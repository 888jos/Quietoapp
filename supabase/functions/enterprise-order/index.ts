// Thank-you page of the site: the code right away on screen. Replaces the
// Firebase function commandeEntreprise. Stripe sends the buyer back to
// merci.html?session_id=cs_…; the page asks here for the code of ITS order.
// The session is read again at Stripe (payment complete?), then the
// enterprise created by stripe-webhook. The session id is only known to the
// buyer (it is in their return URL).
// 202 = the webhook has not run yet: the page asks again a bit later.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient } from "../_shared/http.ts";
import { invoiceLink, ipKey, json, LIMITS, messageATransferer, preflight, underLimit } from "../_shared/entreprise.ts";
import { stripeRequest } from "../_shared/stripe.ts";

Deno.serve(async (request: Request) => {
  const options = preflight(request);
  if (options) return options;
  let id = new URL(request.url).searchParams.get("session") ?? "";
  if (!id && request.method === "POST") {
    try {
      id = String((await request.json())?.session ?? "");
    } catch {
      id = "";
    }
  }
  if (!/^cs_(test|live)_[A-Za-z0-9]{10,200}$/.test(id)) return json(400, { ok: false });
  const admin = adminClient();
  if (!admin || !Deno.env.get("STRIPE_SECRET_KEY")) return json(503, { ok: false });
  if (!(await underLimit(admin, "commande", await ipKey(request), LIMITS.commande))) return json(429, { ok: false });

  try {
    const session = await stripeRequest("GET", "/checkout/sessions/" + encodeURIComponent(id));
    if (session.status !== "complete" || typeof session.subscription !== "string") return json(404, { ok: false });
    const { data: enterprise, error } = await admin.from("enterprises")
      .select("name, code, seats, billing_email, manage_url, invoice_url")
      .eq("id", session.subscription).maybeSingle();
    if (error) throw new Error(error.message);
    if (!enterprise?.code) return json(202, { ok: true, pret: false });
    return json(200, {
      ok: true,
      pret: true,
      nom: enterprise.name,
      code: enterprise.code,
      places: enterprise.seats,
      email: enterprise.billing_email ?? "",
      gererUrl: enterprise.manage_url ?? "",
      factureUrl: invoiceLink(enterprise.invoice_url),
      message: messageATransferer(enterprise.name, enterprise.code),
    });
  } catch (error) {
    console.error("[Commande]", id.slice(0, 14), error instanceof Error ? error.message : error);
    return json(502, { ok: false });
  }
});
