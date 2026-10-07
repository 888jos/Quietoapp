import { assertEquals } from "jsr:@std/assert@1";
import {
  appleState, applyArguments, environmentGrantsAccess, idList, isProductionEnvironment, revenueCatState,
  superwallIgnoreReason, superwallState, supabaseUserID,
} from "./entitlements.ts";

const future = Date.now() + 86_400_000;

Deno.test("a Superwall cancellation keeps access until the period ends", () => {
  const state = superwallState({ name: "cancellation", originalTransactionId: "1", expirationAt: future, cancelReason: "UNSUBSCRIBE", periodType: "NORMAL", ts: Date.now() });
  assertEquals(state?.status, "active");
  assertEquals(state?.will_renew, false);
  assertEquals(state?.revoked_at, null);
});

Deno.test("a Superwall refund revokes access", () => {
  const state = superwallState({ name: "cancellation", originalTransactionId: "1", expirationAt: future, cancelReason: "CUSTOMER_SUPPORT", price: -9.99, ts: Date.now() });
  assertEquals(state?.status, "revoked");
});

Deno.test("Superwall trial, billing issue, expiration and product change", () => {
  assertEquals(superwallState({ name: "initial_purchase", originalTransactionId: "1", periodType: "TRIAL" })?.status, "trial");
  assertEquals(superwallState({ name: "billing_issue", originalTransactionId: "1" })?.status, "billing_issue");
  assertEquals(superwallState({ name: "expiration", originalTransactionId: "1" })?.status, "expired");
  assertEquals(superwallState({ name: "product_change", originalTransactionId: "1", productId: "a", newProductId: "b" })?.product_id, "b");
  assertEquals(superwallState({ name: "renewal" }), null);
});

Deno.test("only identify() UUIDs resolve to Supabase users", () => {
  assertEquals(supabaseUserID("$SuperwallAlias:7152E89E-60A6-4B2E-9C67-D7ED8F5BE372"), null);
  assertEquals(supabaseUserID("7152E89E-60A6-4B2E-9C67-D7ED8F5BE372"), "7152e89e-60a6-4b2e-9c67-d7ed8f5be372");
  assertEquals(supabaseUserID(null), null);
});

Deno.test("RevenueCat cancellation is not an immediate loss of access", () => {
  const state = revenueCatState({ type: "CANCELLATION", app_user_id: "fuid", original_transaction_id: "9", expiration_at_ms: future, cancel_reason: "UNSUBSCRIBE" });
  assertEquals(state?.status, "active");
  assertEquals(revenueCatState({ type: "BILLING_ISSUE", app_user_id: "fuid", expiration_at_ms: future })?.status, "billing_issue");
  assertEquals(revenueCatState({ type: "TRANSFER" }), null);
  assertEquals(revenueCatState({ type: "INITIAL_PURCHASE", app_user_id: "fuid" })?.original_transaction_id, "rc:fuid");
});

const base = {
  transactionId: "2", originalTransactionId: "1", bundleId: "b", productId: "p", signedDate: Date.now(),
  type: "Auto-Renewable Subscription", environment: "Production",
};

Deno.test("StoreKit transactions", () => {
  assertEquals(appleState({ ...base, expiresDate: future }).status, "active");
  assertEquals(appleState({ ...base, expiresDate: future, offerDiscountType: "FREE_TRIAL" }).status, "trial");
  assertEquals(appleState({ ...base, expiresDate: Date.now() - 1 }).status, "expired");
  assertEquals(appleState({ ...base, expiresDate: future, revocationDate: Date.now() }).status, "revoked");
  assertEquals(appleState({ ...base, expiresDate: future }).environment, "PRODUCTION");
});

Deno.test("only auto-renewable subscriptions grant access", () => {
  const lifetime = appleState({ ...base, type: "Non-Consumable" });
  assertEquals(lifetime.status, "inactive");
  assertEquals(lifetime.expires_at, null);
  assertEquals(appleState({ ...base, type: "Non-Renewing Subscription", expiresDate: future }).status, "inactive");
  assertEquals(appleState({ ...base, type: "Consumable" }).status, "inactive");
  assertEquals(appleState({ ...base, type: undefined, expiresDate: future }).status, "inactive");
});

Deno.test("QUIETO_PREMIUM_PRODUCT_IDS restricts the products", () => {
  const policy = { premiumProductIDs: idList("quieto.annual, quieto.monthly") };
  assertEquals(appleState({ ...base, productId: "quieto.annual", expiresDate: future }, Date.now(), policy).status, "active");
  assertEquals(appleState({ ...base, productId: "other", expiresDate: future }, Date.now(), policy).status, "inactive");
  // An empty list means "every auto-renewable subscription of the bundle".
  assertEquals(appleState({ ...base, productId: "other", expiresDate: future }, Date.now(), { premiumProductIDs: idList("") }).status, "active");
});

Deno.test("sandbox purchases only grant access to listed testers", () => {
  const testers = idList("7152E89E-60A6-4B2E-9C67-D7ED8F5BE372, ", true);
  assertEquals(testers.size, 1);
  assertEquals(isProductionEnvironment("Production"), true);
  assertEquals(isProductionEnvironment("PRODUCTION"), true);
  assertEquals(isProductionEnvironment("Sandbox"), false);
  assertEquals(isProductionEnvironment(undefined), false);
  assertEquals(environmentGrantsAccess("Production", "someone", testers), true);
  assertEquals(environmentGrantsAccess("Sandbox", "someone", testers), false);
  assertEquals(environmentGrantsAccess("SANDBOX", null, testers), false);
  assertEquals(environmentGrantsAccess("Xcode", "7152e89e-60a6-4b2e-9c67-d7ed8f5be372", testers), true);
  assertEquals(environmentGrantsAccess(undefined, "7152e89e-60a6-4b2e-9c67-d7ed8f5be372", testers), true);
  assertEquals(environmentGrantsAccess(undefined, "someone", testers), false);
});

Deno.test("Superwall events that must not grant access", () => {
  const event = { name: "initial_purchase", originalTransactionId: "1", productId: "quieto.annual", bundleId: "app.quieto", environment: "PRODUCTION" };
  const options = { bundleID: "app.quieto", premiumProductIDs: idList("quieto.annual") };
  assertEquals(superwallIgnoreReason(event, options), null);
  assertEquals(superwallIgnoreReason({ ...event, environment: "SANDBOX" }, options), "sandbox_event");
  assertEquals(superwallIgnoreReason({ ...event, environment: "Sandbox" }, options), "sandbox_event");
  assertEquals(superwallIgnoreReason({ ...event, bundleId: "other.app" }, options), "other_bundle");
  // No bundleId: accepted only for an allowed product (when the list is set).
  assertEquals(superwallIgnoreReason({ ...event, bundleId: undefined }, options), null);
  assertEquals(superwallIgnoreReason({ ...event, bundleId: undefined, productId: "lifetime" }, options), "product_not_allowed");
  assertEquals(superwallIgnoreReason({ ...event, bundleId: undefined, productId: "lifetime" }, { bundleID: "app.quieto" }), null);
  assertEquals(
    superwallIgnoreReason({ ...event, name: "product_change", productId: "quieto.annual", newProductId: "lifetime" }, options),
    "product_not_allowed",
  );
  assertEquals(superwallState({ name: "non_renewing_purchase", originalTransactionId: "1" })?.status, "inactive");
});

Deno.test("the device claim is only sent by subscription-sync", () => {
  const state = appleState({ ...base, expiresDate: future });
  const webhook = applyArguments(state, "u", false, "superwall", {});
  assertEquals("p_app_account_token" in webhook, false);
  assertEquals("p_signed_at" in webhook, false);
  const claim = applyArguments(state, "u", true, "app_store", {}, {
    appAccountToken: " 7152E89E-60A6-4B2E-9C67-D7ED8F5BE372 ",
    signedAt: state.event_at,
  });
  assertEquals(claim.p_app_account_token, "7152e89e-60a6-4b2e-9c67-d7ed8f5be372");
  assertEquals(claim.p_signed_at, state.event_at);
});
