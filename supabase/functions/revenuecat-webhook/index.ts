// Legacy RevenueCat → Supabase entitlements, kept until the Flutter app is
// retired. Same single writer as Superwall (public.apply_store_subscription),
// so retries and replays can never overwrite a newer state.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, readBody, reply, timingSafeEqual } from "../_shared/http.ts";
import { applyArguments, revenueCatState } from "../_shared/entitlements.ts";

async function digest(value: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const expected = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!expected || !supplied || !timingSafeEqual(await digest(supplied), await digest(expected))) {
    return reply(401, { error: "unauthorized" });
  }
  const admin = adminClient();
  if (!admin) return reply(503, { error: "server_not_configured" });

  const body = await readBody(request, 128 * 1024);
  if (body === null) return reply(413, { error: "payload_too_large" });
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(body);
  } catch {
    return reply(400, { error: "invalid_json" });
  }

  const event = (payload.event ?? payload) as Record<string, unknown>;
  const eventID = String(event.id ?? "").slice(0, 200);
  if (!eventID) return reply(200, { ok: true, ignored: "missing_event_id" });
  const appUserID = typeof event.app_user_id === "string" ? event.app_user_id.slice(0, 128) : "";

  const { error: insertError } = await admin.from("subscription_events").upsert({
    source: "revenuecat",
    source_event_id: eventID,
    event_type: String(event.type ?? "UNKNOWN").slice(0, 80),
    occurred_at: new Date(Number(event.event_timestamp_ms ?? Date.now())).toISOString(),
    payload,
  }, { onConflict: "source,source_event_id", ignoreDuplicates: true });
  if (insertError) return reply(500, { error: "event_persist_failed" });

  const { data: stored, error: readError } = await admin.from("subscription_events")
    .select("id, processed_at").eq("source", "revenuecat").eq("source_event_id", eventID).single();
  if (readError || !stored) return reply(500, { error: "event_read_failed" });
  if (stored.processed_at) return reply(200, { ok: true, duplicate: true });

  // TRANSFER, TEST and events without a user are recorded but change nothing.
  const state = revenueCatState(event);
  if (!state || !appUserID) {
    await admin.from("subscription_events").update({ processed_at: new Date().toISOString(), processing_error: "not_applicable" }).eq("id", stored.id);
    return reply(200, { ok: true, ignored: String(event.type ?? "unknown") });
  }

  // A Firebase account already linked to a Supabase user resolves to that user;
  // otherwise the legacy Firebase UID gets its own (server-side) profile row.
  const { data: linked } = await admin.from("profiles").select("user_id").eq("firebase_uid", appUserID).limit(1);
  let userID = linked?.[0]?.user_id as string | undefined;
  if (!userID) {
    const { error: profileError } = await admin.from("profiles").upsert(
      { user_id: appUserID, is_anonymous: false },
      { onConflict: "user_id", ignoreDuplicates: true },
    );
    if (profileError) return reply(500, { error: "profile_upsert_failed" });
    userID = appUserID;
  }

  const { data: resolved, error: applyError } = await admin.rpc(
    "apply_store_subscription",
    applyArguments(state, userID, false, "revenuecat", event),
  );
  if (applyError) {
    await admin.from("subscription_events").update({ processing_error: "apply_failed" }).eq("id", stored.id);
    return reply(500, { error: "entitlement_projection_failed" });
  }
  await admin.from("subscription_events").update({
    user_id: resolved ?? userID,
    processed_at: new Date().toISOString(),
    processing_error: null,
  }).eq("id", stored.id);
  return reply(200, { ok: true, id: eventID });
});
