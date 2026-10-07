// Superwall → Supabase entitlements. Source of truth for renewals, expirations,
// billing issues and refunds once RevenueCat is retired. Signed by Svix.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, readBody, reply } from "../_shared/http.ts";
import { verifySvixSignature } from "../_shared/svix.ts";
import {
  applyArguments, idList, superwallIgnoreReason, superwallState, supabaseUserID,
} from "../_shared/entitlements.ts";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const secret = Deno.env.get("SUPERWALL_WEBHOOK_SECRET") ?? "";
  const admin = adminClient();
  if (!secret || !admin) return reply(503, { error: "server_not_configured" });

  const body = await readBody(request, 64 * 1024);
  if (body === null) return reply(413, { error: "payload_too_large" });
  if (!(await verifySvixSignature(secret, request.headers, body))) return reply(401, { error: "unauthorized" });

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(body);
  } catch {
    return reply(400, { error: "invalid_json" });
  }
  const data = (payload.data ?? {}) as Record<string, unknown>;
  const eventID = String(data.id ?? "").slice(0, 200);
  if (!eventID) return reply(200, { ok: true, ignored: "missing_event_id" });

  const bundleID = Deno.env.get("APPLE_BUNDLE_ID") ?? "";
  if (bundleID && data.bundleId && data.bundleId !== bundleID) {
    return reply(200, { ok: true, ignored: "other_bundle" });
  }
  // Sandbox (TestFlight, StoreKit testing) and products outside
  // QUIETO_PREMIUM_PRODUCT_IDS are recorded below but never grant access.
  const ignoreReason = superwallIgnoreReason(data, {
    bundleID,
    premiumProductIDs: idList(Deno.env.get("QUIETO_PREMIUM_PRODUCT_IDS")),
  });

  const { error: insertError } = await admin.from("subscription_events").upsert({
    source: "superwall",
    source_event_id: eventID,
    event_type: String(data.name ?? payload.type ?? "unknown").slice(0, 80),
    occurred_at: new Date(Number(data.ts ?? payload.timestamp ?? Date.now())).toISOString(),
    payload,
  }, { onConflict: "source,source_event_id", ignoreDuplicates: true });
  if (insertError) return reply(500, { error: "event_persist_failed" });

  // Processed only once, but a failed processing is retried by Svix.
  const { data: stored, error: readError } = await admin.from("subscription_events")
    .select("id, processed_at").eq("source", "superwall").eq("source_event_id", eventID).single();
  if (readError || !stored) return reply(500, { error: "event_read_failed" });
  if (stored.processed_at) return reply(200, { ok: true, duplicate: true });

  if (ignoreReason) {
    await admin.from("subscription_events").update({ processed_at: new Date().toISOString(), processing_error: ignoreReason }).eq("id", stored.id);
    return reply(200, { ok: true, ignored: ignoreReason });
  }

  const state = superwallState(data, payload.timestamp);
  if (!state) {
    await admin.from("subscription_events").update({ processed_at: new Date().toISOString(), processing_error: "no_original_transaction_id" }).eq("id", stored.id);
    return reply(200, { ok: true, ignored: "no_original_transaction_id" });
  }

  const { data: userID, error: applyError } = await admin.rpc(
    "apply_store_subscription",
    applyArguments(state, supabaseUserID(data.originalAppUserId), false, "superwall", data),
  );
  if (applyError) {
    await admin.from("subscription_events").update({ processing_error: "apply_failed" }).eq("id", stored.id);
    return reply(500, { error: "entitlement_projection_failed" });
  }

  await admin.from("subscription_events").update({
    user_id: userID ?? null,
    processed_at: new Date().toISOString(),
    processing_error: userID ? null : "user_unresolved_until_device_claim",
  }).eq("id", stored.id);
  return reply(200, { ok: true });
});
