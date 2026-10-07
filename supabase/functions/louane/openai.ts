// OpenAI calls of Louane over plain fetch (no Node SDK): Voix, Veilleur,
// Mémoire, Juge. Same model, parameters and messages as the Firebase
// `louane` function; the SDK behaviour it relied on (timeout, one retry on
// network errors / 408 / 409 / 429 / 5xx) is reproduced in `chat`.
import {
  CONSIGNE_CATALOGUE, CONSIGNE_GUIDE_BESOINS, CONSIGNE_POURQUOI, CONSIGNE_PRESENTATION, CONSIGNE_PROGRAMME_NATIF,
  CONSIGNE_SEANCE_LANCEMENT, CONSIGNE_SONS, consigneLangue,
  consigneAccueil, consigneEcoutes, consigneHeure, consigneJour, consigneMemoire, consigneParcours,
  consigneProfil, consigneSante, PROMPT_JUGE, PROMPT_MEMOIRE, PROMPT_VEILLEUR, PROMPT_VOIX,
} from "./prompts.ts";
import {
  DEFAUTS_JUGE, derniersTours, type Ecoute, extraireJson, FENETRE_VEILLEUR_TOURS, FENETRE_VOIX_TOURS,
  filetLexicalDetresse, type Parcours, type Profil, sansMarqueursLancement, type Tour,
} from "./logic.ts";

// Le modèle de TOUS les appels (Voix, Mémoire, Veilleur, Juge). Même valeur
// que MODELE dans backend/functions/index.js : changer de modèle = cette
// ligne, puis rejouer le banc (backend/functions/banc/banc-voix.mjs).
export const MODELE = "gpt-5.6-luna";

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

type CallOptions = { timeoutMs: number; maxRetries: number; deadline?: number };
// Voix et Veilleur : 20 s, un réessai (client du 06/10/2026).
const OPTIONS_PAR_DEFAUT: CallOptions = { timeoutMs: 20_000, maxRetries: 1 };
// Mémoire et Juge tournent APRÈS la Voix, la personne attend : délai court
// et pas de réessai (ils retombent déjà proprement en cas d'échec).
const OPTIONS_APRES_REPONSE: CallOptions = { timeoutMs: 12_000, maxRetries: 0 };

type ChatResponse = {
  choices?: { message?: { content?: string | null } }[];
  usage?: unknown;
};

export class OpenAIError extends Error {
  constructor(message: string, readonly status = 0) {
    super(message);
  }
}

function cleOpenAI(): string {
  const key = Deno.env.get("OPENAI_API_KEY") ?? "";
  if (!key) throw new OpenAIError("OPENAI_API_KEY absente");
  return key;
}

const retryable = (status: number) => status === 408 || status === 409 || status === 429 || status >= 500;

/** POST /v1/chat/completions with a bounded delay. `deadline` (epoch ms)
 * keeps a retry from outliving the app's own 35 s timeout. */
export async function chat(body: Record<string, unknown>, options: CallOptions = OPTIONS_PAR_DEFAUT): Promise<ChatResponse> {
  const key = cleOpenAI();
  let lastError: unknown = null;
  for (let attempt = 0; attempt <= options.maxRetries; attempt += 1) {
    const remaining = options.deadline ? options.deadline - Date.now() : options.timeoutMs;
    if (attempt > 0 && remaining < 3_000) break;
    const timeout = Math.max(1_000, Math.min(options.timeoutMs, remaining));
    try {
      const response = await fetch(OPENAI_URL, {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${key}` },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(timeout),
      });
      if (response.ok) return await response.json() as ChatResponse;
      const detail = (await response.text()).slice(0, 300);
      lastError = new OpenAIError(`OpenAI HTTP ${response.status}: ${detail}`, response.status);
      if (!retryable(response.status)) break;
    } catch (cause) {
      lastError = cause;
    }
    if (attempt < options.maxRetries) await new Promise((resolve) => setTimeout(resolve, 500 * (attempt + 1)));
  }
  throw lastError instanceof Error ? lastError : new OpenAIError(String(lastError));
}

const contenu = (r: ChatResponse) => (r.choices && r.choices[0] && r.choices[0].message && r.choices[0].message.content) || "";

export type ContexteVoix = {
  historique: Tour[];
  message: string;
  heure: string;
  jour: string;
  prenom: string;
  memoire: string;
  profil: Profil | null;
  accueil: string;
  parcours: Parcours | null;
  ecoutes: Ecoute[] | null;
  santeDispo: boolean;
  langue: string;
  quota: string;
};

// Bloc FIXE (mis en cache côté OpenAI, identique pour tout le monde) : rien
// qui varie d'un appel à l'autre ici. CONSIGNE_PROGRAMME_NATIF remplace
// CONSIGNE_PARCOURS_OFFRE (l'app native construit son programme elle-même).
export const PROMPT_FIXE_VOIX = PROMPT_VOIX + CONSIGNE_CATALOGUE + CONSIGNE_PROGRAMME_NATIF +
  CONSIGNE_SEANCE_LANCEMENT + CONSIGNE_GUIDE_BESOINS + CONSIGNE_SONS + CONSIGNE_POURQUOI +
  CONSIGNE_PRESENTATION;

// Bloc VARIABLE. consigneCreuser (le fil « creuser puis proposer le
// programme ») n'est pas porté : Louane ne propose plus de programme.
export function promptVariableVoix(c: ContexteVoix): string {
  return consigneHeure(c.heure) + consigneJour(c.jour) +
    consigneMemoire(c.prenom, c.memoire) + consigneProfil(c.profil) +
    consigneAccueil(c.accueil) + consigneParcours(c.parcours) +
    consigneEcoutes(c.ecoutes) + consigneSante(c.santeDispo) +
    consigneLangue(c.langue) + (c.quota || "");
}

// Appel de la Voix. Peut échouer → l'erreur remonte. Pas de temperature.
export async function appelVoix(c: ContexteVoix, deadline?: number): Promise<string> {
  const reponse = await chat({
    model: MODELE,
    // Luna "réfléchit" un peu avant d'écrire : ces reasoning_tokens comptent
    // dans le plafond → marge au-dessus des ~1000 tokens de réponse utile.
    max_completion_tokens: 1500,
    // Cache explicite : un point de coupe à la fin du bloc FIXE.
    prompt_cache_key: "quieto-voix-2",
    prompt_cache_options: { mode: "explicit", ttl: "30m" },
    messages: [
      {
        role: "system",
        content: [{ type: "text", text: PROMPT_FIXE_VOIX, prompt_cache_breakpoint: { mode: "explicit" } }],
      },
      { role: "system", content: promptVariableVoix(c) },
      ...derniersTours(c.historique, FENETRE_VOIX_TOURS),
      { role: "user", content: c.message },
    ],
  }, { ...OPTIONS_PAR_DEFAUT, deadline });
  console.log("[Voix] usage:", JSON.stringify(reponse.usage));
  return contenu(reponse);
}

export type Verdict = { niveau: number; categorie: string; raison: string; secours?: boolean };

// Verdict de secours quand le Veilleur n'a pas pu trancher : niveau 2 si le
// filet lexical accroche, niveau 0 sinon. Toujours journalisé.
export function verdictSecours(message: string, cause: string): Verdict {
  const categorie = filetLexicalDetresse(message);
  if (categorie) {
    console.warn("[Veilleur] muet (" + cause + ") : filet lexical → niveau 2 (" + categorie + ")");
    return { niveau: 2, categorie, raison: "filet_lexical", secours: true };
  }
  console.error("[Veilleur] muet (" + cause + ") : filet lexical muet → niveau 0");
  return { niveau: 0, categorie: "aucune", raison: "", secours: true };
}

// Lecture du JSON du Veilleur : `niveau` absent ou hors 0/1/2 = verdict
// illisible (→ filet lexical), pas un « tout va bien ».
export function lireVerdict(brut: string, message: string): Verdict {
  const signal = extraireJson(brut);
  const niveau = signal && signal.niveau !== undefined && signal.niveau !== null &&
      signal.niveau !== "" ? Number(signal.niveau) : NaN;
  if (niveau === 1 || niveau === 2) {
    return { niveau, categorie: String(signal?.categorie || ""), raison: String(signal?.raison || "") };
  }
  if (niveau === 0) return { niveau: 0, categorie: "aucune", raison: "" };
  return verdictSecours(message, "réponse illisible");
}

// Appel du Veilleur. Ne DOIT JAMAIS faire échouer la requête.
export async function appelVeilleur(historique: Tour[], message: string, deadline?: number): Promise<Verdict> {
  try {
    const reponse = await chat({
      model: MODELE,
      max_completion_tokens: 500,
      reasoning_effort: "none",
      prompt_cache_key: "quieto-veilleur-1",
      prompt_cache_options: { ttl: "30m" },
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: PROMPT_VEILLEUR },
        ...derniersTours(historique, FENETRE_VEILLEUR_TOURS),
        { role: "user", content: message },
      ],
    }, { ...OPTIONS_PAR_DEFAUT, deadline });
    console.log("[Veilleur] usage:", JSON.stringify(reponse.usage));
    return lireVerdict(contenu(reponse), message);
  } catch (e) {
    console.error("[Veilleur] erreur :", e);
    return verdictSecours(message, "erreur API");
  }
}

// La MÉMOIRE : ne DOIT JAMAIS casser la requête (erreur → fiche inchangée).
export async function appelMemoire(memoireActuelle: string, echanges: string): Promise<string> {
  try {
    const texteUtilisateur =
      "FICHE ACTUELLE :\n" + (memoireActuelle || "(vide — première fois)") +
      "\n\nDERNIERS ÉCHANGES :\n" + echanges;
    const r = await chat({
      model: MODELE,
      max_completion_tokens: 1000,
      reasoning_effort: "none",
      messages: [
        { role: "system", content: PROMPT_MEMOIRE },
        { role: "user", content: texteUtilisateur },
      ],
    }, OPTIONS_APRES_REPONSE);
    console.log("[Mémoire] usage:", JSON.stringify(r.usage));
    const fiche = contenu(r).trim();
    return fiche || memoireActuelle;
  } catch (e) {
    console.error("[Mémoire] erreur (on garde la fiche actuelle) :", e);
    return memoireActuelle;
  }
}

// Le JUGE (qualité de la Voix) : erreur → null (pas de champ dans les stats).
export async function appelJuge(historique: Tour[], message: string, reponseLouane: string) {
  try {
    const fil = [...derniersTours(historique, 4).map((m) =>
      (m.role === "user" ? "La personne : " : "Louane : ") +
      sansMarqueursLancement(String(m.content)).trim()),
    "La personne : " + message,
    "Louane (RÉPONSE À JUGER) : " + reponseLouane].join("\n");
    const r = await chat({
      model: MODELE,
      max_completion_tokens: 200,
      reasoning_effort: "none",
      prompt_cache_key: "quieto-juge-1",
      prompt_cache_options: { ttl: "30m" },
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: PROMPT_JUGE },
        { role: "user", content: fil },
      ],
    }, OPTIONS_APRES_REPONSE);
    console.log("[Juge] usage:", JSON.stringify(r.usage));
    const verdict = extraireJson(contenu(r));
    if (!verdict) return null;
    const note = Math.min(5, Math.max(1, Number(verdict.note) || 0));
    const defauts = Array.isArray(verdict.defauts) ?
      verdict.defauts.map(String).filter((d) => DEFAUTS_JUGE.has(d)).slice(0, 6) : [];
    return { jugeNote: note, jugeDefauts: defauts };
  } catch (e) {
    console.error("[Juge] erreur (ignorée) :", e);
    return null;
  }
}
