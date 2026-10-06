import { assertEquals } from "jsr:@std/assert@1";
import { appleState, revenueCatState, superwallState, supabaseUserID } from "./entitlements.ts";

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

Deno.test("StoreKit transactions", () => {
  const base = { transactionId: "2", originalTransactionId: "1", bundleId: "b", productId: "p", signedDate: Date.now() };
  assertEquals(appleState({ ...base, expiresDate: future }).status, "active");
  assertEquals(appleState({ ...base, expiresDate: future, offerDiscountType: "FREE_TRIAL" }).status, "trial");
  assertEquals(appleState({ ...base, expiresDate: Date.now() - 1 }).status, "expired");
  assertEquals(appleState({ ...base, expiresDate: future, revocationDate: Date.now() }).status, "revoked");
  assertEquals(appleState({ ...base, type: "Non-Consumable" }).expires_at, null);
});
