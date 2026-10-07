// Louane for the native iOS app, ported from the Firebase callable `louane`
// (backend/functions/index.js, 06/10/2026), without Firebase:
//   - identity: the user's Supabase JWT; access: `user_has_premium` (hard
//     paywall, as louane-proxy did);
//   - the VOIX answers while the VEILLEUR (safety) reads every message in
//     parallel; level 2 → validated 3114 message, once per 24 h;
//   - the Veilleur runs even past the paywall or the daily cap: nobody in
//     danger is cut off to sell a subscription;
//   - counters, quotas, 3114 memory and stats live in Postgres (store.ts).
// Request/response keep the callable format: {"data": {...}} → {"result": {...}}.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";
import { adminClient, readBody, reply } from "../_shared/http.ts";
import {
  BORNES, bullesDepuisTexte, detecterPlainte, MARQUEUR_ANALYSE, MARQUEUR_PARCOURS, nettoyerEcoutes,
  nettoyerHistorique, nettoyerParcours, nettoyerProfil, PLAFOND_IP_LOUANE, PLAFOND_JOUR_ABONNE,
  nettoyerLangue, pourquoiDuMarqueur, REGEX_SESSION_ID, REGEX_VIGIE_ID, sansMarqueursLancement,
  seanceDuMarqueur, signauxReponse, sonDuMarqueur, texte,
} from "./logic.ts";
import { MESSAGE_SECURITE, consigneQuota } from "./prompts.ts";
import { appelJuge, appelMemoire, appelVeilleur, appelVoix } from "./openai.ts";
import {
  alerteRecente, compterParJour, enregistrerStatsLouane, incrementerCompteurs, lireCompteurs, marquerAlerte,
} from "./store.ts";

const maxBodyBytes = 32 * 1024;
// Voix ∥ Veilleur must finish under the app's own 35 s timeout.
const voixBudgetMs = 30_000;

// Callable-style error ({"error": {status, message}}), as Firebase sent them.
function erreur(httpStatus: number, status: string, message: string): Response {
  return reply(httpStatus, { error: { status, message } });
}

// The first X-Forwarded-For entry is whatever the client sent: only the
// address added by the platform's own proxy (cf-connecting-ip, else the LAST
// entry) can be trusted for the per-IP quota.
function clientIP(request: Request): string {
  const cloudflare = (request.headers.get("cf-connecting-ip") ?? "").trim();
  if (cloudflare) return cloudflare.slice(0, 64);
  const forwarded = (request.headers.get("x-forwarded-for") ?? "").split(",").map((part) => part.trim()).filter(Boolean);
  return (forwarded[forwarded.length - 1] ?? "inconnue").slice(0, 64);
}

// Per account: one message at a time and 12 per minute (the daily caps stay
// in logic.ts). The in-flight lock expires by itself after 90 s in SQL, so a
// crash never locks anyone out. A database failure lets the message through,
// like the other quotas (store.ts).
const parMinute = { max: 12, windowSeconds: 60 };
const messageTropRapide = "Doucement : laisse-moi un instant avant ton prochain message.";

async function prendreTour(admin: SupabaseClient, uid: string): Promise<"ok" | "limite"> {
  const [minute, tour] = await Promise.all([
    admin.rpc("rate_limit_hit", {
      p_bucket: "louane_minute", p_subject: uid, p_max: parMinute.max, p_window_seconds: parMinute.windowSeconds,
    }),
    admin.rpc("louane_rate_acquire", { p_user_id: uid }),
  ]);
  if (minute.error) console.error("[Quota] minute illisible (on laisse passer) :", minute.error.message);
  if (tour.error) console.error("[Quota] verrou illisible (on laisse passer) :", tour.error.message);
  const minuteOk = minute.error ? true : minute.data !== false;
  const tourOk = tour.error ? true : tour.data !== false;
  if (minuteOk && tourOk) return "ok";
  // Ne pas garder un verrou pris pour une requête refusée.
  if (tourOk && !tour.error) await rendreTour(admin, uid);
  return "limite";
}

async function rendreTour(admin: SupabaseClient, uid: string): Promise<void> {
  const { error } = await admin.rpc("louane_rate_release", { p_user_id: uid });
  if (error) console.error("[Quota] verrou non rendu (expire seul) :", error.message);
}

// Quota key: the IP is only ever stored hashed.
async function cleIp(ip: string): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(ip)));
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

const reponseSecurite = (categorie: string, memoire: string) => ({
  reponse: MESSAGE_SECURITE,
  bulles: [MESSAGE_SECURITE], // le message de sécurité part d'un bloc
  securite: true,
  niveau: 2,
  categorie,
  memoire, // on ne touche pas à la mémoire pendant l'alerte
});

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const admin = adminClient();
  if (!admin || !Deno.env.get("OPENAI_API_KEY")) return reply(503, { error: "not_configured" });
  const bearer = request.headers.get("authorization") ?? "";
  if (!bearer.startsWith("Bearer ")) return reply(401, { error: "unauthorized" });
  const { data: identity, error: identityError } = await admin.auth.getUser(bearer.slice("Bearer ".length));
  if (identityError || !identity.user) return reply(401, { error: "unauthorized" });
  const uid = identity.user.id;

  if ((await prendreTour(admin, uid)) === "limite") {
    return erreur(429, "RESOURCE_EXHAUSTED", messageTropRapide);
  }
  try {
    return await repondre(request, admin, uid);
  } finally {
    await rendreTour(admin, uid);
  }
});

async function repondre(request: Request, admin: SupabaseClient, uid: string): Promise<Response> {
  const debut = Date.now();

  const body = await readBody(request, maxBodyBytes);
  if (body === null) return reply(413, { error: "payload_too_large" });
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return reply(400, { error: "invalid_json" });
  }
  const racine = parsed && typeof parsed === "object" ? parsed as Record<string, unknown> : {};
  // `{"data": null}` ne doit pas finir en TypeError.
  const d = (racine.data && typeof racine.data === "object" ? racine.data : {}) as Record<string, unknown>;

  const message = texte(d.message, BORNES.message + 1);
  if (!message.trim()) return erreur(400, "INVALID_ARGUMENT", "Le message est vide.");
  if (message.length > BORNES.message) {
    return erreur(400, "INVALID_ARGUMENT", `Message trop long (${BORNES.message} caractères max).`);
  }
  const historique = nettoyerHistorique(d.historique);
  const heure = texte(d.heure, BORNES.heure); // heure locale du téléphone, ex. "23:47"
  const jour = texte(d.jour, BORNES.jour); // jour local en toutes lettres
  const accueil = texte(d.accueil, BORNES.accueil);
  const prenom = texte(d.prenom, BORNES.prenom);
  const memoire = texte(d.memoire, BORNES.memoire); // fiche mémoire de Louane
  const profil = nettoyerProfil(d.profil);
  const parcours = nettoyerParcours(d.parcours);
  const ecoutes = nettoyerEcoutes(d.ecoutes);
  // Apple Santé : seulement « disponible sur l'appareil » (aucune donnée
  // Santé ne quitte l'iPhone ; le champ `sante` n'est plus lu).
  const santeDispo = d.santeDispo === true;
  // Langue de l'app : Louane répond dans cette langue ("fr" par défaut).
  const langue = nettoyerLangue(d.langue);
  const vigie = REGEX_VIGIE_ID.test(texte(d.vigie, 40)) ? String(d.vigie) : "";
  const session = REGEX_SESSION_ID.test(texte(d.session, 40)) ? String(d.session) : "";

  // Abonnement, compteurs et quota réseau EN PARALLÈLE.
  const [premium, compteurs, quotaOk] = await Promise.all([
    admin.rpc("user_has_premium", { p_user_id: uid }),
    lireCompteurs(admin, uid),
    cleIp(clientIP(request)).then((cle) => compterParJour(admin, "ip", cle, "louane", PLAFOND_IP_LOUANE)),
  ]);
  if (!quotaOk) return erreur(429, "RESOURCE_EXHAUSTED", "Trop d'appels depuis ce réseau aujourd'hui.");
  if (premium.error) return reply(503, { error: "entitlement_unavailable" });
  const abonne = premium.data === true;
  const compteurTotal = compteurs ? compteurs.total : 0;
  const compteurJour = compteurs ? compteurs.n : 0;
  const deadline = debut + voixBudgetMs;

  // Socle commun d'une ligne de stats (sans texte, sans prénom, sans compte).
  const statsBase = {
    source: "native",
    vigie,
    session,
    abonne,
    compteurTotal,
    compteurJour,
    heure: heure.includes(":") ? parseInt(heure.split(":")[0], 10) : null,
    carMessage: message.length,
    nbMessagesHistorique: historique.length,
    avecSante: false,
  };

  // Limite atteinte : pas de Voix, mais le Veilleur vérifie quand même le
  // message. Danger → le message de sécurité part quoi qu'il arrive. Sinon,
  // signal paywall/plafond. App native = MUR DUR : sans Premium, aucun
  // message découverte (les 40 messages offerts restent à l'app Flutter).
  const limiteGratuit = !abonne;
  const limiteAbonne = abonne && compteurJour >= PLAFOND_JOUR_ABONNE;
  if (limiteGratuit || limiteAbonne) {
    const veilleurSeul = await appelVeilleur(historique, message, deadline);
    await enregistrerStatsLouane(admin, {
      ...statsBase,
      niveau: veilleurSeul.niveau,
      categorie: veilleurSeul.categorie,
      veilleurSecours: !!veilleurSeul.secours,
      paywall: limiteGratuit,
      plafond: limiteAbonne,
      carReponse: 0,
    });
    if (veilleurSeul.niveau === 2 && !(await alerteRecente(admin, uid))) {
      await marquerAlerte(admin, uid);
      console.warn("[Veilleur] ALERTE niveau 2 (hors quota) :", veilleurSeul.categorie);
      return reply(200, { result: reponseSecurite(veilleurSeul.categorie, memoire) });
    }
    return reply(200, {
      result: {
        reponse: "",
        bulles: [],
        paywall: limiteGratuit,
        plafond: limiteAbonne,
        niveau: veilleurSeul.niveau,
        memoire,
      },
    });
  }

  // La Voix et le Veilleur EN PARALLÈLE. Une panne de la Voix n'emporte pas
  // le Veilleur : en danger, le message de sécurité part quand même.
  let erreurVoix = null as unknown; // (cast : affecté dans le catch, pas de rétrécissement à null)
  const [texteVoix, veilleur] = await Promise.all([
    appelVoix({
      historique, message, heure, jour, prenom, memoire, profil, accueil, parcours, ecoutes, santeDispo,
      langue, quota: consigneQuota(abonne, compteurTotal),
    }, deadline).catch((e) => {
      erreurVoix = e;
      return "";
    }),
    appelVeilleur(historique, message, deadline),
  ]);
  if (erreurVoix) {
    if (veilleur.niveau === 2) {
      // Mieux vaut répéter le 3114 qu'afficher une erreur à quelqu'un en danger.
      console.error("[Voix] erreur, niveau 2 → message de sécurité :", erreurVoix);
      await marquerAlerte(admin, uid);
      await enregistrerStatsLouane(admin, {
        ...statsBase, niveau: 2, categorie: veilleur.categorie, paywall: false, plafond: false,
        carReponse: MESSAGE_SECURITE.length, voixEnPanne: true, veilleurSecours: !!veilleur.secours,
      });
      return reply(200, { result: reponseSecurite(veilleur.categorie, memoire) });
    }
    console.error("[Voix] erreur :", erreurVoix);
    return erreur(500, "INTERNAL", "INTERNAL");
  }
  // Message répondu → compté côté serveur.
  await incrementerCompteurs(admin, uid);

  // [PARCOURS] et [ANALYSE] sont TOUJOURS retirés du texte (bullesDepuisTexte)
  // et ne lèvent plus aucun signal : l'app native construit son programme
  // elle-même et n'envoie aucune donnée Santé.
  const marqueurPresent = texteVoix.includes(MARQUEUR_PARCOURS) || texteVoix.includes(MARQUEUR_ANALYSE);
  // [SEANCE:id] : signal seulement si l'id existe dans le catalogue natif.
  const seanceTrouvee = seanceDuMarqueur(texteVoix);
  // [SON:id] et [POURQUOI:…] : même validation contre le catalogue natif.
  const sonTrouve = sonDuMarqueur(texteVoix);
  const pourquoi = pourquoiDuMarqueur(texteVoix);
  const { bulles, phrasesCoupees, prenomRetire, ecritureEtrangere, filtreQuestions } =
    bullesDepuisTexte(texteVoix, prenom, langue);
  const texteComplet = bulles.join("\n\n");
  // Garde : jamais de lancement de séance sur un message en danger.
  const seance = veilleur.niveau === 2 ? null : seanceTrouvee;
  const son = veilleur.niveau === 2 ? null : sonTrouve;
  // Filet : jamais de bulle vide (la Voix n'a envoyé que des marqueurs).
  const reponseFinale = texteComplet || "Je suis là, je t'écoute.";

  const statsReponse = {
    ...statsBase,
    niveau: veilleur.niveau,
    categorie: veilleur.categorie,
    veilleurSecours: !!veilleur.secours,
    paywall: false,
    plafond: false,
    parcoursPropose: false,
    marqueurProgrammeRetire: marqueurPresent,
    analyseSante: false,
    seanceLancee: seance ? seance.id : "",
    sonLance: son ? son.id : "",
    carReponse: reponseFinale.length,
    nbBulles: bulles.length || 1,
    plainte: detecterPlainte(message),
    ...signauxReponse(bulles.length ? bulles : [reponseFinale]),
    phrasesCoupees: Math.max(0, phrasesCoupees),
    prenomRetire,
    questionsRetirees: filtreQuestions.retirees,
    ecritureEtrangere,
  };

  // Niveau 2 : le message de sécurité validé, UNE SEULE FOIS par 24 h ; déjà
  // donné → Louane continue d'accompagner avec la Voix.
  if (veilleur.niveau === 2 && !(await alerteRecente(admin, uid))) {
    await marquerAlerte(admin, uid);
    console.warn("[Veilleur] ALERTE niveau 2 :", veilleur.categorie);
    await enregistrerStatsLouane(admin, statsReponse);
    return reply(200, { result: reponseSecurite(veilleur.categorie, memoire) });
  }

  // Mémoire (un échange sur trois, ou tout de suite si la fiche est vide) et
  // Juge à la même cadence, en parallèle.
  const nbEchangesAvant = historique.filter((m) => m && m.role === "user").length;
  const memoireDue = !memoire || nbEchangesAvant % 3 === 2;
  const [nouvelleMemoire, juge] = await Promise.all([
    memoireDue ?
      appelMemoire(memoire,
        [...historique.slice(-4).map((m) =>
          (m.role === "user" ? "La personne : " : "Louane : ") +
          sansMarqueursLancement(String(m.content)).trim()),
        "La personne : " + message,
        "Louane : " + reponseFinale].join("\n")) :
      Promise.resolve(memoire),
    memoireDue ? appelJuge(historique, message, reponseFinale) : Promise.resolve(null),
  ]);
  await enregistrerStatsLouane(admin, { ...statsReponse, ...(juge || {}) });
  return reply(200, {
    result: {
      reponse: reponseFinale,
      bulles: bulles.length ? bulles : [reponseFinale],
      securite: false,
      niveau: veilleur.niveau,
      memoire: nouvelleMemoire,
      parcoursPropose: false,
      analyseSante: false,
      analyseApres: 0,
      finDecouverte: false,
      seance: seance ?
        {
          id: seance.id,
          titre: seance.titre,
          duree_min: seance.duree_min,
          categorie: seance.categorie,
          type: seance.type,
          premium: false,
          raison: pourquoi,
        } :
        null,
      // Son d'ambiance lancé avec la réponse (seul ou après la séance).
      son: son ? { id: son.id, titre: son.titre, raison: seance ? "" : pourquoi } : null,
    },
  });
}
