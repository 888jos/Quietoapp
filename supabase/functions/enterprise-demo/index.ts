// « Demander une démo » form of the Quieto Entreprise site. Replaces the
// Firebase function demandeEntreprise. The request is stored in
// public.enterprise_demo_requests (business contact, no health data) and sent
// by e-mail to CONTACT_ENTREPRISE, replying straight to the sender.
// Safety nets: honeypot field « site » (bots), 5 requests / day / network.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, readBody } from "../_shared/http.ts";
import { CONTACT_ENTREPRISE, EXPEDITEUR, ipKey, json, LIMITS, preflight, sendResend, text, underLimit } from "../_shared/entreprise.ts";

Deno.serve(async (request: Request) => {
  const options = preflight(request);
  if (options) return options;
  if (request.method !== "POST") return text(405, "POST uniquement");
  const admin = adminClient();
  if (!admin || !Deno.env.get("RESEND_API_KEY")) return json(503, { ok: false, erreur: "non configuré" });

  const body = await readBody(request, 16 * 1024);
  if (body === null) return json(413, { ok: false, erreur: "trop long" });
  let d: Record<string, unknown> = {};
  try {
    const parsed = JSON.parse(body);
    if (parsed && typeof parsed === "object") d = parsed;
  } catch {
    return json(400, { ok: false, erreur: "champs manquants" });
  }
  if (d.site) return json(200, { ok: true }); // honeypot filled: a bot. Say "ok", do nothing.

  const field = (key: string, max: number) => (typeof d[key] === "string" ? (d[key] as string).slice(0, max) : "").trim();
  const demande = {
    profil: field("profil", 60), prenom: field("prenom", 60), nom: field("nom", 60),
    email: field("email", 120), entreprise: field("entreprise", 100),
    telephone: field("telephone", 30), taille: field("taille", 40), message: field("message", 2000),
  };
  if (!demande.prenom || !demande.nom || !demande.entreprise || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(demande.email)) {
    return json(400, { ok: false, erreur: "champs manquants" });
  }
  if (!(await underLimit(admin, "demande", await ipKey(request), LIMITS.demande))) {
    return json(429, { ok: false, erreur: "trop de demandes" });
  }

  const { error: insertError } = await admin.from("enterprise_demo_requests").insert({
    profile: demande.profil || null,
    first_name: demande.prenom,
    last_name: demande.nom,
    email: demande.email,
    company: demande.entreprise,
    phone: demande.telephone || null,
    company_size: demande.taille || null,
    message: demande.message || null,
  });
  if (insertError) console.error("[Démo] demande non rangée :", insertError.message);

  const lignes = [
    `Profil : ${demande.profil || "—"}`,
    `Nom : ${demande.prenom} ${demande.nom}`,
    `E-mail : ${demande.email}`,
    `Téléphone : ${demande.telephone || "—"}`,
    `Entreprise : ${demande.entreprise}`,
    `Taille : ${demande.taille || "—"}`,
    "",
    demande.message || "(pas de message)",
  ];
  try {
    await sendResend({
      from: EXPEDITEUR,
      to: [CONTACT_ENTREPRISE],
      reply_to: demande.email,
      subject: `Quieto Entreprise : demande de ${demande.entreprise}${demande.taille ? " (" + demande.taille + ")" : ""}`,
      text: lignes.join("\n"),
    });
  } catch (error) {
    console.error("[Démo] e-mail non envoyé :", error instanceof Error ? error.message : error);
    return json(502, { ok: false, erreur: "envoi impossible" });
  }
  return json(200, { ok: true });
});
