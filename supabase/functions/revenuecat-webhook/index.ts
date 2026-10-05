import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const jsonHeaders = { "content-type": "application/json" };

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

async function digest(value: string): Promise<Uint8Array> {
  const bytes = new TextEncoder().encode(value);
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}

async function constantTimeEqual(left: string, right: string): Promise<boolean> {
  const [a, b] = await Promise.all([digest(left), digest(right)]);
  let difference = a.length ^ b.length;
  const size = Math.max(a.length, b.length);
  for (let index = 0; index < size; index += 1) {
    difference |= (a[index % a.length] ?? 0) ^ (b[index % b.length] ?? 0);
  }
  return difference === 0;
}

function entitlementStatus(event: Record<string, unknown>): string {
  const type = String(event.type ?? "").toUpperCase();
  if (type === "BILLING_ISSUE") return "billing_issue";
  if (type === "EXPIRATION") return "expired";
  if (type === "CANCELLATION" && Number(event.expiration_at_ms ?? 0) <= Date.now()) return "expired";
  if (type === "UNCANCELLATION" || type === "RENEWAL" || type === "INITIAL_PURCHASE" || type === "PRODUCT_CHANGE") return "active";
  if (type === "NON_RENEWING_PURCHASE") return "active";
  if (String(event.period_type ?? "").toUpperCase() === "TRIAL") return "trial";
  return "unknown";
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return response(405, { error: "method_not_allowed" });

  const expected = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!expected || !supplied || !(await constantTimeEqual(supplied, expected))) {
    return response(401, { error: "unauthorized" });
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return response(400, { error: "invalid_json" });
  }

  const event = (payload.event ?? payload) as Record<string, unknown>;
  const eventID = String(event.id ?? "");
  const appUserID = String(event.app_user_id ?? "");
  if (!eventID || !appUserID) return response(400, { error: "missing_event_identity" });

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const secretKey = Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseURL || !secretKey) return response(503, { error: "server_not_configured" });
  const supabase = createClient(supabaseURL, secretKey, { auth: { persistSession: false } });

  const occurredAtMs = Number(event.event_timestamp_ms ?? event.purchased_at_ms ?? Date.now());
  const expiresAtMs = Number(event.expiration_at_ms ?? 0);
  const aliases = Array.isArray(event.aliases) ? event.aliases.map(String) : [];

  const { error: profileError } = await supabase.from("profiles").upsert({
    user_id: appUserID,
    firebase_uid: appUserID,
    is_anonymous: false,
  }, { onConflict: "user_id", ignoreDuplicates: true });
  if (profileError) return response(500, { error: "profile_upsert_failed" });

  const { error: eventError } = await supabase.from("subscription_events").upsert({
    source: "revenuecat",
    source_event_id: eventID,
    user_id: appUserID,
    event_type: String(event.type ?? "UNKNOWN"),
    occurred_at: new Date(occurredAtMs).toISOString(),
    payload,
    processed_at: new Date().toISOString(),
  }, { onConflict: "source,source_event_id", ignoreDuplicates: true });
  if (eventError) return response(500, { error: "event_persist_failed" });

  const { error: accountError } = await supabase.from("subscription_accounts").upsert({
    user_id: appUserID,
    revenuecat_app_user_id: appUserID,
    original_app_user_id: String(event.original_app_user_id ?? appUserID),
    status: entitlementStatus(event),
    product_id: event.product_id ? String(event.product_id) : null,
    store: event.store ? String(event.store) : null,
    environment: event.environment ? String(event.environment) : null,
    expires_at: expiresAtMs > 0 ? new Date(expiresAtMs).toISOString() : null,
    will_renew: event.will_renew === true,
    source: "revenuecat",
    source_updated_at: new Date(occurredAtMs).toISOString(),
    raw_customer_info: { event, aliases },
  }, { onConflict: "user_id" });
  if (accountError) return response(500, { error: "entitlement_projection_failed" });

  return response(200, { ok: true, id: eventID });
});

