// « Télécharger la facture »: the Stripe PDF, renamed. Replaces the Firebase
// function factureEntreprise. Stripe names the file "Invoice-6K3W8VDG-0003.pdf";
// the button of the e-mail and of the thank-you page goes through here and
// gets "Facture-Quieto-0003.pdf". The secret per-invoice Stripe link stays
// the access key: only pay.stripe.com/invoice/…/pdf links are accepted.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient } from "../_shared/http.ts";
import { ipKey, isStripeInvoicePdf, LIMITS, preflight, text, underLimit } from "../_shared/entreprise.ts";

Deno.serve(async (request: Request) => {
  const options = preflight(request);
  if (options) return options;
  if (request.method !== "GET") return text(405, "GET uniquement");
  const link = new URL(request.url).searchParams.get("u") ?? "";
  if (!isStripeInvoicePdf(link)) return text(400, "Lien de facture invalide.");
  const admin = adminClient();
  if (admin && !(await underLimit(admin, "facture", await ipKey(request), LIMITS.facture))) {
    return text(429, "Trop de téléchargements aujourd'hui, réessayez demain.");
  }
  try {
    const upstream = await fetch(link, { signal: AbortSignal.timeout(8_000) });
    if (!upstream.ok) throw new Error("Stripe " + upstream.status);
    const disposition = upstream.headers.get("content-disposition") ?? "";
    const number = (disposition.match(/-(\d+)\.pdf/i) ?? [])[1];
    const name = number ? `Facture-Quieto-${number}.pdf` : "Facture-Quieto.pdf";
    return new Response(await upstream.arrayBuffer(), {
      status: 200,
      headers: {
        "content-type": "application/pdf",
        "content-disposition": `attachment; filename="${name}"`,
        "cache-control": "private, max-age=3600",
      },
    });
  } catch (error) {
    console.error("[Facture]", error instanceof Error ? error.message : error);
    return text(502, "Facture indisponible pour le moment. Retrouvez-la dans votre espace client.");
  }
});
