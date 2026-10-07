// Stripe Checkout for Quieto Entreprise. Replaces the Firebase function
// paiementEntreprise. The site sends {places, rythme}; the price is computed
// HERE (never the browser's) and a subscription Checkout Session is created:
// yearly or monthly, grid price per employee × exact seats, card or SEPA.
// The subscription carries `places` and `origine` in metadata: stripe-webhook
// creates the enterprise with exactly that number of seats.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, readBody } from "../_shared/http.ts";
import { enterprisePrice, ipKey, json, LIMITS, preflight, SEATS_MAX, SEATS_MIN, text, underLimit } from "../_shared/entreprise.ts";
import { stripeRequest } from "../_shared/stripe.ts";

Deno.serve(async (request: Request) => {
  const options = preflight(request);
  if (options) return options;
  if (request.method !== "POST") return text(405, "POST uniquement");

  const body = await readBody(request, 4 * 1024);
  let d: Record<string, unknown> = {};
  try {
    const parsed = body === null ? null : JSON.parse(body);
    if (parsed && typeof parsed === "object") d = parsed;
  } catch {
    // Same as Firebase: an unreadable body is an empty one.
  }
  const places = parseInt(String(d.places ?? ""), 10);
  const rythme = d.rythme === "mensuel" ? "mensuel" : "annuel";
  if (!(places >= SEATS_MIN && places <= SEATS_MAX)) {
    return json(400, { ok: false, erreur: `de ${SEATS_MIN} à ${SEATS_MAX} places` });
  }

  const key = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
  const site = (Deno.env.get("SITE_ENTREPRISE") ?? "").replace(/\/$/, "");
  const admin = adminClient();
  if (!/^(sk|rk)_/.test(key) || !site || !admin) {
    return json(503, { ok: false, erreur: "paiement pas encore ouvert" });
  }
  if (!(await underLimit(admin, "paiement", await ipKey(request), LIMITS.paiement))) {
    return json(429, { ok: false, erreur: "trop de demandes" });
  }

  const { perPeriod, total } = enterprisePrice(places, rythme);
  const product = Deno.env.get("STRIPE_PRODUIT") ?? "";
  try {
    const session = await stripeRequest("POST", "/checkout/sessions", {
      mode: "subscription",
      locale: "fr",
      line_items: [{
        quantity: places,
        price_data: {
          currency: "eur",
          unit_amount: Math.round(perPeriod * 100),
          recurring: { interval: rythme === "mensuel" ? "month" : "year" },
          ...(product ? { product } : { product_data: { name: "Quieto Entreprise" } }),
        },
      }],
      subscription_data: {
        description: `Quieto Entreprise · ${places} places · ${rythme}`,
        metadata: { origine: "quieto-entreprise", places: String(places), rythme },
      },
      metadata: { origine: "quieto-entreprise", places: String(places), rythme },
      custom_fields: [{
        key: "entreprise",
        label: { type: "custom", custom: "Nom de l'entreprise" },
        type: "text",
        text: { maximum_length: 60 },
      }],
      // Card or SEPA debit only (Stripe would otherwise offer Klarna, Amazon Pay…).
      payment_method_types: ["card", "sepa_debit"],
      // « Managed Payments » off: Cofonde stays the seller and issues invoices.
      managed_payments: { enabled: false },
      billing_address_collection: "required",
      tax_id_collection: { enabled: true },
      allow_promotion_codes: true,
      // Stripe replaces {CHECKOUT_SESSION_ID}: the thank-you page shows the code.
      success_url: site + "/merci.html?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: `${site}/tarifs.html?places=${places}&rythme=${rythme}`,
    }, key);
    return json(200, { ok: true, url: session.url, total });
  } catch (error) {
    console.error("[Paiement]", places, rythme, error instanceof Error ? error.message : error);
    return json(502, { ok: false, erreur: "paiement indisponible" });
  }
});
