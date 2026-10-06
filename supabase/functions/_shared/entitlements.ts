// Maps store events (Superwall, RevenueCat, StoreKit) to the arguments of
// public.apply_store_subscription(). Access itself is decided in SQL by
// public.user_has_premium(): a status that grants access still needs
// `expires_at` in the future, so a cancelled subscription keeps working until
// the end of the paid period.
import type { AppleTransaction } from "./apple-jws.ts";
import { isoOrNull } from "./http.ts";

export interface StoreState {
  original_transaction_id: string;
  status: "trial" | "active" | "billing_issue" | "expired" | "revoked" | "inactive" | "promotional" | "unknown";
  product_id: string | null;
  store: string | null;
  environment: string | null;
  period_type: string | null;
  expires_at: string | null;
  revoked_at: string | null;
  will_renew: boolean | null;
  event_at: string;
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Superwall passes the identify() user id; anonymous aliases are not ours. */
export function supabaseUserID(value: unknown): string | null {
  const candidate = typeof value === "string" ? value.trim() : "";
  return uuidPattern.test(candidate) ? candidate.toLowerCase() : null;
}

function text(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value.slice(0, 200) : null;
}

function paidStatus(periodType: unknown): "trial" | "active" {
  return String(periodType ?? "").toUpperCase() === "TRIAL" ? "trial" : "active";
}

export function superwallState(data: Record<string, unknown>, envelopeTimestamp?: unknown): StoreState | null {
  const originalTransactionID = text(data.originalTransactionId);
  if (!originalTransactionID) return null;
  const name = String(data.name ?? "").toLowerCase();
  const eventAt = isoOrNull(data.ts) ?? isoOrNull(envelopeTimestamp) ?? new Date().toISOString();
  const refund = name === "cancellation" &&
    (String(data.cancelReason ?? "").toUpperCase() === "CUSTOMER_SUPPORT" || Number(data.price) < 0);

  let status: StoreState["status"];
  let willRenew: boolean | null = null;
  switch (name) {
    case "initial_purchase":
    case "renewal":
    case "uncancellation":
    case "product_change":
      status = paidStatus(data.periodType);
      willRenew = true;
      break;
    case "non_renewing_purchase":
      status = "active";
      willRenew = false;
      break;
    case "cancellation":
      status = refund ? "revoked" : paidStatus(data.periodType);
      willRenew = false;
      break;
    case "billing_issue":
      status = "billing_issue";
      break;
    case "expiration":
      status = "expired";
      willRenew = false;
      break;
    case "subscription_paused":
      status = "inactive";
      break;
    default:
      status = "unknown";
  }

  return {
    original_transaction_id: originalTransactionID,
    status,
    product_id: text(name === "product_change" ? data.newProductId ?? data.productId : data.productId),
    store: text(data.store),
    environment: text(data.environment),
    period_type: text(data.periodType),
    expires_at: isoOrNull(data.expirationAt),
    revoked_at: refund ? eventAt : null,
    will_renew: willRenew,
    event_at: eventAt,
  };
}

export function revenueCatState(event: Record<string, unknown>): StoreState | null {
  const appUserID = text(event.app_user_id);
  const type = String(event.type ?? "").toUpperCase();
  const originalTransactionID = text(event.original_transaction_id) ?? (appUserID ? `rc:${appUserID}` : null);
  if (!originalTransactionID) return null;
  const eventAt = isoOrNull(event.event_timestamp_ms) ?? isoOrNull(event.purchased_at_ms) ?? new Date().toISOString();
  const refund = type === "CANCELLATION" && String(event.cancel_reason ?? "").toUpperCase() === "CUSTOMER_SUPPORT";

  let status: StoreState["status"];
  let willRenew: boolean | null = null;
  switch (type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
      status = paidStatus(event.period_type);
      willRenew = true;
      break;
    case "NON_RENEWING_PURCHASE":
      status = "active";
      willRenew = false;
      break;
    case "CANCELLATION":
      status = refund ? "revoked" : paidStatus(event.period_type);
      willRenew = false;
      break;
    case "BILLING_ISSUE":
      status = "billing_issue";
      break;
    case "EXPIRATION":
      status = "expired";
      willRenew = false;
      break;
    case "SUBSCRIPTION_PAUSED":
      status = "inactive";
      break;
    default:
      return null;
  }

  return {
    original_transaction_id: originalTransactionID,
    status,
    product_id: text(type === "PRODUCT_CHANGE" ? event.new_product_id ?? event.product_id : event.product_id),
    store: text(event.store),
    environment: text(event.environment),
    period_type: text(event.period_type),
    expires_at: isoOrNull(event.expiration_at_ms),
    revoked_at: refund ? eventAt : null,
    will_renew: willRenew,
    event_at: eventAt,
  };
}

export function appleState(transaction: AppleTransaction, now = Date.now()): StoreState {
  const lifetime = transaction.type === "Non-Consumable";
  const expiresAt = Number(transaction.expiresDate ?? 0);
  let status: StoreState["status"];
  if (transaction.revocationDate) status = "revoked";
  else if (lifetime) status = "promotional";
  else if (expiresAt > now) status = transaction.offerDiscountType === "FREE_TRIAL" ? "trial" : "active";
  else status = "expired";

  return {
    original_transaction_id: transaction.originalTransactionId,
    status,
    product_id: transaction.productId,
    store: "APP_STORE",
    environment: transaction.environment ? transaction.environment.toUpperCase() : null,
    period_type: transaction.offerDiscountType === "FREE_TRIAL" ? "TRIAL" : null,
    expires_at: lifetime ? null : isoOrNull(transaction.expiresDate),
    revoked_at: isoOrNull(transaction.revocationDate),
    will_renew: null,
    event_at: new Date(transaction.signedDate).toISOString(),
  };
}

export function applyArguments(
  state: StoreState,
  userID: string | null,
  transfer: boolean,
  source: "superwall" | "app_store" | "revenuecat",
  raw: unknown,
) {
  return {
    p_original_transaction_id: state.original_transaction_id,
    p_user_id: userID,
    p_transfer: transfer,
    p_source: source,
    p_status: state.status,
    p_product_id: state.product_id,
    p_store: state.store,
    p_environment: state.environment,
    p_period_type: state.period_type,
    p_expires_at: state.expires_at,
    p_revoked_at: state.revoked_at,
    p_will_renew: state.will_renew,
    p_event_at: state.event_at,
    p_raw: raw ?? {},
  };
}
