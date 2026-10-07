// deno test --allow-net=none supabase/functions/_shared
import { assertEquals } from "jsr:@std/assert@1";
import { paidUntilStripe, signStripePayload, subscriptionIdFromEvent, verifyStripeSignature } from "./stripe.ts";
import { enterprisePrice, normalizeCode } from "./entreprise.ts";

const secret = "whsec_test_secret_for_quieto_unit_tests";
const body = new TextEncoder().encode('{"id":"evt_test","type":"customer.subscription.updated","note":"Acmé"}');
const timestamp = 1759737600;
// Computed independently with Node: crypto.createHmac("sha256", secret).update(`${t}.${body}`).digest("hex")
const reference = "33b4f53c04a3c85483358685939b282ddfc3b97daca4dcdba7b138f7bc432dec";

Deno.test("accepts the independently computed Stripe signature", async () => {
  assertEquals(await verifyStripeSignature(secret, `t=${timestamp},v1=${reference}`, body, timestamp + 10), true);
  assertEquals(await signStripePayload(secret, body, timestamp), `t=${timestamp},v1=${reference}`);
});

Deno.test("accepts when one of several v1 signatures matches (secret rotation) and ignores v0", async () => {
  const header = `t=${timestamp},v0=deadbeef,v1=${"0".repeat(64)},v1=${reference}`;
  assertEquals(await verifyStripeSignature(secret, header, body, timestamp), true);
});

Deno.test("rejects a modified body, a wrong secret, an old or future timestamp", async () => {
  const header = `t=${timestamp},v1=${reference}`;
  assertEquals(await verifyStripeSignature(secret, header, new TextEncoder().encode('{"id":"evt_test"}'), timestamp), false);
  assertEquals(await verifyStripeSignature("whsec_other", header, body, timestamp), false);
  assertEquals(await verifyStripeSignature(secret, header, body, timestamp + 301), false);
  assertEquals(await verifyStripeSignature(secret, header, body, timestamp - 301), false);
});

Deno.test("rejects missing or malformed headers", async () => {
  assertEquals(await verifyStripeSignature(secret, null, body, timestamp), false);
  assertEquals(await verifyStripeSignature(secret, `v1=${reference}`, body, timestamp), false);
  assertEquals(await verifyStripeSignature(secret, `t=abc,v1=${reference}`, body, timestamp), false);
  assertEquals(await verifyStripeSignature(secret, `t=${timestamp}`, body, timestamp), false);
  assertEquals(await verifyStripeSignature("", `t=${timestamp},v1=${reference}`, body, timestamp), false);
});

Deno.test("paid period rules (same as Firebase finPayeeStripe)", () => {
  const now = 1_760_000_000_000;
  const start = 1_759_000_000;
  const end = 1_790_000_000;
  const base = { current_period_start: start, current_period_end: end };
  assertEquals(paidUntilStripe({ ...base, status: "active", latest_invoice: { status: "paid" } }, now).paidUntilMs, end * 1000);
  // First SEPA debit processing: 14 provisional days.
  const sepa = { status: "open", amount_due: 100, payment_intent: { status: "processing" } };
  assertEquals(paidUntilStripe({ ...base, status: "incomplete", latest_invoice: sepa }, now).paidUntilMs, now + 14 * 86_400_000);
  assertEquals(paidUntilStripe({ ...base, status: "active", latest_invoice: sepa }, now).paidUntilMs, now + 14 * 86_400_000);
  // Unpaid renewal: only the previous period stays acquired.
  assertEquals(paidUntilStripe({ ...base, status: "past_due", latest_invoice: { status: "open", amount_due: 100 } }, now).paidUntilMs, start * 1000);
  assertEquals(paidUntilStripe({ ...base, status: "canceled" }, now).paidUntilMs, 0);
  assertEquals(paidUntilStripe({ ...base, status: "incomplete", latest_invoice: { status: "open", amount_due: 100 } }, now).paidUntilMs, 0);
});

Deno.test("subscription id extraction from webhook events", () => {
  assertEquals(subscriptionIdFromEvent({ type: "checkout.session.completed", data: { object: { mode: "subscription", subscription: "sub_1" } } }).subscriptionId, "sub_1");
  assertEquals(subscriptionIdFromEvent({ type: "checkout.session.completed", data: { object: { mode: "payment" } } }).subscriptionId, null);
  assertEquals(subscriptionIdFromEvent({ type: "customer.subscription.updated", data: { object: { id: "sub_2" } } }).subscriptionId, "sub_2");
  assertEquals(subscriptionIdFromEvent({ type: "invoice.paid", data: { object: { parent: { subscription_details: { subscription: "sub_3" } } } } }).subscriptionId, "sub_3");
  assertEquals(subscriptionIdFromEvent({ type: "invoice.paid", data: { object: { subscription: "in_x" } } }).subscriptionId, null);
});

Deno.test("codes and prices", () => {
  assertEquals(normalizeCode(" Acmé-7k2p "), "ACME7K2P");
  assertEquals(enterprisePrice(25, "annuel"), { yearlyPerSeat: 56.04, perPeriod: 56.04, total: 1401 });
  assertEquals(enterprisePrice(999, "mensuel").perPeriod, 4.49);
});
