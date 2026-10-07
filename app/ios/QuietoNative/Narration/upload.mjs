// Envoie les narrations générées (out/<langue>/*.m4a) dans le bucket privé
// Supabase « session-audio », au chemin <langue>/<id>.m4a lu par l'app.
//
// Usage :
//   SUPABASE_URL=https://xxx.supabase.co SUPABASE_SERVICE_ROLE_KEY=... node upload.mjs [--only id1,id2]
//
// La clé service_role ne doit jamais quitter cette machine ni entrer dans l'app.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const LANG = process.env.NARRATION_LANG || "fr";
const BUCKET = "session-audio";
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont requis.");
  process.exit(1);
}

const args = process.argv.slice(2);
const onlyArg = args.find((a) => a.startsWith("--only"));
const only = onlyArg ? (onlyArg.split("=")[1] ?? args[args.indexOf(onlyArg) + 1] ?? "").split(",").filter(Boolean) : null;

const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, "..", "Resources", "Narration", `narration-${LANG}.json`), "utf8"));
const entries = Object.entries(manifest.sessions).filter(([id, e]) => e.audioPath && (!only || only.includes(id)));

let failed = 0;
for (const [id, entry] of entries) {
  const file = path.join(ROOT, "out", entry.audioPath);
  if (!fs.existsSync(file)) { console.warn(`… ${id} : ${entry.audioPath} absent de out/, ignoré`); continue; }
  const response = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${entry.audioPath}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      "Content-Type": "audio/mp4",
      "x-upsert": "true",
      "Cache-Control": "max-age=31536000",
    },
    body: fs.readFileSync(file),
  });
  if (response.ok) console.log(`✓ ${id} → ${BUCKET}/${entry.audioPath}`);
  else { failed++; console.error(`✗ ${id} : ${response.status} ${await response.text()}`); }
}
console.log(`\n${entries.length - failed}/${entries.length} fichiers envoyés.`);
process.exit(failed ? 1 : 0);
