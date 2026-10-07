// Device claim: the app sends the StoreKit 2 signed transactions it currently
// holds (Transaction.currentEntitlements). Each one is verified against Apple's
// root certificate, then bound to the caller. This is how a subscription
// follows its Apple ID across reinstalls, new anonymous accounts and the move
// from the Flutter app, without trusting anything the client says about itself.
//
// Ownership: a verified JWS proves the device holds the Apple ID, not that the
// caller bought it. A transaction already bound to another account only moves
// when its appAccountToken is the caller's id (Superwall sets it to the
// Supabase UUID at purchase), or when the JWS is fresh (signed < 10 min ago)
// and the transaction has not moved in the last 24 h. The rule lives in
// public.apply_store_subscription(); otherwise the call succeeds without
// granting access.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, readBody, reply } from "../_shared/http.ts";
import { AppleJWSError, verifyAppleTransaction } from "../_shared/apple-jws.ts";
import { appleState, applyArguments, environmentGrantsAccess, idList } from "../_shared/entitlements.ts";

const maxTransactions = 20;
// Each call may run up to 20 X.509 chain verifications: 10 calls / 10 min.
const rateLimit = { max: 10, windowSeconds: 600 };

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const admin = adminClient();
  const bundleID = Deno.env.get("APPLE_BUNDLE_ID") ?? "";
  if (!admin || !bundleID) return reply(503, { error: "server_not_configured" });

  const bearer = request.headers.get("authorization") ?? "";
  if (!bearer.startsWith("Bearer ")) return reply(401, { error: "unauthorized" });
  const { data: identity, error: identityError } = await admin.auth.getUser(bearer.slice(7));
  if (identityError || !identity.user) return reply(401, { error: "invalid_token" });
  const userID = identity.user.id;

  const { data: allowed, error: rateError } = await admin.rpc("rate_limit_hit", {
    p_bucket: "subscription_sync",
    p_subject: userID,
    p_max: rateLimit.max,
    p_window_seconds: rateLimit.windowSeconds,
  });
  // A failing limiter never blocks a purchase (logged); only a clear "no" does.
  if (rateError) console.error("[subscription-sync] rate limit unavailable:", rateError.message);
  else if (allowed === false) return reply(429, { error: "rate_limited" });

  const sandboxUserIDs = idList(Deno.env.get("QUIETO_SANDBOX_USER_IDS"), true);
  const premiumProductIDs = idList(Deno.env.get("QUIETO_PREMIUM_PRODUCT_IDS"));

  const body = await readBody(request, 256 * 1024);
  if (body === null) return reply(413, { error: "payload_too_large" });
  let transactions: unknown;
  try {
    transactions = JSON.parse(body).transactions;
  } catch {
    return reply(400, { error: "invalid_json" });
  }
  if (!Array.isArray(transactions) || transactions.length > maxTransactions || !transactions.every((t) => typeof t === "string" && t.length < 20_000)) {
    return reply(400, { error: "invalid_transactions" });
  }

  const { error: profileError } = await admin.from("profiles").upsert({
    user_id: userID,
    is_anonymous: identity.user.is_anonymous ?? false,
  }, { onConflict: "user_id", ignoreDuplicates: true });
  if (profileError) return reply(500, { error: "profile_upsert_failed" });

  const rejected: string[] = [];
  for (const jws of transactions as string[]) {
    try {
      const transaction = await verifyAppleTransaction(jws);
      if (transaction.bundleId !== bundleID) {
        rejected.push("other_bundle");
        continue;
      }
      // TestFlight / Sandbox / Xcode purchases are free: testers only.
      if (!environmentGrantsAccess(transaction.environment, userID, sandboxUserIDs)) {
        rejected.push("sandbox_not_allowed");
        continue;
      }
      const state = appleState(transaction, Date.now(), { premiumProductIDs });
      const { data: owner, error } = await admin.rpc(
        "apply_store_subscription",
        applyArguments(state, userID, true, "app_store", {
          transactionId: transaction.transactionId,
          productId: transaction.productId,
          environment: transaction.environment,
          appAccountToken: transaction.appAccountToken ?? null,
        }, {
          appAccountToken: transaction.appAccountToken ?? null,
          signedAt: state.event_at,
        }),
      );
      if (error) return reply(500, { error: "entitlement_projection_failed" });
      if (owner !== userID) rejected.push("bound_to_another_account");
    } catch (error) {
      rejected.push(error instanceof AppleJWSError ? error.message : "verification_failed");
    }
  }

  const { data: premium, error: premiumError } = await admin.rpc("user_has_premium", { p_user_id: userID });
  if (premiumError) return reply(500, { error: "entitlement_read_failed" });
  return reply(200, { premium: premium === true, rejected });
});
