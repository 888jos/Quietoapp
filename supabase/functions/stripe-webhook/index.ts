// Stripe webhook of Quieto Entreprise. Replaces the Firebase function `stripe`.
// On every event (payment, renewal, failure, cancellation…) the subscription
// is READ AGAIN at Stripe (webhook order is not guaranteed) and
// public.enterprises is updated through enterprise_apply_stripe(). On the
// first activation a code (e.g. ACME-7K2P) is created and e-mailed to the
// buyer (HR) with a text to forward to the team. Members' access follows the
// paid period through a trigger (no lazy extension at app launch any more).
// Signature: Stripe-Signature header, HMAC-SHA256 with STRIPE_WEBHOOK_SECRET.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient } from "../_shared/http.ts";
import { CONTACT_ENTREPRISE, contenuCodeEntreprise, EXPEDITEUR, json, newEnterpriseCode, normalizeCode, sendResend, text } from "../_shared/entreprise.ts";
import {
  companyNameFromSession,
  paidUntilStripe,
  type StripeObject,
  stripeRequest,
  subscriptionIdFromEvent,
  verifyStripeSignature,
} from "../_shared/stripe.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";

const maxBodyBytes = 512 * 1024;

async function syncEnterprise(admin: SupabaseClient, subscriptionId: string, session: StripeObject | null) {
  const subscription = await stripeRequest("GET", "/subscriptions/" + encodeURIComponent(subscriptionId), {
    expand: ["customer", "latest_invoice.payment_intent"],
  });
  const meta = (subscription.metadata ?? {}) as Record<string, string>;
  const item = subscription.items?.data?.[0];
  const seats = parseInt(String(item?.quantity ?? meta.places ?? ""), 10);
  if (meta.origine !== "quieto-entreprise" || !(seats > 0)) {
    console.log("[Stripe]", subscriptionId, ": pas un abonnement Quieto Entreprise, ignoré");
    return;
  }
  const customer = subscription.customer && typeof subscription.customer === "object" ? subscription.customer : {};
  const sessionName = companyNameFromSession(session);
  // The name typed at checkout is also stored on the subscription: visible in
  // the Stripe Dashboard, and read again on the following events.
  if (sessionName && meta.entreprise !== sessionName) {
    await stripeRequest("POST", "/subscriptions/" + encodeURIComponent(subscriptionId), { metadata: { entreprise: sessionName } })
      .catch((error) => console.warn("[Stripe] nom non rangé sur", subscriptionId, ":", error.message));
  }
  const name = String(sessionName || meta.entreprise || customer.name || "Ton entreprise").slice(0, 60);
  const email = String(session?.customer_details?.email || customer.email || "");
  const status = String(subscription.status ?? "");
  const { paidUntilMs, paid, processing } = paidUntilStripe(subscription);
  const lastInvoice = subscription.latest_invoice && typeof subscription.latest_invoice === "object" ? subscription.latest_invoice : {};
  const invoiceUrl = String(lastInvoice.invoice_pdf || lastInvoice.hosted_invoice_url || "");
  const active = paidUntilMs > 0 && !["canceled", "incomplete_expired", "paused"].includes(status);

  const { data: existing, error: readError } = await admin.from("enterprises").select("id").eq("id", subscriptionId).maybeSingle();
  if (readError) throw new Error("enterprise read failed: " + readError.message);
  // Stripe sometimes sends "subscription created" BEFORE "checkout completed":
  // the name typed by the buyer is not known yet (the customer name is often
  // the card holder's). Nothing is invented: the enterprise, its code and the
  // e-mail wait for the next event.
  if (!existing && !sessionName && !meta.entreprise) {
    console.log("[Stripe]", subscriptionId, ": en attente du nom de l'entreprise (checkout.session.completed)");
    return;
  }
  const newCode = existing ? null : await newEnterpriseCode(admin, name);

  const { data: result, error: applyError } = await admin.rpc("enterprise_apply_stripe", {
    p_id: subscriptionId,
    p_name: name,
    p_seats: seats,
    p_status: status,
    p_paid_until: paidUntilMs > 0 ? new Date(paidUntilMs).toISOString() : null,
    p_active: active,
    p_paid: paid,
    p_email: email,
    p_customer: String(customer.id || subscription.customer || ""),
    p_manage_url: Deno.env.get("STRIPE_PORTAIL") ?? "",
    p_invoice_url: invoiceUrl,
    p_new_code: newCode,
    p_new_code_key: newCode ? normalizeCode(newCode) : null,
  });
  if (applyError || !result) throw new Error("enterprise_apply_stripe failed: " + (applyError?.message ?? "no result"));
  const outcome = result as {
    send: boolean;
    code: string;
    name: string;
    seats: number;
    email: string;
    manage_url: string | null;
    invoice_url: string | null;
  };

  if (outcome.send) {
    // Idempotency key = subscription + code: two simultaneous webhooks (or a
    // retry after a failed `code_sent` update) send a single e-mail.
    const { sujet, texte, html } = contenuCodeEntreprise({
      nom: outcome.name,
      code: outcome.code,
      places: outcome.seats,
      gererUrl: outcome.manage_url ?? "",
      factureUrl: outcome.invoice_url ?? "",
    });
    try {
      await sendResend({
        from: EXPEDITEUR,
        to: [outcome.email],
        reply_to: CONTACT_ENTREPRISE,
        subject: sujet,
        text: texte,
        html,
      }, `code-entreprise/${subscriptionId}/${outcome.code}`);
    } catch (error) {
      // Reservation released: Stripe's retry (500) will try again.
      await admin.from("enterprises").update({ code_send_started_at: null }).eq("id", subscriptionId);
      throw error;
    }
    const { error: sentError } = await admin.from("enterprises")
      .update({ code_sent: true, code_send_started_at: null }).eq("id", subscriptionId);
    if (sentError) console.error("[Stripe] code_sent non enregistré pour", subscriptionId, ":", sentError.message);
  }
  console.log("[Stripe]", subscriptionId, outcome.name, status, seats, "places, payé", paid, processing ? "(SEPA en cours)" : "",
    "fin", paidUntilMs ? new Date(paidUntilMs).toISOString() : "—");
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return text(405, "POST uniquement");
  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
  const admin = adminClient();
  if (!secret || !admin || !Deno.env.get("STRIPE_SECRET_KEY")) return text(503, "non configuré");

  const declared = Number(request.headers.get("content-length") ?? "0");
  if (declared > maxBodyBytes) return text(413, "trop long");
  const raw = new Uint8Array(await request.arrayBuffer());
  if (raw.byteLength > maxBodyBytes) return text(413, "trop long");
  if (!(await verifyStripeSignature(secret, request.headers.get("stripe-signature"), raw))) {
    return text(401, "signature invalide");
  }

  let event: StripeObject;
  try {
    event = JSON.parse(new TextDecoder().decode(raw));
  } catch {
    return text(400, "JSON invalide");
  }
  const type = String(event.type ?? "");
  const { subscriptionId, session } = subscriptionIdFromEvent(event);
  if (!subscriptionId) return json(200, { ok: true, ignore: type });
  try {
    await syncEnterprise(admin, subscriptionId, session);
    return json(200, { ok: true });
  } catch (error) {
    // 500 → Stripe retries (up to 3 days); processing can be replayed.
    console.error("[Stripe]", type, subscriptionId, error instanceof Error ? error.message : error);
    return text(500, "erreur, réessaie");
  }
});
