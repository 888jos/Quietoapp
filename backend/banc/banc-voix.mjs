// Banc de test de la VOIX de Louane : rejoue des conversations réalistes
// contre la fonction `louane` (émulateur local par défaut) et écrit les
// transcriptions dans banc/resultats/. Sert à comparer deux versions du
// prompt (ou deux réglages du modèle) sur EXACTEMENT les mêmes scénarios.
//
// Prérequis : l'émulateur tourne, SANS émulateur Firestore (le garde-fou
// VIGIE_ECRITURE d'index.js empêche alors toute écriture dans la Vigie),
// AVEC l'émulateur Auth (depuis le 12/09, EXIGER_AUTH = true : le banc se
// crée une identité anonyme sur l'émulateur, jamais en prod) :
//   firebase emulators:start --only functions,auth --project quieto-06
//
// Usage :
//   node banc/banc-voix.mjs <etiquette> [id-scenario ...]
//   ex. node banc/banc-voix.mjs avant            → tous les scénarios
//       node banc/banc-voix.mjs apres confie nuit → deux scénarios seulement
//
// Les répliques de la personne sont écrites à l'avance (le même fil quoi que
// réponde Louane) : on juge le TON et le naturel, pas la logique du dialogue.
// Chaque bulle de Louane repart dans l'historique comme un message
// « assistant » distinct, exactement comme le fait l'app.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const URL_LOUANE = process.env.LOUANE_URL ||
  "http://127.0.0.1:5001/quieto-06/us-central1/louane";
const URL_AUTH = process.env.AUTH_EMULATOR_URL || "http://127.0.0.1:9099";
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Jeton d'une identité anonyme créée sur l'émulateur Auth (une par lancement).
let jeton = null;
async function jetonBanc() {
  if (jeton) return jeton;
  const r = await fetch(
    `${URL_AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=banc`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ returnSecureToken: true }),
    }).catch(() => null);
  const json = r && await r.json().catch(() => ({}));
  if (!json || !json.idToken) {
    throw new Error("Émulateur Auth injoignable : lancer --only functions,auth");
  }
  jeton = json.idToken;
  return jeton;
}

const PROFIL_STRESS = {
  goals: "Apaiser mon stress|Mieux dormir",
  q1: "Apaiser mon stress",
  q2: "Jamais essayé",
  q4: "Le soir",
  q_minutes: "10 minutes",
};

export const SCENARIOS = [
  {
    id: "soiree",
    titre: "Petite conversation du soir, rien de lourd",
    heure: "21:30", jour: "mercredi 2 septembre", prenom: "Paul",
    accueil: "Hey Paul\nAlors, elle a donné quoi cette journée ?",
    tours: [
      "bof, longue journée au taf",
      "un client qui m'a pris la tête toute la journée, il change d'avis toutes les deux heures",
      "ouais bon ça va passer. là je vais me faire des pâtes et regarder une série",
      "the bear, tu connais ?",
    ],
  },
  {
    id: "confie",
    titre: "Elle se confie : humiliée par sa manager",
    heure: "19:10", jour: "mercredi 2 septembre", prenom: "Camille",
    accueil: "Hey Camille\nTa soirée commence comment ?",
    tours: [
      "ça va pas fort là",
      "ma manager m'a encore recadrée devant toute l'équipe ce matin. pour une erreur que j'avais même pas faite",
      "je rumine ça depuis ce matin, j'arrive pas à penser à autre chose. et j'ai rien dit sur le moment, comme d'habitude",
      "je sais pas. j'ai pas envie d'une séance là, je veux juste en parler",
    ],
  },
  {
    id: "nuit",
    titre: "Insomnie, 1h30 du matin, présentation demain",
    heure: "01:30", jour: "jeudi 3 septembre", prenom: "Léa",
    accueil: "Hey Léa\nT'arrives pas à dormir ?",
    tours: [
      "non je tourne dans mon lit depuis 1h",
      "je pense à ma présentation de demain, j'ai peur de bafouiller devant tout le monde",
      "ok vas-y, lance-moi un truc",
    ],
  },
  {
    id: "teste",
    titre: "Il la teste : robot, à quoi tu sers, blague",
    heure: "15:00", jour: "mercredi 2 septembre", prenom: "Karim",
    accueil: "Hey Karim\nQuoi de neuf ?",
    tours: [
      "t'es un robot avoue",
      "franchement tu sers à quoi",
      "ok fais moi une blague alors",
    ],
  },
  {
    id: "horssujet",
    titre: "Hors terrain : un mail au proprio, puis le vrai sujet",
    heure: "12:40", jour: "mercredi 2 septembre", prenom: "Nadia",
    accueil: "Hey Nadia\nAlors, cette matinée ?",
    tours: [
      "tu peux m'écrire un mail pour mon proprio ? il veut augmenter le loyer",
      "allez stp juste un petit mail de trois lignes",
      "bon ok. en vrai c'est que j'ai des soucis d'argent en ce moment et ça me stresse à mort",
    ],
  },
  {
    id: "programme",
    titre: "Elle demande un programme (mini-diagnostic)",
    heure: "20:15", jour: "mercredi 2 septembre", prenom: "Julie",
    profil: PROFIL_STRESS,
    accueil: "Hey Julie\nAlors, comment s'est passé aujourd'hui ?",
    tours: [
      "ça va. dis, tu peux me faire un programme ?",
      "c'est le stress au boulot surtout, et du coup je dors mal",
      "le soir surtout. j'arrive pas à décrocher, je suis tendue partout et je repasse ma journée en boucle",
      "10 minutes par jour max. j'ai essayé des applis de méditation mais j'ai lâché au bout de trois jours",
    ],
  },
  {
    id: "memoire",
    titre: "Elle revient : Louane se souvient (mère hospitalisée, partiels)",
    heure: "18:20", jour: "mercredi 2 septembre", prenom: "Sarah",
    memoire: "- Prénom : Sarah, 22 ans, étudiante en droit (L3), partiels de rattrapage début septembre.\n" +
      "- Sa mère est hospitalisée à Lyon (cancer), Sarah y va le week-end.\n" +
      "- Copain : Tom, très présent.\n" +
      "- La séance « Respiration 4-7-8 » l'a aidée à dormir, elle l'aime bien.\n" +
      "- Ce qui pèse : la peur pour sa mère, la culpabilité de réviser pendant ce temps.",
    accueil: "Hey Sarah\nAlors, elle a donné quoi cette journée ?",
    tours: [
      "j'ai eu ma mère au téléphone",
      "elle sort demain, les médecins sont plutôt rassurants",
      "ouais je suis soulagée. par contre je crois que j'ai raté mon partiel de ce matin",
    ],
  },
  {
    id: "premiere",
    titre: "Toute première conversation après l'onboarding (objectif : dormir)",
    heure: "22:40", jour: "mercredi 2 septembre", prenom: "Marc",
    profil: { goals: "Mieux dormir", q1: "Mieux dormir", q2: "Un peu", q4: "Le soir", q_minutes: "5 minutes" },
    accueil: "Hey Marc\nMoi c'est Louane\nDu coup si j'ai bien compris, t'es surtout là pour mieux dormir, c'est bien ça ?",
    tours: [
      "oui c'est ça",
      "je me réveille vers 4h et je me rendors pas, ça fait deux mois",
      "depuis que j'ai changé de boulot en fait. c'est plus de responsabilités",
    ],
  },
  {
    id: "moral",
    titre: "Moral au fond, sans danger (niveau 1)",
    heure: "23:05", jour: "mercredi 2 septembre", prenom: "Thomas",
    accueil: "Hey Thomas\nPas encore au lit, toi :)",
    tours: [
      "je suis nul, j'arrive à rien, tout le monde s'en sort mieux que moi",
      "j'ai 34 ans et je vis encore chez mes parents. mes potes ont des gosses, des apparts",
      "je sais même pas ce que je veux faire de ma vie",
    ],
  },
  {
    id: "rentree",
    titre: "La rentrée stresse (cas de Paul) : creuser, puis amener le programme",
    heure: "17:05", jour: "mercredi 2 septembre", prenom: "Paul",
    profil: PROFIL_STRESS,
    accueil: "Hey Paul\nTu tiens le coup cet aprèm ?",
    tours: [
      "non en vrai c'est l'école, la rentrée me stresse pas mal",
      "le rythme qui va reprendre, et les gens que j'ai pas envie de voir",
      "des gens de ma classe. l'an dernier ça s'est mal passé avec deux d'entre eux",
      "ils se foutaient de moi devant les autres, pendant des mois. à la fin je parlais plus à personne",
      "non j'en ai parlé à personne, même pas à mes parents",
      "le soir surtout. je repense à ça, j'ai le ventre noué et je dors mal",
      "j'ai essayé de pas y penser mais ça marche pas",
      "oui c'est ça",
      "ouais je veux bien",
    ],
  },
  {
    id: "retour",
    titre: "Elle revient, Louane sait déjà (moqueries au travail) : confirmer, ne pas affirmer",
    heure: "21:20", jour: "mercredi 2 septembre", prenom: "Paul",
    memoire: "- Paul, en poste depuis 3 ans, reprend le travail après deux semaines de congés.\n" +
      "- Ses collègues se moquent de son physique, en face, devant les autres ; il encaisse sans rien dire.\n" +
      "- Le soir, il rumine et dort mal.",
    accueil: "Hey Paul\nAlors, elle a donné quoi cette journée ?",
    tours: [
      "je stresse pour demain",
      "ouais c'est ça",
      "j'ai personne à qui en parler là-bas",
      "aide moi à trouver",
    ],
  },
  {
    id: "salut",
    titre: "Il dit juste salut, quatre fois (cas de Paul) : chaleur, sourire, pas de pression",
    heure: "19:15", jour: "mercredi 2 septembre", prenom: "Paul",
    accueil: "Hey Paul\nT'as réussi à souffler un peu aujourd'hui ?",
    tours: [
      "Salut",
      "Salut",
      "Salut",
      "Salut",
      "ça va et toi ?",
    ],
  },
  {
    id: "nonsens",
    titre: "Il tape n'importe quoi et répète une bêtise : elle sourit, ne force pas",
    heure: "19:20", jour: "mercredi 2 septembre", prenom: "Paul",
    accueil: "Hey Paul\nTu fais quoi de ta soirée ?",
    tours: [
      "azerazer",
      "sdfghjk sdfg",
      "les poules ont des dents",
      "les poules ont des dents",
      "ok ok je testais, ça va et toi",
    ],
  },
  {
    id: "sante",
    titre: "Programme à partir de son test Santé (questionnaire anxiété seul, réponses lues)",
    heure: "19:40", jour: "vendredi 11 septembre", prenom: "Manon",
    accueil: "Hey Manon\nTa soirée commence comment ?",
    profil: PROFIL_STRESS,
    // Exactement ce que l'app envoie (health_service.dart, formaterResumeSante).
    sante: "QUESTIONNAIRE SANTÉ : elle a fait le questionnaire ANXIÉTÉ seul " +
      "(pas celui sur le moral) il y a 2 jours. Anxiété (GAD-7) : niveau " +
      "modéré, score 11/21. Réponses sur les 2 dernières semaines (0 jamais · " +
      "1 plusieurs jours · 2 plus de la moitié des jours · 3 presque tous les " +
      "jours) : nervosité, anxiété ou tension : 2 ; inquiétudes impossibles à " +
      "arrêter : 2 ; s'inquiéter de tout et de rien : 1 ; mal à se détendre : " +
      "3 ; agitation, mal à rester en place : 0 ; irritabilité, facilement " +
      "contrarié·e : 1 ; peur qu'il arrive quelque chose de grave : 2. " +
      "Sommeil de la dernière nuit (Apple Santé) : ~5.5h, nuit plutôt courte.",
    tours: [
      "salut, tu peux me faire un programme à partir de mon test dans apple santé ?",
      "oui c'est ça, surtout le soir quand je me couche, ça tourne",
      "j'ai 10 minutes le soir, pas plus",
      "j'ai essayé des vidéos youtube de respiration mais je décroche vite",
      "oui vas-y",
    ],
  },
  {
    id: "cash",
    titre: "Registre cash : la coloc qui abuse",
    heure: "17:45", jour: "mercredi 2 septembre", prenom: "Inès",
    accueil: "Hey Inès\nTu tiens le coup cet aprèm ?",
    tours: [
      "putain j'en ai marre de ma coloc",
      "elle fait jamais la vaisselle et elle ramène des gens à 2h du mat en semaine. je bosse moi",
      "je lui ai rien dit encore. je sais pas comment lui dire sans que ça parte en couille",
    ],
  },
];

async function appelLouane(data) {
  const r = await fetch(URL_LOUANE, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer " + await jetonBanc(),
    },
    body: JSON.stringify({ data }),
  });
  const json = await r.json().catch(() => ({}));
  if (!r.ok || json.error) {
    throw new Error(`HTTP ${r.status} : ${JSON.stringify(json).slice(0, 300)}`);
  }
  return json.result;
}

async function jouerScenario(sc) {
  const historique = [];
  const lignes = [`## ${sc.id} — ${sc.titre}`, "",
    `*${sc.heure}, ${sc.jour}${sc.memoire ? ", avec fiche mémoire" : ""}${sc.profil ? ", avec profil" : ""}*`, "",
    ...sc.accueil.split("\n").map((b) => `> 🌸 ${b}`), ""];
  let memoire = sc.memoire || "";
  let compteur = 0;
  const brut = [];
  for (const tour of sc.tours) {
    lignes.push(`**${sc.prenom} :** ${tour}`, "");
    const debut = Date.now();
    let res;
    try {
      res = await appelLouane({
        message: tour,
        historique,
        heure: sc.heure,
        jour: sc.jour,
        accueil: sc.accueil,
        prenom: sc.prenom,
        memoire,
        profil: sc.profil || null,
        parcours: null,
        ecoutes: null,
        sante: sc.sante || "",
        santeDispo: true,
        abonne: true,
        compteurTotal: compteur,
        compteurJour: compteur,
        vigie: "banc_voix_local",
        session: "banc",
      });
    } catch (e) {
      lignes.push(`💥 ${e.message}`, "");
      brut.push({ tour, erreur: e.message });
      break;
    }
    const ms = Date.now() - debut;
    const bulles = res.bulles && res.bulles.length ? res.bulles : [res.reponse];
    for (const b of bulles) lignes.push(`> 🌸 ${b}`);
    const extras = [];
    if (res.seance) extras.push(`▶︎ séance lancée : « ${res.seance.titre} »`);
    if (res.parcoursPropose) extras.push("📅 bouton programme");
    if (res.analyseSante) extras.push(`🩺 carte « Louane analyse » après ${res.analyseApres || 0} bulle(s)`);
    if (res.securite) extras.push("🛡 message de sécurité");
    if (res.niveau) extras.push(`veilleur niveau ${res.niveau}`);
    lignes.push(`<sub>${bulles.length} bulle(s), ${bulles.join(" ").length} car, ${(ms / 1000).toFixed(1)} s${extras.length ? " · " + extras.join(" · ") : ""}</sub>`, "");
    brut.push({ tour, bulles, ms, seance: res.seance, parcoursPropose: res.parcoursPropose, niveau: res.niveau });
    historique.push({ role: "user", content: tour });
    // Comme l'app : chaque bulle devient un message assistant ; un lancement
    // de séance garde son marqueur en fin de dernière bulle.
    // La carte d'analyse Santé : le marqueur [ANALYSE] revient devant la
    // première bulle, pour que Louane sache qu'elle l'a déjà fait.
    bulles.forEach((b, i) => {
      const debut = (res.analyseSante && i === Math.min(res.analyseApres || 0, bulles.length - 1)) ? "[ANALYSE] " : "";
      const fin = (i === bulles.length - 1 && res.seance) ? ` [SEANCE:${res.seance.id}]` : "";
      historique.push({ role: "assistant", content: debut + b + fin });
    });
    if (res.memoire) memoire = res.memoire;
    compteur += 1;
  }
  if (memoire && memoire !== (sc.memoire || "")) {
    lignes.push("<details><summary>fiche mémoire en fin de scénario</summary>", "", "```", memoire, "```", "</details>", "");
  }
  return { id: sc.id, md: lignes.join("\n"), brut, memoire };
}

// Importé par mesures.mjs pour ses scénarios : on ne lance le banc que
// quand ce fichier est exécuté directement.
const executeDirectement = process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (!executeDirectement) {
  // rien : export des SCENARIOS seulement
} else {
await (async () => {
const etiquette = process.argv[2];
if (!etiquette) {
  console.error("Usage : node banc/banc-voix.mjs <etiquette> [id-scenario ...]");
  process.exit(1);
}
const voulus = process.argv.slice(3);
const aJouer = voulus.length ? SCENARIOS.filter((s) => voulus.includes(s.id)) : SCENARIOS;
if (!aJouer.length) {
  console.error("Aucun scénario ne correspond. Ids :", SCENARIOS.map((s) => s.id).join(", "));
  process.exit(1);
}

console.log(`🌸 Banc Voix « ${etiquette} » : ${aJouer.length} scénario(s) vers ${URL_LOUANE}`);
const debutTotal = Date.now();
// 3 scénarios en parallèle (l'émulateur accepte 4 appels simultanés).
const resultats = [];
let curseur = 0;
async function ouvrier() {
  while (curseur < aJouer.length) {
    const sc = aJouer[curseur++];
    process.stdout.write(`  → ${sc.id}…\n`);
    resultats.push(await jouerScenario(sc));
    process.stdout.write(`  ✓ ${sc.id}\n`);
  }
}
await Promise.all([ouvrier(), ouvrier(), ouvrier()]);
resultats.sort((a, b) => aJouer.findIndex((s) => s.id === a.id) - aJouer.findIndex((s) => s.id === b.id));

const horodatage = new Date().toISOString().slice(0, 16).replace("T", "_").replace(":", "h");
const dossier = path.join(__dirname, "resultats");
fs.mkdirSync(dossier, { recursive: true });
const base = path.join(dossier, `${horodatage}-${etiquette}`);
const tousTours = resultats.flatMap((r) => r.brut.filter((t) => t.bulles));
const nbBulles = tousTours.reduce((n, t) => n + t.bulles.length, 0);
const nbCar = tousTours.reduce((n, t) => n + t.bulles.join(" ").length, 0);
const entete = [`# Banc Voix — ${etiquette}`, "",
  `${resultats.length} scénarios, ${tousTours.length} réponses · ${(nbBulles / tousTours.length).toFixed(1)} bulle(s)/réponse · ${Math.round(nbCar / tousTours.length)} car/réponse · ${((Date.now() - debutTotal) / 1000).toFixed(0)} s au total`, "", "---", ""];
fs.writeFileSync(base + ".md", entete.concat(resultats.map((r) => r.md)).join("\n"));
fs.writeFileSync(base + ".json", JSON.stringify(resultats.map(({ id, brut, memoire }) => ({ id, brut, memoire })), null, 2));
console.log(`\n✅ ${base}.md`);
})();
}
