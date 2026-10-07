// Stripe over plain fetch (no SDK), same as the Firebase backend
// (backend/functions/index.js, section « ACCÈS ENTREPRISE »): pinned API
// version, form-encoded bodies, and webhook signatures checked with Web Crypto.
import { timingSafeEqual } from "./http.ts";

// Pinned: object shapes (current_period_end on the subscription, invoice
// payment_intent…) do not move when Stripe publishes a new version.
export const STRIPE_VERSION = "2024-06-20";

// {a: {b: [1, {c: 2}]}} → "a[b][0]=1&a[b][1][c]=2" (Stripe's form format).
export function formStripe(object: Record<string, unknown>, prefix = "", out: string[] = []): string {
  for (const [key, value] of Object.entries(object ?? {})) {
    if (value === undefined || value === null) continue;
    const name = prefix ? `${prefix}[${key}]` : key;
    if (typeof value === "object") formStripe(value as Record<string, unknown>, name, out);
    else out.push(encodeURIComponent(name) + "=" + encodeURIComponent(String(value)));
  }
  return out.join("&");
}

export class StripeError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

// deno-lint-ignore no-explicit-any
export type StripeObject = Record<string, any>;

export async function stripeRequest(
  method: "GET" | "POST",
  path: string,
  params?: Record<string, unknown>,
  secretKey = Deno.env.get("STRIPE_SECRET_KEY") ?? "",
): Promise<StripeObject> {
  const body = params ? formStripe(params) : "";
  const response = await fetch("https://api.stripe.com/v1" + path + (method === "GET" && body ? "?" + body : ""), {
    method,
    headers: {
      "authorization": "Bearer " + secretKey,
      "stripe-version": STRIPE_VERSION,
      ...(method === "GET" ? {} : { "content-type": "application/x-www-form-urlencoded" }),
    },
    body: method === "GET" ? undefined : body,
    signal: AbortSignal.timeout(10_000),
  });
  const json = await response.json().catch(() => ({})) as StripeObject;
  if (!response.ok) {
    throw new StripeError(response.status, `Stripe ${response.status} : ${json?.error?.message ?? JSON.stringify(json).slice(0, 200)}`);
  }
  return json;
}

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

const toleranceSeconds = 5 * 60;

/**
 * `Stripe-Signature: t=…,v1=…[,v1=…]`: HMAC-SHA256 of "{t}.{raw body}" keyed
 * with the whole "whsec_…" string (UTF-8, not base64-decoded, unlike Svix),
 * hex encoded. 5 minutes of tolerance against replays. Several v1 entries
 * coexist while a webhook secret is being rolled.
 */
export async function verifyStripeSignature(
  secret: string,
  header: string | null,
  rawBody: Uint8Array,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<boolean> {
  if (!secret || !header || !rawBody) return false;
  const parts: Record<string, string[]> = {};
  for (const piece of header.split(",")) {
    const index = piece.indexOf("=");
    if (index <= 0) continue;
    const key = piece.slice(0, index).trim();
    (parts[key] ??= []).push(piece.slice(index + 1).trim());
  }
  const timestamp = parts.t?.[0] ?? "";
  if (!/^\d+$/.test(timestamp) || Math.abs(nowSeconds - Number(timestamp)) > toleranceSeconds) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const prefix = new TextEncoder().encode(timestamp + ".");
  const signed = new Uint8Array(prefix.length + rawBody.length);
  signed.set(prefix, 0);
  signed.set(rawBody, prefix.length);
  const expected = new TextEncoder().encode(hex(await crypto.subtle.sign("HMAC", key, signed)));
  return (parts.v1 ?? []).some((candidate) => timingSafeEqual(new TextEncoder().encode(candidate), expected));
}

/** Test helper and documentation of the scheme: builds a valid header. */
export async function signStripePayload(secret: string, rawBody: Uint8Array, timestamp: number): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const prefix = new TextEncoder().encode(`${timestamp}.`);
  const signed = new Uint8Array(prefix.length + rawBody.length);
  signed.set(prefix, 0);
  signed.set(rawBody, prefix.length);
  return `t=${timestamp},v1=${hex(await crypto.subtle.sign("HMAC", key, signed))}`;
}

// Provisional access while a first SEPA debit is processing.
export const PROVISIONAL_MS = 14 * 24 * 60 * 60 * 1000;

/**
 * How far the subscription is PAID (ms, 0 = not at all), per Stripe:
 *  - paid: end of the current period (one year or one month);
 *  - first SEPA debit processing: 14 provisional days;
 *  - unpaid renewal (past_due, unpaid): only the previous period stays
 *    acquired (Stripe moves the period forward even when unpaid);
 *  - canceled, expired, paused: 0.
 * The 10-day margin is added in SQL (private.enterprise_coverage).
 */
export function paidUntilStripe(subscription: StripeObject, now = Date.now()) {
  const start = Number(subscription.current_period_start) * 1000 || 0;
  const end = Number(subscription.current_period_end) * 1000 || 0;
  const invoice = subscription.latest_invoice && typeof subscription.latest_invoice === "object" ? subscription.latest_invoice : null;
  const paid = !invoice || invoice.status === "paid" || Number(invoice.amount_due) === 0;
  const intent = invoice?.payment_intent && typeof invoice.payment_intent === "object" ? invoice.payment_intent : null;
  const processing = !!intent && intent.status === "processing";
  const provisional = Math.min(end || Infinity, now + PROVISIONAL_MS);
  switch (String(subscription.status)) {
    case "active":
    case "trialing":
      return { paidUntilMs: paid ? end : (processing ? provisional : start), paid, processing };
    case "incomplete":
      return { paidUntilMs: processing ? provisional : 0, paid: false, processing };
    case "past_due":
    case "unpaid":
      return { paidUntilMs: start, paid: false, processing };
    default: // canceled, incomplete_expired, paused
      return { paidUntilMs: 0, paid, processing: false };
  }
}

/** Company name: the answer to the custom field asked during checkout. */
export function companyNameFromSession(session: StripeObject | null): string {
  const fields = Array.isArray(session?.custom_fields) ? session!.custom_fields : [];
  const field = fields.find((entry: StripeObject) => entry && entry.key === "entreprise");
  return String(field?.text?.value ?? "").trim().slice(0, 60);
}

/** Subscription id carried by a webhook event, or null when not relevant. */
export function subscriptionIdFromEvent(event: StripeObject): { subscriptionId: string | null; session: StripeObject | null } {
  const type = String(event?.type ?? "");
  const object = (event?.data?.object ?? {}) as StripeObject;
  let subscriptionId: unknown = null;
  let session: StripeObject | null = null;
  if (type.startsWith("checkout.session.")) {
    if (object.mode === "subscription") {
      subscriptionId = object.subscription;
      session = object;
    }
  } else if (type.startsWith("customer.subscription.")) {
    subscriptionId = object.id;
  } else if (type.startsWith("invoice.")) {
    subscriptionId = object.subscription ?? object.parent?.subscription_details?.subscription;
  }
  return {
    subscriptionId: typeof subscriptionId === "string" && subscriptionId.startsWith("sub_") ? subscriptionId : null,
    session,
  };
}
