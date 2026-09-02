// Mesures objectives sur les résultats du banc (banc/resultats/*.json) :
// longueur, bulles, part de réponses qui finissent par une question,
// questions à choix (« … ou … ? »), tics (« Aïe », « Ah mince », « … »),
// prénom répété, bulles qui commencent par « Ah ». Une ligne par fichier.
//
// Usage : node banc/mesures.mjs [motif]   (motif = sous-chaîne du nom de fichier)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { SCENARIOS } from "./banc-voix.mjs";

const dossier = path.join(path.dirname(fileURLToPath(import.meta.url)), "resultats");
const motif = process.argv[2] || "";
const fichiers = fs.readdirSync(dossier).filter((f) => f.endsWith(".json") && f.includes(motif)).sort();
const prenoms = new Set(SCENARIOS.map((s) => s.prenom));

const pct = (n, d) => (d ? Math.round((100 * n) / d) : 0) + " %";
const lignes = [["fichier", "réponses", "car/rép", "bulles/rép", "finit par ?", "question à choix", "2 questions", "commence par Ah/Aïe", "Aïe", "Ah mince", "…", "prénom", "prénom en fin de phrase", "> 25 mots"]];
for (const f of fichiers) {
  const data = JSON.parse(fs.readFileSync(path.join(dossier, f), "utf8"));
  const reponses = data.flatMap((sc) => sc.brut.filter((t) => t.bulles).map((t) => ({ ...t, prenom: SCENARIOS.find((s) => s.id === sc.id)?.prenom })));
  const n = reponses.length;
  let car = 0, bulles = 0, finitQ = 0, choix = 0, deuxQ = 0, debutAh = 0, aie = 0, ahMince = 0, susp = 0, prenom = 0, prenomFin = 0, longs = 0;
  for (const r of reponses) {
    const texte = r.bulles.join(" ");
    car += texte.length;
    bulles += r.bulles.length;
    if (/\?\s*[^\w]*$/.test(r.bulles[r.bulles.length - 1].trim())) finitQ++;
    if (r.bulles.some((b) => /\bou\b[^.?!]*\?/.test(b) && !/ou pas \?|ou quoi \?|ou bien \?$/.test(b))) choix++;
    if ((texte.match(/\?/g) || []).length >= 2) deuxQ++;
    debutAh += r.bulles.filter((b) => /^(Ah|Aïe|ah|aïe)\b/.test(b.trim())).length;
    aie += (texte.match(/\bAïe\b/gi) || []).length;
    ahMince += (texte.match(/ah mince/gi) || []).length;
    susp += (texte.match(/…|\.\.\./g) || []).length;
    if (r.prenom && texte.includes(r.prenom)) prenom++;
    if (r.prenom && new RegExp(`(?:,\\s*|\\s+)${r.prenom}\\s*(?:[.?!…]|$)`, "u").test(texte)) prenomFin++;
    if (texte.split(/\s+/).length > 25) longs++;
  }
  lignes.push([f.replace(".json", ""), n, Math.round(car / n), (bulles / n).toFixed(1), pct(finitQ, n), choix, deuxQ, pct(debutAh, bulles), aie, ahMince, susp, prenom, prenomFin, pct(longs, n)]);
}
const largeurs = lignes[0].map((_, i) => Math.max(...lignes.map((l) => String(l[i]).length)));
for (const l of lignes) console.log(l.map((c, i) => String(c).padEnd(largeurs[i])).join(" | "));
