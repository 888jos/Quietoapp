// Quieto Entreprise (B2B): shared pieces of the Edge Functions that replace
// the Firebase functions demandeEntreprise, paiementEntreprise,
// factureEntreprise, commandeEntreprise, stripe and accesEntreprise
// (backend/functions/index.js). Texts, prices and rules are copied as is.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";

// Contact address of Quieto Entreprise (site quietopro.com): receives demo
// requests and replies to the code e-mail (HR).
export const CONTACT_ENTREPRISE = "quieto@cofonde.com";
// The domain must be verified in Resend (SPF + DKIM).
export const EXPEDITEUR = "Quieto <quieto@cofonde.com>";

// Daily caps (same values as PLAFOND_IP / PLAFOND_UID in Firebase).
export const LIMITS = {
  demande: 5,
  paiement: 40,
  commande: 120,
  facture: 60,
  entreprise: 30,
  entrepriseUser: 10,
} as const;

// ── CORS: the site calls these functions from the browser ──
// Same openness as Firebase `cors: true` (any origin reflected).
const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
  "access-control-max-age": "86400",
};

export function preflight(request: Request): Response | null {
  return request.method === "OPTIONS" ? new Response(null, { status: 204, headers: corsHeaders }) : null;
}

export function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

export function text(status: number, body: string): Response {
  return new Response(body, { status, headers: { ...corsHeaders, "content-type": "text/plain; charset=utf-8" } });
}

// ── Rate limits (filet, pas le produit) ──
async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** Hashed client IP (never stored in clear), same convention as louane-proxy. */
export async function ipKey(request: Request): Promise<string> {
  const forwarded = request.headers.get("x-forwarded-for") ?? "";
  const first = forwarded.split(",").map((part) => part.trim()).find(Boolean);
  const ip = (first ?? request.headers.get("cf-connecting-ip") ?? "inconnue").slice(0, 64);
  return (await sha256Hex(ip)).slice(0, 32);
}

/** false when the daily cap is reached. A database failure lets the call through. */
export async function underLimit(admin: SupabaseClient, bucket: string, subject: string, limit: number): Promise<boolean> {
  const { data, error } = await admin.rpc("consume_rate_limit", { p_bucket: bucket, p_subject: subject, p_limit: limit });
  if (error) {
    console.error("[Quota]", bucket, "illisible (on laisse passer) :", error.message);
    return true;
  }
  return data === true;
}

// ── Codes ──
// No 0/O, 1/I/L: readable aloud and copied without mistakes.
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

/** "acme-7k2p", "ACME 7K2P", "Acmé7k2p" → "ACME7K2P". */
export function normalizeCode(raw: unknown): string {
  return String(raw ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "")
    .toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 24);
}

export function candidateCode(name: string): string {
  let prefix = normalizeCode(name).replace(/[0-9]/g, "").slice(0, 6);
  if (prefix.length < 3) prefix = "QUIETO";
  let suffix = "";
  for (const byte of crypto.getRandomValues(new Uint8Array(4))) suffix += CODE_ALPHABET[byte % CODE_ALPHABET.length];
  return prefix + "-" + suffix;
}

export async function newEnterpriseCode(admin: SupabaseClient, name: string): Promise<string> {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const code = candidateCode(name);
    const { data, error } = await admin.from("enterprises").select("id").eq("code_key", normalizeCode(code)).limit(1);
    if (error) throw new Error("code lookup failed: " + error.message);
    if (!data?.length) return code;
  }
  throw new Error("aucun code libre trouvé");
}

// ── Price grid (page « Tarifs »): this one is authoritative ──
// Same grid as Headspace small business (23/09/2026), € HT per employee and
// per year. Monthly = yearly ÷ 10. ⚠️ A display copy lives in
// sites/entreprise/assets/js/site.js: both must stay identical.
export const PRICE_GRID: [number, number][] = [
  [800, 44.88], [600, 45.96], [450, 47.16], [350, 48.36],
  [250, 49.56], [150, 52.56], [50, 54.30], [10, 56.04],
];
export const SEATS_MIN = 10;
export const SEATS_MAX = 999;

export function enterprisePrice(seats: number, rhythm: "annuel" | "mensuel") {
  const yearlyPerSeat = PRICE_GRID.find(([min]) => seats >= min)![1];
  // Per-seat price rounded to the cent BEFORE multiplying: the total shown
  // on the site (unit price × seats) is exact.
  const perPeriod = Math.round((rhythm === "mensuel" ? yearlyPerSeat / 10 : yearlyPerSeat) * 100) / 100;
  return { yearlyPerSeat, perPeriod, total: Math.round(perPeriod * seats * 100) / 100 };
}

// ── Invoice links ──
// Only pay.stripe.com/invoice/…/pdf links (secret, one per invoice).
export function isStripeInvoicePdf(value: unknown): boolean {
  try {
    const url = new URL(String(value ?? ""));
    return url.protocol === "https:" && url.hostname === "pay.stripe.com" &&
      url.pathname.startsWith("/invoice/") && url.pathname.endsWith("/pdf");
  } catch {
    return false;
  }
}

/** Download button of the e-mail and of the thank-you page: through enterprise-invoice (file renamed). */
export function invoiceLink(invoiceUrl: unknown): string {
  const base = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
  return isStripeInvoicePdf(invoiceUrl) && base
    ? `${base}/functions/v1/enterprise-invoice?u=${encodeURIComponent(String(invoiceUrl))}`
    : String(invoiceUrl ?? "");
}

// ── Resend ──
/**
 * POST to Resend with an optional idempotency key (kept 24 h by Resend):
 * 409 on a reused key is treated as "already sent". Throws on other errors.
 */
export async function sendResend(body: Record<string, unknown>, idempotencyKey?: string): Promise<void> {
  const headers: Record<string, string> = {
    "authorization": "Bearer " + (Deno.env.get("RESEND_API_KEY") ?? ""),
    "content-type": "application/json",
  };
  if (idempotencyKey) headers["idempotency-key"] = await sha256Hex(idempotencyKey);
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(8_000),
  });
  if (response.status === 409 && idempotencyKey) {
    console.warn("[Resend] clé d'idempotence déjà utilisée : e-mail considéré comme envoyé.");
    return;
  }
  if (!response.ok) {
    const detail = (await response.text().catch(() => "")).slice(0, 300);
    throw new Error(`Resend ${response.status} : ${detail}`);
  }
}

// ── Texts (copied from Firebase, validated by Paul: keep as is) ──
const LIEN_APP_STORE = "https://apps.apple.com/fr/app/quieto/id6764535642";
const LIEN_PLAY_STORE = "https://play.google.com/store/apps/details?id=com.quieto.quieto";

/** Message HR forwards to the team: in the e-mail AND on the thank-you page. */
export function messageATransferer(nom: string, code: string): string {
  return `Bonne nouvelle : ${nom} vous offre Quieto Premium.\n\n` +
    "Quieto vous aide à souffler quand la pression monte, au bureau comme à la maison :\n" +
    "• des séances guidées de 1 à 14 minutes, pour avant une réunion, un coup de stress, " +
    "une actualité qui pèse ou une nuit sans sommeil ;\n" +
    "• Louane, à qui écrire à toute heure quand ça déborde ;\n" +
    "• un programme de 7 jours, construit pour vous.\n\n" +
    "C'est offert, et ça reste entre vous et l'application : " +
    "votre employeur ne voit rien de ce que vous y faites.\n\n" +
    "Pour l'activer (1 minute) :\n" +
    `1. Téléchargez Quieto : ${LIEN_APP_STORE} (iPhone) ou ${LIEN_PLAY_STORE} (Android)\n` +
    "2. Dans l'app, ouvrez Profil → « Accès offert par mon entreprise »\n" +
    `3. Connectez-vous avec Apple ou Google, puis entrez le code ${code}`;
}

export interface CodeEmail {
  nom: string;
  code: string;
  places: number;
  gererUrl: string;
  factureUrl: string;
}

export function contenuCodeEntreprise({ nom, code, places, gererUrl, factureUrl: pdf }: CodeEmail) {
  const factureUrl = invoiceLink(pdf);
  const sujet = `Votre accès Quieto est prêt : code ${code}`;
  const aTransferer = messageATransferer(nom, code);
  const texte =
    "Bonjour,\n\n" +
    `Merci d'offrir Quieto à votre équipe. Votre abonnement couvre ${places} personne${places > 1 ? "s" : ""}.\n\n` +
    `Votre code entreprise : ${code}\n\n` +
    "Voici un message prêt à transférer à vos salariés :\n\n" +
    "----------\n" + aTransferer + "\n----------\n\n" +
    "Confidentialité : nous ne partageons aucune donnée individuelle avec l'employeur, " +
    "ni qui utilise l'application, ni ce qui s'y dit.\n\n" +
    (factureUrl ? `Télécharger la facture : ${factureUrl}\n\n` : "") +
    (gererUrl ? `Factures, moyen de paiement, forfait : ${gererUrl}\n\n` : "") +
    "Une question ? Répondez simplement à cet e-mail.\n\nL'équipe Quieto";
  const esc = (value: unknown) => String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const html = `<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:560px;margin:auto;color:#1B2F4E;line-height:1.55">
  <p>Bonjour,</p>
  <p>Merci d'offrir Quieto à votre équipe. Votre abonnement couvre <b>${places} personne${places > 1 ? "s" : ""}</b>.</p>
  <p style="margin:28px 0;text-align:center"><span style="display:inline-block;padding:14px 22px;border-radius:12px;background:#EAF6F4;font-size:24px;letter-spacing:2px;font-weight:600">${esc(code)}</span></p>
  <p>Voici un message prêt à transférer à vos salariés :</p>
  <div style="border-left:3px solid #4FB3A5;padding:4px 16px;margin:16px 0;white-space:pre-line">${esc(aTransferer)}</div>
  <p style="font-size:14px">Confidentialité : nous ne partageons aucune donnée individuelle avec l'employeur, ni qui utilise l'application, ni ce qui s'y dit.</p>
  ${factureUrl ? `<p style="margin:28px 0;text-align:center"><a href="${esc(factureUrl)}" style="display:inline-block;padding:14px 28px;border-radius:999px;background:#1B2F4E;color:#FFFFFF;font-size:16px;font-weight:600;text-decoration:none">Télécharger la facture</a></p>` : ""}
  ${gererUrl ? `<p style="font-size:14px">Factures, moyen de paiement, forfait : <a href="${esc(gererUrl)}">gérer l'abonnement</a></p>` : ""}
  <p>Une question ? Répondez simplement à cet e-mail.</p>
  <p>L'équipe Quieto</p>
</div>`;
  return { sujet, texte, html };
}
