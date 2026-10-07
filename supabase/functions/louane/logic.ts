// Pure logic of Louane, ported from backend/functions/index.js (Firebase
// `louane`, 06/10/2026): input bounds, sliding window, lexical safety net,
// bubble splitting and all its filters, session marker, quality signals.
// Function bodies are copied unchanged; only TypeScript types were added.
// No I/O here: everything is covered by logic_test.ts.
import catalogue from "./catalogue.json" with { type: "json" };

export type Tour = { role: "user" | "assistant"; content: string };
export type Profil = Record<string, string>;
export type Parcours = {
  actif: boolean;
  termine: boolean;
  titre: string;
  jour: number;
  seanceDuJourFaite: boolean;
  // Native app: id of the next programme session (validated against the catalogue), or "".
  prochaine: string;
  // Native app, goal plans (07/10/2026): plan id, number of steps with the
  // chosen rhythm, and phase of the current step. "" / 0 when not sent.
  plan: PlanId | "";
  etapes: number;
  phase: PhasePlan | "";
};
export const PLANS = ["sleep", "anxiety", "stress", "mind", "self", "relationships"] as const;
export type PlanId = typeof PLANS[number];
export const PHASES_PLAN = ["discovery", "understand", "practice", "anchor"] as const;
export type PhasePlan = typeof PHASES_PLAN[number];
export type Ecoute = { id: string; fois: number; jours: number };
export type Seance = {
  id: string;
  titre: string;
  but: string;
  duree_min: number;
  categorie: string;
  objectif: string;
  type: "meditation" | "respiration";
};
// Ambient sound bundled in the native app (QuietoAmbience), launched with [SON:id].
export type Son = { id: string; titre: string; but: string };

// Native catalogue, generated from app/ios/QuietoNative/.../SessionCatalog.swift
// (94 sessions: 81 guided meditations, 13 breathing exercises).
export const CATALOGUE = catalogue as { source: string; seances: Seance[]; sons: Son[] };

// The nine categories of the native app (QuietoCategory), in its order.
export const NOMS_CATEGORIES: Record<string, string> = {
  discovery: "Découverte",
  work: "Travail",
  relationships: "Relations",
  innerSelf: "Soi & émotions",
  daily: "Quotidien & transitions",
  morning: "Matin & énergie",
  screens: "Écrans & actualité",
  night: "Nuit & sommeil",
  body: "Corps & récupération",
};

// Size bounds: everything the app sends is cut or refused here.
export const BORNES = {
  message: 2000, memoire: 4000, prenom: 40, accueil: 300, jour: 60, heure: 5,
  sante: 1800, historiqueEntrees: 20, historiqueContenu: 2000,
  profilValeur: 120, ecoutes: 20, langue: 8, pourquoi: 90,
};
// Daily quotas (Paris day). IP = safety net against scripts.
export const PLAFOND_IP_LOUANE = 300;
export const ALERTE_MEMOIRE_MS = 24 * 60 * 60 * 1000; // 3114 message: at most once per 24 h

export const texte = (v: unknown, max: number): string => (typeof v === "string" ? v.slice(0, max) : "");

// deno-lint-ignore no-explicit-any
export function nettoyerHistorique(brut: any): Tour[] {
  if (!Array.isArray(brut)) return [];
  return brut
    .filter((m) => m && (m.role === "user" || m.role === "assistant") &&
      typeof m.content === "string" && m.content.trim())
    .slice(-BORNES.historiqueEntrees)
    .map((m) => ({ role: m.role, content: m.content.slice(0, BORNES.historiqueContenu) }));
}

export const CLES_PROFIL = ["goals", "q1", "q_focus", "q2", "q4", "q_minutes"];

// deno-lint-ignore no-explicit-any
export function nettoyerProfil(brut: any): Profil | null {
  if (!brut || typeof brut !== "object") return null;
  const propre: Record<string, string> = {};
  for (const k of CLES_PROFIL) {
    if (typeof brut[k] === "string" && brut[k].trim()) {
      propre[k] = brut[k].slice(0, BORNES.profilValeur);
    }
  }
  return Object.keys(propre).length ? propre : null;
}

// deno-lint-ignore no-explicit-any
export function nettoyerParcours(brut: any): Parcours | null {
  if (!brut || typeof brut !== "object") return null;
  return {
    actif: brut.actif === true,
    termine: brut.termine === true,
    titre: texte(brut.titre, 80),
    jour: Number(brut.jour) || 1,
    seanceDuJourFaite: brut.seanceDuJourFaite === true,
    prochaine: CATALOGUE.seances.some((s) => s.id === brut.prochaine) ? String(brut.prochaine) : "",
    plan: (PLANS as readonly string[]).includes(brut.plan) ? brut.plan as PlanId : "",
    etapes: Math.min(Math.max(Math.trunc(Number(brut.etapes)) || 0, 0), 60),
    phase: (PHASES_PLAN as readonly string[]).includes(brut.phase) ? brut.phase as PhasePlan : "",
  };
}

// deno-lint-ignore no-explicit-any
export function nettoyerEcoutes(brut: any): Ecoute[] | null {
  if (!Array.isArray(brut)) return null;
  return brut.slice(0, BORNES.ecoutes)
    .filter((e) => e && typeof e === "object")
    .map((e) => ({ id: texte(e.id, 40), fois: Number(e.fois) || 1, jours: Number(e.jours) }));
}

export const FENETRE_VOIX_TOURS = 8; // 8 échanges, quel que soit le nombre de bulles (~500 tokens, l'historique est repayé à chaque appel)

export const FENETRE_VEILLEUR_TOURS = 3; // 3 échanges — assez pour le contexte de sécurité

export function derniersTours(historique: Tour[], nbTours: number): Tour[] {
  let vus = 0;
  for (let i = historique.length - 1; i >= 0; i--) {
    if (historique[i] && historique[i].role === "user") {
      vus += 1;
      if (vus === nbTours) return historique.slice(i);
    }
  }
  return historique;
}

export const FILET_LEXICAL: [string, RegExp][] = [
  ["suicide", new RegExp([
    "suicid", // suicide, me suicider, suicidaire, suicidal
    "\\b(me|m')\\s?(tuer|pendre|foutre en l'air|flinguer|buter)\\b",
    "\\ben finir\\b",
    "\\bmettre fin a (mes jours|ma vie)",
    "\\b(envie|besoin) de (mourir|crever|disparaitre)",
    "\\bje (veux|voudrais|vais) (mourir|crever)",
    "\\b(plus|pas) (envie|la force|le courage) de vivre",
    "\\bmourir\\b",
    "\\boverdose\\b",
    "\\bsauter (du|d'un|depuis le|par la) (pont|fenetre|balcon|toit)",
    "\\b(me jeter|sauter) (sous|devant) (un|le) (train|metro|camion|voiture)",
    "\\bkill(ing)? myself\\b",
    "\\bend(ing)? (my life|it all)\\b",
    "\\b(want|wanna|going) to die\\b",
    "\\btake my (own )?life\\b",
  ].join("|"))],
  ["automutilation", new RegExp([
    "\\b(me|m')\\s?faire du mal\\b",
    "scarifi", // scarifier, scarification
    "auto-?mutil", // automutilation, auto-mutilation
    "\\bme (couper|tailler) (les veines|les bras|la peau)",
    "\\bself[- ]?harm",
    "\\b(cut|hurt)(ting)? myself\\b",
  ].join("|"))],
];

export function normaliserPourFilet(message: unknown): string {
  return String(message || "").normalize("NFD").replace(/[̀-ͯ]/g, "")
    .toLowerCase().replace(/[’`´]/g, "'").replace(/\s+/g, " ");
}

export function filetLexicalDetresse(message: unknown): string {
  const t = normaliserPourFilet(message);
  for (const [categorie, re] of FILET_LEXICAL) if (re.test(t)) return categorie;
  return "";
}

export const PLAINTES: [string, RegExp][] = [
  // Elle dit que Louane se répète / repose la même question.
  ["repetition", /tu (te )?r[ée]p[èe]tes|(d[ée]j[àa]|encore) (demand|dit|pos[ée]|r[ée]pondu)|je viens de te (le )?dire|je te l'ai d[ée]j[àa] dit|m[êe]me question|tu tournes en rond|encore cette question|en boucle/i],
  // Elle dit que Louane n'écoute pas / répond à côté.
  ["ecoute", /tu (m')?[ée]coutes? pas|tu (ne )?comprends? (rien|pas)|t'as (rien|pas) compris|tu (r[ée]ponds|es) [àa] c[ôo]t[ée]|tu lis pas|hors sujet|c'est pas ce que j('ai|e t'ai) (dit|demand)/i],
  // Trop de questions.
  ["questions", /(trop|arr[êe]te|assez|marre|stop) (de |des |les |avec (tes|les) )?questions|pose pas de questions|toujours des questions|que des questions|interrogatoire/i],
  // Trop long.
  ["long", /trop long|pav[ée]|abr[èe]ge|fais court|trop de texte|r[ée]sume|trop de blabla/i],
  // Elle conteste que Louane soit une vraie personne (identité).
  ["identite", /\b(robot|chat ?gpt|gpt|une? ia|un bot|intelligence artificielle|un programme|un algorithme|une machine|un llm|un mod[èe]le)\b/i],
  // Le ton sonne faux.
  ["ton", /tu parles (bizarre|mal|comme|chelou|trop bien)|t(u|'es) .{0,25}(bizarre|chelou|robotique|artificiel|faux|fake)|(bizarre|chelou) (ta|cette) (r[ée]ponse|fa[çc]on)/i],
  // Louane ne sert à rien.
  ["inutile", /tu sers [àa] rien|t'es (nulle?|inutile)|tu (m')?aides? pas|[çc]a sert [àa] rien de te parler|tu fais rien/i],
];

export function detecterPlainte(message: unknown): string {
  const m = String(message || "");
  for (const [categorie, re] of PLAINTES) if (re.test(m)) return categorie;
  return "";
}

export function signauxReponse(bulles: string[]) {
  const texte = bulles.join(" ");
  const derniere = bulles[bulles.length - 1] || "";
  return {
    finitParQuestion: /\?\s*$/.test(derniere),
    nbQuestions: (texte.match(/\?/g) || []).length,
    // « plutôt A ou plutôt B ? » (mais pas « ou pas ? »).
    questionAChoix: bulles.some((b) => /\bou\b[^.?!]*\?/.test(b) && !/ou pas( encore)? \?/.test(b)),
    motsReponse: texte.split(/\s+/).filter(Boolean).length,
  };
}

export const DEFAUTS_JUGE = new Set(["question_repetee", "question_a_choix", "deux_questions", "reformulation",
  "ton_psy", "ecrit", "trop_long", "prenom", "a_cote", "invente", "conseil_trop_tot",
  "hors_role", "froide", "familier"]);

export function extraireJson(texte: string): Record<string, unknown> | null {
  try {
    return JSON.parse(texte);
  } catch (_) {
    const m = texte.match(/\{[\s\S]*\}/);
    if (m) {
      try {
        return JSON.parse(m[0]);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

export const MARQUEUR_PARCOURS = "[PARCOURS]";

export const MARQUEUR_ANALYSE = "[ANALYSE]";

export const MARQUEUR_BULLE = "[BULLE]";

export const REGEX_SEANCE = /\[SEANCE:([a-zA-Z0-9_]+)\]/g;

// [SON:id] launches an ambient sound; [POURQUOI:…] is the short line shown on
// the launch card. Both are always removed from the text the person reads.
export const REGEX_SON = /\[SON:([a-z-]+)\]/g;

export const REGEX_POURQUOI = /\[POURQUOI:([^\]\n]{1,200})\]/g;

// Every launch marker, for the cleaning of texts (bubbles, memory, history).
export const sansMarqueursLancement = (t: string): string =>
  t.replace(REGEX_SEANCE, " ").replace(REGEX_SON, " ").replace(REGEX_POURQUOI, " ");

export function sansTiretLong(texte: unknown): string {
  return String(texte || "").replace(/[ \t]*[—–][ \t]*/g, ", ")
    .replace(/[ \t]{2,}/g, " ").trim();
}

export const BULLES_MAX = 5;

export function enPhrases(bulle: unknown): string[] {
  const morceaux = String(bulle || "")
    .split(/(?<=[.?!…]|[\u{1F300}-\u{1FAFF}])\s+(?=[A-ZÀ-ÖØ-Þ«"“(0-9])/u)
    .map((b) => b.trim()).filter(Boolean);
  // Une citation ouverte (« ... ») reste dans la même bulle jusqu'au « ».
  const phrases: string[] = [];
  for (const m of morceaux) {
    const prec = phrases[phrases.length - 1];
    const ouverte = prec && (prec.split("«").length > prec.split("»").length);
    if (ouverte) phrases[phrases.length - 1] = prec + " " + m;
    else phrases.push(m);
  }
  return phrases;
}

export function plafonnerBulles(bulles: string[], max: number): string[] {
  if (bulles.length <= max) return bulles;
  return [...bulles.slice(0, max - 1), bulles.slice(max - 1).join(" ")];
}

export const REGEX_EMOJI = new RegExp("\\p{Extended_Pictographic}|\\uFE0F|\\u200D", "gu");

export function sansEmoji(texte: unknown): string {
  return String(texte || "").replace(REGEX_EMOJI, "")
    .replace(/[ \t]{2,}/g, " ").trim();
}

export const REGEX_ECRITURE_ETRANGERE = new RegExp("[^\\p{Script=Latin}\\p{Script=Common}]", "gu");

// Scripts the app's language needs besides Latin (Japanese, Korean, Chinese):
// they are not "foreign" when the person reads the app in that language.
const ECRITURES_LANGUE: Record<string, string> = {
  ja: "\\p{Script=Hiragana}\\p{Script=Katakana}\\p{Script=Han}",
  ko: "\\p{Script=Hangul}",
  zh: "\\p{Script=Han}",
};

function regexEcritureEtrangere(langue: string): RegExp {
  const autorisees = ECRITURES_LANGUE[langue];
  return autorisees ?
    new RegExp(`[^\\p{Script=Latin}\\p{Script=Common}${autorisees}]`, "u") :
    REGEX_ECRITURE_ETRANGERE;
}

export function aEcritureEtrangere(texte: unknown, langue = "fr"): boolean {
  // Sans /g : pas de lastIndex qui traîne d'un appel à l'autre.
  return new RegExp(regexEcritureEtrangere(langue).source, "u").test(String(texte || "").normalize("NFC"));
}

export function sansEcritureEtrangere(texte: unknown, langue = "fr"): string {
  return String(texte || "").normalize("NFC").replace(new RegExp(regexEcritureEtrangere(langue).source, "gu"), "")
    .replace(/[ \t]{2,}/g, " ").trim();
}

export function apresTuMeTestes(bulles: string[]): string[] {
  const i = bulles.findIndex((b) => /tu me testes/i.test(b));
  return i === -1 ? bulles : bulles.slice(0, i + 1);
}

export const REGEX_DEBUT_QUESTION = /^(qu[’']est-ce|est-ce qu|comment|pourquoi|combien|quel(le)?s?\b|qui\b|où\b|quand\b|à quel|à quoi|de quoi|depuis quand|lequel|laquelle)/iu;

export const REGEX_FIN_QUESTION = /\b(quoi|comment|où|quand|combien|qui|pourquoi|lequel|laquelle|quel(le)?s?\s+\S+)\s*$/iu;

export const REGEX_QUESTION_DOUBLE = /^(.+?),\s+et\s+(?!que\b|qu[’'])(.+)\?\s*$/iu;

export function uneSeuleQuestion(bulles: string[]): { bulles: string[]; retirees: number } {
  let retirees = 0;
  let dejaUne = false;
  const gardees: string[] = [];
  for (const b of bulles) {
    let bulle = b;
    if (/\?\s*$/.test(bulle)) {
      const m = REGEX_QUESTION_DOUBLE.exec(bulle);
      if (m && m[1].split(/\s+/).length >= 3 &&
          (REGEX_DEBUT_QUESTION.test(m[1]) || REGEX_FIN_QUESTION.test(m[1]))) {
        bulle = m[1].trim() + " ?";
        retirees++;
      }
      if (dejaUne) { retirees++; continue; }
      dejaUne = true;
    }
    gardees.push(bulle);
  }
  return { bulles: gardees, retirees };
}

export function sansPointFinal(texte: unknown): string {
  return String(texte || "").replace(/(?<![.…])\.\s*$/u, "").trim();
}

export function sansPrenomFinal(texte: unknown, prenom: string): string {
  const p = String(prenom || "").trim();
  if (!p) return String(texte || "");
  const echappe = p.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return String(texte || "")
    .replace(new RegExp(`(?:,\\s*|\\s+)${echappe}(\\s*)(?=[.?!…]|$)`, "giu"), "$1")
    .replace(/[ \t]{2,}/g, " ").trim();
}

export function bullesDepuisTexte(texteVoix: string, prenom: string, langue = "fr") {
  const texteNettoye = texteVoix.split(MARQUEUR_PARCOURS).join(" ")
    .split(MARQUEUR_ANALYSE).join(" ")
    .replace(REGEX_SEANCE, " ")
    .replace(REGEX_SON, " ")
    .replace(REGEX_POURQUOI, " ")
    .replace(/[ \t]{2,}/g, " ").trim();
  // Découpe en bulles ([BULLE] posé par la Voix) : max 4, jamais de vide.
  // (4 et pas 3 : les messages de fin de découverte ajoutent une bulle
  // séparée obligatoire — elle ne doit jamais sauter à la coupe.)
  // `reponse` reste le texte complet (vieilles apps), `bulles` le découpage.
  let bulles = texteNettoye.split(MARQUEUR_BULLE)
    .map((b) => b.trim()).filter(Boolean);
  // Filet : la Voix écrit parfois deux paragraphes (saut de ligne) au lieu
  // de poser [BULLE]. Deux paragraphes courts = deux messages qui se
  // relancent → on découpe aussi sur les sauts de paragraphe. Les messages
  // longs assumés (> 500 caractères : explication, résumé, questions du
  // programme) restent entiers.
  if (bulles.length === 1 && texteNettoye.length <= 500) {
    bulles = bulles[0].split(/\n{2,}/).map((b) => b.trim()).filter(Boolean);
  }
  // Une phrase = une bulle (demande de Paul, 02/09) : la consigne le dit, ce
  // filet le garantit, même quand la Voix colle deux phrases dans une bulle
  // (« ..., ça rajoute une couche. Et… quoi d'autre ? »). Plafond, le reste
  // fondu dans la dernière bulle : rien n'est jamais perdu (les messages de
  // fin de découverte y compris).
  const nbBullesVoix = bulles.length; // ce que la Voix avait découpé elle-même
  bulles = apresTuMeTestes(plafonnerBulles(bulles.flatMap(enPhrases), BULLES_MAX));
  const nbBullesPhrases = bulles.length; // après « une phrase = une bulle »
  // Une seule question par réponse (demande de Paul, 10/09) : la première
  // reste, les autres sautent (voir uneSeuleQuestion).
  const filtreQuestions = uneSeuleQuestion(bulles);
  bulles = filtreQuestions.bulles;
  // Aucun tiret long ne sort du chat non plus (le nettoyage vient APRÈS le
  // découpage : il ne doit pas effacer les sauts de ligne qui servent à
  // séparer les bulles).
  const avantPrenom = bulles.join("\n");
  // Bulles avec un jeton parasite d'une autre écriture (compté AVANT nettoyage).
  const ecritureEtrangere = bulles.filter((b) => aEcritureEtrangere(b, langue)).length;
  bulles = bulles.map(sansTiretLong).map(sansEmoji).map((b) => sansEcritureEtrangere(b, langue))
    .map((b) => sansPrenomFinal(b, prenom)).map(sansPointFinal).filter(Boolean);
  return {
    bulles,
    // Signaux Vigie : les filets ont-ils dû corriger la Voix ? (compteurs, pas de texte)
    phrasesCoupees: nbBullesPhrases - nbBullesVoix, // > 0 : la Voix collait des phrases
    prenomRetire: avantPrenom !== bulles.join("\n"),
    ecritureEtrangere,
    filtreQuestions,
  };
}

export const GRATUIT_MAX = 40; // messages découverte offerts (au total)

export const PLAFOND_JOUR_ABONNE = 100; // messages/jour pour un abonné (large)

export const REGEX_VIGIE_ID = /^v_[0-9a-f]{16}$/; // format généré par vigie_service.dart

export const REGEX_SESSION_ID = /^s_[0-9a-f]{16}$/;

// [SEANCE:id] marker: the id is only accepted if it exists in the catalogue
// (the model can be wrong). Same logic as `louane` (exec, then lastIndex = 0).
export function seanceDuMarqueur(texteVoix: string): Seance | null {
  const match = REGEX_SEANCE.exec(texteVoix);
  REGEX_SEANCE.lastIndex = 0; // regex /g : on remet le curseur à zéro
  return match ? CATALOGUE.seances.find((s) => s.id === match[1]) || null : null;
}

// [SON:id]: same rule, against the bundled sounds.
export function sonDuMarqueur(texteVoix: string): Son | null {
  const match = REGEX_SON.exec(texteVoix);
  REGEX_SON.lastIndex = 0;
  return match ? CATALOGUE.sons.find((s) => s.id === match[1]) || null : null;
}

// [POURQUOI:…]: one short line, without long dashes, emoji or final period.
export function pourquoiDuMarqueur(texteVoix: string): string {
  const match = REGEX_POURQUOI.exec(texteVoix);
  REGEX_POURQUOI.lastIndex = 0;
  if (!match) return "";
  const ligne = sansPointFinal(sansEmoji(sansTiretLong(match[1].trim())));
  return ligne.length > BORNES.pourquoi ? ligne.slice(0, BORNES.pourquoi - 1).trimEnd() + "…" : ligne;
}

// Language of the app (QuietoLocalization.languageCode): "fr" when unknown.
export const LANGUES: Record<string, string> = {
  fr: "français", en: "anglais", es: "espagnol", de: "allemand", it: "italien",
  pt: "portugais", ja: "japonais", ko: "coréen", zh: "chinois", nl: "néerlandais",
};

export function nettoyerLangue(brut: unknown): string {
  const code = texte(brut, BORNES.langue).toLowerCase().split(/[-_]/)[0];
  return LANGUES[code] ? code : "fr";
}

// Paris day (YYYY-MM-DD): the single "day" window of quotas and counters.
export const jourParis = (date = new Date()): string =>
  new Intl.DateTimeFormat("fr-CA", { timeZone: "Europe/Paris" }).format(date);
