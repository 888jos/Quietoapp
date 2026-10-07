// Génère les narrations des séances avec ElevenLabs, en une seule passe.
//
// Source de vérité : un fichier Markdown par séance dans scripts/<langue>/.
// Sortie :
//   out/<langue>/<id>.m4a                       fichiers à envoyer sur Supabase (upload.mjs)
//   ../Resources/Narration/narration-<langue>.json  texte + chemin audio + durée, embarqué dans l'app
//
// Chaque paragraphe est demandé séparément à ElevenLabs puis assemblé avec de
// vrais silences : les pauses longues d'une méditation ne dépendent donc pas
// de la voix. Les réponses sont mises en cache (.cache/) : relancer le script
// ne refacture que les paragraphes modifiés.
//
// Usage :
//   node generate.mjs --dry-run              compte les caractères (coût) sans appeler l'API
//   node generate.mjs --text-only            met à jour le JSON de l'app sans audio (voix Apple en attendant)
//   node generate.mjs                        génère tout
//   node generate.mjs --only express_1,express_4
//   node generate.mjs --preview              voix gratuite du Mac à la place d'ElevenLabs : vérifie
//                                            le rythme et les durées avant de payer (rien n'est écrit dans le JSON)
//
// Variables : ELEVENLABS_API_KEY, ELEVENLABS_VOICE_ID (obligatoires hors --dry-run / --text-only),
// ELEVENLABS_MODEL (défaut eleven_multilingual_v2), NARRATION_LANG (défaut fr).

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const LANG = process.env.NARRATION_LANG || "fr";
const MODEL = process.env.ELEVENLABS_MODEL || "eleven_multilingual_v2";
const VOICE = process.env.ELEVENLABS_VOICE_ID || "";
const API_KEY = process.env.ELEVENLABS_API_KEY || "";
// MP3 est disponible sur toutes les offres ElevenLabs (le PCM exige l'offre Pro).
const OUTPUT_FORMAT = "mp3_44100_128";
const SAMPLE_RATE = 44100;

// Réglages de voix pour la méditation : posée, régulière, un peu lente.
const VOICE_SETTINGS = { stability: 0.6, similarity_boost: 0.75, style: 0, use_speaker_boost: true, speed: 0.9 };

const DEFAULT_PAUSE = 2.5;   // secondes entre deux paragraphes sans [pause]
const MAX_PAUSE = 45;        // aucune pause plus longue, même après ajustement
const MIN_PAUSE = 2;         // ni plus courte quand la voix est plus lente que prévu
const LEAD_IN = 1.5;         // silence avant la première phrase
const DAY_TAIL = 3;          // silence final d'une séance de jour
const SLEEP_TAIL = 20;       // la voix s'éteint, la séance continue un peu en silence
const TARGET_RMS_DB = -20;   // niveau sonore homogène entre les séances
const PEAK_LIMIT_DB = -1;

const SCRIPTS_DIR = path.join(ROOT, "scripts", LANG);
const OUT_DIR = path.join(ROOT, process.argv.includes("--preview") ? "out-preview" : "out", LANG);
const CACHE_DIR = path.join(ROOT, ".cache", LANG);
const MANIFEST = path.join(ROOT, "..", "Resources", "Narration", `narration-${LANG}.json`);

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const textOnly = args.includes("--text-only");
const preview = args.includes("--preview");
const onlyArg = args.find((a) => a.startsWith("--only"));
const only = onlyArg ? (onlyArg.split("=")[1] ?? args[args.indexOf(onlyArg) + 1] ?? "").split(",").filter(Boolean) : null;

// ---------- Lecture des scripts ----------

function parseScript(file) {
  const raw = fs.readFileSync(file, "utf8");
  const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) throw new Error(`${path.basename(file)} : en-tête --- manquant`);
  const meta = {};
  for (const line of match[1].split("\n")) {
    const m = line.match(/^(\w+):\s*(.*?)\s*(#.*)?$/);
    if (m) meta[m[1]] = m[2];
  }
  for (const key of ["id", "title", "duration", "ending"]) {
    if (!meta[key]) throw new Error(`${path.basename(file)} : champ « ${key} » manquant`);
  }
  if (!["day", "sleep"].includes(meta.ending)) throw new Error(`${meta.id} : ending doit valoir day ou sleep`);

  // Découpe : paragraphes séparés par une ligne vide, pauses explicites [pause 8s].
  const items = [];
  const blocks = match[2].split(/\n\s*\n/).map((b) => b.trim()).filter(Boolean);
  for (const block of blocks) {
    const pause = block.match(/^\[pause\s+(\d+(?:[.,]\d+)?)\s*s\]$/i);
    if (pause) {
      const seconds = Number(pause[1].replace(",", "."));
      const last = items.at(-1);
      if (last?.type === "pause") { last.seconds += seconds; last.explicit = true; }
      else items.push({ type: "pause", seconds, explicit: true });
      continue;
    }
    if (/\[pause/i.test(block)) throw new Error(`${meta.id} : [pause] doit être seul sur sa ligne : « ${block.slice(0, 40)}… »`);
    if (items.at(-1)?.type === "speech") items.push({ type: "pause", seconds: DEFAULT_PAUSE, explicit: false });
    items.push({ type: "speech", text: block.replace(/\s*\n\s*/g, " ") });
  }
  if (!items.some((i) => i.type === "speech")) throw new Error(`${meta.id} : aucun texte`);
  return { id: meta.id, title: meta.title, targetSeconds: Number(meta.duration), ending: meta.ending, items };
}

function transcriptOf(script) {
  return script.items.filter((i) => i.type === "speech").map((i) => i.text).join("\n\n");
}

// ---------- ElevenLabs ----------

async function synthesize(text, previousText, nextText) {
  const body = { text, model_id: MODEL, voice_settings: VOICE_SETTINGS };
  if (previousText) body.previous_text = previousText;
  if (nextText) body.next_text = nextText;
  const key = crypto.createHash("sha256").update(JSON.stringify({ VOICE, OUTPUT_FORMAT, body, preview })).digest("hex").slice(0, 24);
  const cached = path.join(CACHE_DIR, `${key}.${preview ? "aiff" : "mp3"}`);
  if (fs.existsSync(cached)) return { file: cached, fromCache: true };
  if (preview) {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    execFileSync("say", ["-v", "Thomas", "-r", "150", "-o", cached, text]);
    return { file: cached, fromCache: true };
  }

  const url = `https://api.elevenlabs.io/v1/text-to-speech/${VOICE}?output_format=${OUTPUT_FORMAT}`;
  for (let attempt = 1; ; attempt++) {
    const response = await fetch(url, {
      method: "POST",
      headers: { "xi-api-key": API_KEY, "Content-Type": "application/json", Accept: "audio/mpeg" },
      body: JSON.stringify(body),
    });
    if (response.ok) {
      fs.mkdirSync(CACHE_DIR, { recursive: true });
      fs.writeFileSync(cached, Buffer.from(await response.arrayBuffer()));
      return { file: cached, fromCache: false };
    }
    const detail = await response.text().catch(() => "");
    if ((response.status === 429 || response.status >= 500) && attempt < 5) {
      const wait = 2 ** attempt * 1000;
      console.warn(`  ElevenLabs ${response.status}, nouvel essai dans ${wait / 1000} s`);
      await new Promise((r) => setTimeout(r, wait));
      continue;
    }
    throw new Error(`ElevenLabs ${response.status} : ${detail.slice(0, 300)}`);
  }
}

// ---------- Audio (PCM 16 bits mono, via afconvert) ----------

function decodeToSamples(sourceFile) {
  const wav = path.join(CACHE_DIR, `${path.parse(sourceFile).name}.wav`);
  if (!fs.existsSync(wav)) {
    execFileSync("afconvert", ["-f", "WAVE", "-d", `LEI16@${SAMPLE_RATE}`, "-c", "1", sourceFile, wav]);
  }
  const data = fs.readFileSync(wav);
  // Cherche le bloc "data" (afconvert peut ajouter d'autres blocs avant).
  let offset = 12;
  while (offset < data.length - 8) {
    const id = data.toString("ascii", offset, offset + 4);
    const size = data.readUInt32LE(offset + 4);
    if (id === "data") {
      const samples = new Float32Array(size / 2);
      for (let i = 0; i < samples.length; i++) samples[i] = data.readInt16LE(offset + 8 + i * 2) / 32768;
      return trimSilence(samples);
    }
    offset += 8 + size + (size % 2);
  }
  throw new Error(`WAV illisible : ${wav}`);
}

// Retire le silence que la voix ajoute en début/fin : les pauses sont gérées ici.
function trimSilence(samples, threshold = 0.004) {
  let start = 0, end = samples.length;
  while (start < end && Math.abs(samples[start]) < threshold) start++;
  while (end > start && Math.abs(samples[end - 1]) < threshold) end--;
  const pad = Math.round(0.05 * SAMPLE_RATE);
  return fade(samples.slice(Math.max(0, start - pad), Math.min(samples.length, end + pad)), 0.02);
}

function fade(samples, seconds) {
  const n = Math.min(Math.round(seconds * SAMPLE_RATE), Math.floor(samples.length / 2));
  for (let i = 0; i < n; i++) {
    const g = i / n;
    samples[i] *= g;
    samples[samples.length - 1 - i] *= g;
  }
  return samples;
}

function normalize(samples) {
  let sum = 0, peak = 0, voiced = 0;
  for (const s of samples) {
    const a = Math.abs(s);
    if (a > 0.004) { sum += s * s; voiced++; }
    if (a > peak) peak = a;
  }
  if (!voiced || !peak) return samples;
  const rms = Math.sqrt(sum / voiced);
  const gain = Math.min(10 ** (TARGET_RMS_DB / 20) / rms, 10 ** (PEAK_LIMIT_DB / 20) / peak);
  for (let i = 0; i < samples.length; i++) samples[i] *= gain;
  return samples;
}

function writeWav(file, samples) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) {
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i])) * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write("RIFF", 0); header.writeUInt32LE(36 + data.length, 4); header.write("WAVE", 8);
  header.write("fmt ", 12); header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(1, 22);
  header.writeUInt32LE(SAMPLE_RATE, 24); header.writeUInt32LE(SAMPLE_RATE * 2, 28); header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34); header.write("data", 36); header.writeUInt32LE(data.length, 40);
  fs.writeFileSync(file, Buffer.concat([header, data]));
}

// ---------- Assemblage d'une séance ----------

async function render(script) {
  const speech = script.items.filter((i) => i.type === "speech");
  const clips = new Map();
  let billed = 0;
  for (const [index, item] of speech.entries()) {
    const { file, fromCache } = await synthesize(item.text, speech[index - 1]?.text, speech[index + 1]?.text);
    if (!fromCache) billed += item.text.length;
    clips.set(item, decodeToSamples(file));
  }

  // Ajuste les pauses explicites pour approcher la durée visée : allongées (MAX_PAUSE au plus)
  // si la voix est plus rapide que prévu, raccourcies (MIN_PAUSE au moins) si elle est plus lente.
  const tail = script.ending === "sleep" ? SLEEP_TAIL : DAY_TAIL;
  const voiced = [...clips.values()].reduce((t, c) => t + c.length / SAMPLE_RATE, 0);
  const pauses = script.items.filter((i) => i.type === "pause");
  const natural = LEAD_IN + voiced + pauses.reduce((t, p) => t + p.seconds, 0) + tail;
  const adjustable = pauses.filter((p) => p.explicit);
  const plan = new Map(pauses.map((p) => [p, p.seconds]));
  let missing = script.targetSeconds - natural;
  if (missing < 0 && adjustable.length) {
    const room = adjustable.reduce((t, p) => t + Math.max(0, p.seconds - MIN_PAUSE), 0);
    const ratio = Math.min(1, -missing / Math.max(room, 0.001));
    for (const p of adjustable) plan.set(p, p.seconds - Math.max(0, p.seconds - MIN_PAUSE) * ratio);
    missing = 0;
  }
  if (missing > 0 && adjustable.length) {
    // Répartition proportionnelle, en redistribuant ce que le plafond empêche.
    let open = adjustable.filter((p) => plan.get(p) < MAX_PAUSE);
    while (missing > 0.5 && open.length) {
      const weight = open.reduce((t, p) => t + p.seconds, 0);
      for (const p of open) {
        const add = Math.min(missing * (p.seconds / weight), MAX_PAUSE - plan.get(p));
        plan.set(p, plan.get(p) + add);
      }
      missing = script.targetSeconds - (LEAD_IN + voiced + [...plan.values()].reduce((a, b) => a + b, 0) + tail);
      open = open.filter((p) => plan.get(p) < MAX_PAUSE - 0.01);
    }
  }

  const parts = [new Float32Array(Math.round(LEAD_IN * SAMPLE_RATE))];
  for (const item of script.items) {
    parts.push(item.type === "speech" ? clips.get(item) : new Float32Array(Math.round(plan.get(item) * SAMPLE_RATE)));
  }
  parts.push(new Float32Array(Math.round(tail * SAMPLE_RATE)));
  const total = parts.reduce((t, p) => t + p.length, 0);
  const samples = new Float32Array(total);
  let cursor = 0;
  for (const p of parts) { samples.set(p, cursor); cursor += p.length; }
  normalize(samples);

  fs.mkdirSync(OUT_DIR, { recursive: true });
  const wav = path.join(OUT_DIR, `${script.id}.wav`);
  const m4a = path.join(OUT_DIR, `${script.id}.m4a`);
  writeWav(wav, samples);
  execFileSync("afconvert", ["-f", "m4af", "-d", "aac", "-b", "96000", wav, m4a]);
  fs.rmSync(wav);

  const seconds = Math.round(total / SAMPLE_RATE);
  const voiceShare = Math.round((voiced / seconds) * 100);
  const gap = seconds - script.targetSeconds;
  const warn = Math.abs(gap) > script.targetSeconds * 0.1
    ? `  ⚠︎ ${gap > 0 ? "plus long" : "plus court"} que prévu de ${Math.abs(gap)} s : ajuster le texte ou les [pause]`
    : "";
  console.log(`✓ ${script.id} : ${fmt(seconds)} (visé ${fmt(script.targetSeconds)}), voix ${voiceShare} %, ${billed} caractères facturés${warn ? "\n" + warn : ""}`);
  return { seconds, billed };
}

const fmt = (s) => `${Math.floor(s / 60)} min ${String(Math.round(s % 60)).padStart(2, "0")}`;

// ---------- Programme ----------

const files = fs.existsSync(SCRIPTS_DIR) ? fs.readdirSync(SCRIPTS_DIR).filter((f) => f.endsWith(".md")).sort() : [];
const scripts = files.map((f) => parseScript(path.join(SCRIPTS_DIR, f)));
const ids = new Set();
for (const s of scripts) {
  if (ids.has(s.id)) throw new Error(`ID en double : ${s.id}`);
  ids.add(s.id);
}
const selected = only ? scripts.filter((s) => only.includes(s.id)) : scripts;
if (only) for (const id of only) if (!ids.has(id)) throw new Error(`Script introuvable : ${id}`);

if (dryRun) {
  let chars = 0;
  for (const s of selected) {
    const n = s.items.filter((i) => i.type === "speech").reduce((t, i) => t + i.text.length, 0);
    chars += n;
    console.log(`${s.id.padEnd(28)} ${String(n).padStart(6)} caractères  (${fmt(s.targetSeconds)} visées)`);
  }
  console.log(`\n${selected.length} séances, ${chars} caractères au total (avant cache).`);
  process.exit(0);
}

if (preview) {
  for (const script of selected) await render(script);
  console.log(`\nAperçu écrit dans ${path.relative(process.cwd(), OUT_DIR)} (voix du Mac, rien de facturé, JSON inchangé).`);
  process.exit(0);
}

if (!textOnly && (!API_KEY || !VOICE)) {
  console.error("ELEVENLABS_API_KEY et ELEVENLABS_VOICE_ID sont requis (ou --dry-run / --text-only).");
  process.exit(1);
}

// Le manifeste garde les entrées audio déjà générées pour les séances non relancées.
const previous = fs.existsSync(MANIFEST) ? JSON.parse(fs.readFileSync(MANIFEST, "utf8")) : { sessions: {} };
const manifest = { language: LANG, voice: VOICE || previous.voice || null, model: MODEL, sessions: {} };
let totalBilled = 0;
for (const script of scripts) {
  const entry = { title: script.title, transcript: transcriptOf(script), targetSeconds: script.targetSeconds };
  const old = previous.sessions?.[script.id];
  if (!textOnly && selected.includes(script)) {
    const { seconds, billed } = await render(script);
    totalBilled += billed;
    entry.audioPath = `${LANG}/${script.id}.m4a`;
    entry.durationSeconds = seconds;
  } else if (old?.audioPath && old.transcript === entry.transcript) {
    entry.audioPath = old.audioPath;
    entry.durationSeconds = old.durationSeconds;
  }
  manifest.sessions[script.id] = entry;
}
fs.mkdirSync(path.dirname(MANIFEST), { recursive: true });
fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2) + "\n");
console.log(`\nManifeste écrit : ${path.relative(process.cwd(), MANIFEST)} (${scripts.length} séances)`);
if (!textOnly) console.log(`Caractères facturés pendant ce lancement : ${totalBilled}. Étape suivante : node upload.mjs`);
