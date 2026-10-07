import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  bullesDepuisTexte, CATALOGUE, enPhrases, filetLexicalDetresse, NOMS_CATEGORIES, nettoyerLangue,
  nettoyerParcours, pourquoiDuMarqueur, seanceDuMarqueur, sonDuMarqueur, uneSeuleQuestion,
} from "./logic.ts";
import { CATALOGUE_TEXTE, CONSIGNE_CATALOGUE, consigneParcours, GUIDE_BESOINS_IDS, SONS_TEXTE } from "./prompts.ts";
import { lireVerdict, PROMPT_FIXE_VOIX, promptVariableVoix } from "./openai.ts";

// --- Filet lexical (secours quand le Veilleur est muet) -------------------

Deno.test("filet lexical : mots explicites de crise", () => {
  assertEquals(filetLexicalDetresse("j'ai envie de mourir"), "suicide");
  assertEquals(filetLexicalDetresse("Je veux me SUICIDER"), "suicide");
  assertEquals(filetLexicalDetresse("j’ai envie de disparaître"), "suicide"); // accent + apostrophe courbe
  assertEquals(filetLexicalDetresse("I want to die"), "suicide");
  assertEquals(filetLexicalDetresse("je vais sauter du pont"), "suicide");
  assertEquals(filetLexicalDetresse("j'ai envie de me faire du mal"), "automutilation");
  assertEquals(filetLexicalDetresse("je me scarifie"), "automutilation");
});

Deno.test("filet lexical : langage figuré banal", () => {
  assertEquals(filetLexicalDetresse("ce boulot me tue"), "");
  assertEquals(filetLexicalDetresse("mort de rire"), "");
  assertEquals(filetLexicalDetresse("longue journée au taf"), "");
});

Deno.test("Veilleur illisible → filet lexical ; verdicts lisibles respectés", () => {
  assertEquals(lireVerdict("pas du json", "je veux en finir").niveau, 2);
  assertEquals(lireVerdict("pas du json", "je veux en finir").secours, true);
  assertEquals(lireVerdict("", "bonne journée").niveau, 0);
  assertEquals(lireVerdict("", "bonne journée").secours, true);
  assertEquals(lireVerdict('{"niveau": 0}', "je veux en finir").niveau, 0); // le Veilleur prime
  assertEquals(lireVerdict('voilà {"niveau": "2", "categorie": "suicide"}', "x"),
    { niveau: 2, categorie: "suicide", raison: "" });
  assertEquals(lireVerdict('{"niveau": 7}', "salut").secours, true);
});

// --- Découpage en bulles et filets ------------------------------------------

Deno.test("bulles : [BULLE], une phrase = une bulle, pas de point final", () => {
  assertEquals(bullesDepuisTexte("Salut ! [BULLE] Alors, t'as prévu quoi aujourd'hui ?", "").bulles,
    ["Salut !", "Alors, t'as prévu quoi aujourd'hui ?"]);
  const r = bullesDepuisTexte("D'accord. Devant l'équipe, et pour rien. [BULLE] Elle t'a dit quoi ?", "");
  assertEquals(r.bulles, ["D'accord", "Devant l'équipe, et pour rien", "Elle t'a dit quoi ?"]);
  assertEquals(r.phrasesCoupees, 1);
});

Deno.test("bulles : paragraphes sans [BULLE] découpés", () => {
  assertEquals(bullesDepuisTexte("Je vois\n\nQu'est-ce qui l'a rendue longue ?", "").bulles,
    ["Je vois", "Qu'est-ce qui l'a rendue longue ?"]);
});

Deno.test("bulles : une seule question, prénom final, emoji, tiret long, écriture étrangère", () => {
  const r = bullesDepuisTexte("Tu dors mal ? [BULLE] Depuis quand ?", "");
  assertEquals(r.bulles, ["Tu dors mal ?"]);
  assertEquals(r.filtreQuestions.retirees, 1);
  assertEquals(bullesDepuisTexte("Qu'est-ce qui te stresse le plus, Paul ?", "Paul").bulles,
    ["Qu'est-ce qui te stresse le plus ?"]);
  assertEquals(bullesDepuisTexte("Je suis là 😊", "").bulles, ["Je suis là"]);
  assertEquals(bullesDepuisTexte("Deux phrases — courtes", "").bulles, ["Deux phrases, courtes"]);
  const etrangere = bullesDepuisTexte("Ce que tu vis участ", "");
  assertEquals(etrangere.bulles, ["Ce que tu vis"]);
  assertEquals(etrangere.ecritureEtrangere, 1);
});

Deno.test("bulles : « tu me testes » termine le message", () => {
  assertEquals(bullesDepuisTexte("Je crois que tu me testes [BULLE] Et toi, ta soirée ?", "").bulles,
    ["Je crois que tu me testes"]);
});

Deno.test("bulles : marqueurs retirés, jamais plus de cinq bulles", () => {
  assertEquals(bullesDepuisTexte("Tiens, installe-toi. [SEANCE:sleep_1]", "").bulles, ["Tiens, installe-toi"]);
  assertEquals(bullesDepuisTexte("Super, je te le prépare. [PARCOURS]", "").bulles, ["Super, je te le prépare"]);
  assertEquals(bullesDepuisTexte("[SEANCE:sleep_1]", "").bulles, []);
  assertEquals(bullesDepuisTexte("Un. Deux. Trois. Quatre. Cinq. Six. Sept.", "").bulles.length, 5);
});

Deno.test("phrases : une citation ouverte reste entière, question double coupée", () => {
  assertEquals(enPhrases("Dis-lui « Je suis fatiguée. Vraiment. » simplement"),
    ["Dis-lui « Je suis fatiguée. Vraiment. » simplement"]);
  assertEquals(uneSeuleQuestion(["Qu'est-ce que tu as déjà essayé, et tu peux y consacrer combien ?"]).bulles,
    ["Qu'est-ce que tu as déjà essayé ?"]);
  assertEquals(uneSeuleQuestion(["Tu dors mal, et ça dure depuis quand ?"]).bulles,
    ["Tu dors mal, et ça dure depuis quand ?"]);
});

// --- Marqueur de séance ---------------------------------------------------

Deno.test("[SEANCE:id] : id du catalogue natif seulement, regex réutilisable", () => {
  assertEquals(seanceDuMarqueur("Installe-toi [SEANCE:sleep_1]")?.titre, "Déposer la journée");
  assertEquals(seanceDuMarqueur("Installe-toi [SEANCE:sleep_1]")?.id, "sleep_1"); // lastIndex remis à zéro
  assertEquals(seanceDuMarqueur("[SEANCE:breath_sigh]")?.type, "respiration");
  assertEquals(seanceDuMarqueur("[SEANCE:express_99]"), null);
  assertEquals(seanceDuMarqueur("pas de marqueur"), null);
});

// --- Catalogue et prompt ----------------------------------------------------

Deno.test("catalogue natif : 94 séances, 9 catégories connues, ids uniques", () => {
  const seances = CATALOGUE.seances;
  assertEquals(seances.length, 94);
  assertEquals(seances.filter((s) => s.type === "meditation").length, 81);
  assertEquals(seances.filter((s) => s.type === "respiration").length, 13);
  assertEquals(new Set(seances.map((s) => s.id)).size, 94);
  assertEquals(Object.keys(NOMS_CATEGORIES).length, 9);
  for (const s of seances) {
    assert(NOMS_CATEGORIES[s.categorie], `catégorie inconnue : ${s.categorie}`);
    assert(s.titre && s.but && s.objectif && s.duree_min >= 1, s.id);
  }
});

Deno.test("prompt catalogue : toutes les séances, rangées sous les 9 catégories", () => {
  for (const nom of Object.values(NOMS_CATEGORIES)) assert(CATALOGUE_TEXTE.includes(`${nom} :\n`), nom);
  for (const s of CATALOGUE.seances) assertEquals(CATALOGUE_TEXTE.split(`[${s.id}]`).length, 2, s.id);
  assert(CATALOGUE_TEXTE.includes(
    "  • [sleep_1] « Déposer la journée » (12 min, méditation guidée, objectif « S’endormir ») : ",
  ));
  assert(CONSIGNE_CATALOGUE.includes(CATALOGUE_TEXTE));
});

Deno.test("prompt fixe : exemples d'id valides, navigation native, aucun programme proposé", () => {
  for (const [, id] of PROMPT_FIXE_VOIX.matchAll(/\[SEANCE:([a-zA-Z0-9_]+)\]/g)) {
    if (id !== "id") assert(seanceDuMarqueur(`[SEANCE:${id}]`), id);
  }
  assert(!PROMPT_FIXE_VOIX.includes("Explorer N'EXISTE PLUS"));
  assert(!PROMPT_FIXE_VOIX.includes("sur l'Accueil"));
  assert(PROMPT_FIXE_VOIX.includes("onglet Séances"));
  assert(!PROMPT_FIXE_VOIX.includes("TEMPS 3, QUAND ELLE DIT OUI"));
  assert(PROMPT_FIXE_VOIX.includes("jamais le marqueur [PARCOURS]"));
});

Deno.test("prompt variable : jamais « Android » pour l'app native", () => {
  const base = {
    historique: [], message: "salut", heure: "23:47", jour: "lundi", prenom: "Paul", memoire: "",
    profil: null, accueil: "", parcours: null, ecoutes: null, langue: "fr", quota: "",
  };
  assert(!promptVariableVoix({ ...base, santeDispo: false }).includes("Android"));
  assert(promptVariableVoix({ ...base, santeDispo: true }).includes("elle est sur iPhone"));
  assert(promptVariableVoix({ ...base, santeDispo: true }).includes("Il est 23:47 chez la personne"));
  assert(!promptVariableVoix({ ...base, santeDispo: true }).includes("[PARCOURS]"));
});

// --- Sons, phrase de la carte, langue, programme ----------------------------

Deno.test("[SON:id] : sons inclus seulement, retiré des bulles avec [POURQUOI:…]", () => {
  assertEquals(sonDuMarqueur("Je te mets la pluie [SON:rain]")?.titre, "Pluie sur la fenêtre");
  assertEquals(sonDuMarqueur("[SON:brown-noise]")?.id, "brown-noise");
  assertEquals(sonDuMarqueur("[SON:cafe]"), null); // pas encore inclus dans l'app
  const texte = "Installe-toi, je te la lance [SEANCE:sleep_1] [SON:rain] [POURQUOI:Pour que le sommeil vienne sans forcer.]";
  assertEquals(pourquoiDuMarqueur(texte), "Pour que le sommeil vienne sans forcer");
  const { bulles } = bullesDepuisTexte(texte, "Paul");
  assertEquals(bulles, ["Installe-toi, je te la lance"]);
  assertEquals(pourquoiDuMarqueur("rien"), "");
  assert(pourquoiDuMarqueur(`[POURQUOI:${"a".repeat(150)}]`).length <= 90);
});

Deno.test("catalogue des sons et guide des besoins : ids valides", () => {
  assertEquals(CATALOGUE.sons.length, 10);
  for (const s of CATALOGUE.sons) assertEquals(SONS_TEXTE.split(`[${s.id}]`).length, 2, s.id);
  for (const id of GUIDE_BESOINS_IDS) assert(seanceDuMarqueur(`[SEANCE:${id}]`), id);
  for (const [, id] of PROMPT_FIXE_VOIX.matchAll(/\[SON:([a-z-]+)\]/g)) {
    if (id !== "id") assert(sonDuMarqueur(`[SON:${id}]`), id);
  }
});

Deno.test("langue : code de l'app, japonais conservé, consigne seulement hors français", () => {
  assertEquals(nettoyerLangue("en-GB"), "en");
  assertEquals(nettoyerLangue("xx"), "fr");
  assertEquals(nettoyerLangue(undefined), "fr");
  assertEquals(bullesDepuisTexte("今夜は少し休もう", "", "ja").bulles, ["今夜は少し休もう"]);
  assertEquals(bullesDepuisTexte("Repose-toi 今夜", "", "fr").bulles, ["Repose-toi"]);
  const base = {
    historique: [], message: "hi", heure: "23:47", jour: "monday", prenom: "", memoire: "",
    profil: null, accueil: "", parcours: null, ecoutes: null, santeDispo: true, quota: "",
  };
  assert(promptVariableVoix({ ...base, langue: "en" }).includes("anglais"));
  assert(!promptVariableVoix({ ...base, langue: "fr" }).includes("LANGUE :"));
});

Deno.test("programme : prochaine séance validée et citée", () => {
  const parcours = nettoyerParcours({ actif: true, titre: "Dormir", jour: 2, prochaine: "sleep_1" });
  assertEquals(parcours?.prochaine, "sleep_1");
  assert(consigneParcours(parcours).includes("[sleep_1]"));
  assertEquals(nettoyerParcours({ actif: true, prochaine: "inconnue_9" })?.prochaine, "");
});
