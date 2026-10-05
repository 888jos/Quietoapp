import postgres from "postgres";
import { readManifest, requireEnv } from "./lib.mjs";

const directory = process.argv[2];
if (!directory) throw new Error("Usage: npm run verify -- /chemin/du/snapshot");
const manifest = await readManifest(directory);
const sql = postgres(requireEnv("SUPABASE_DB_URL"), { max: 1, ssl: "require", prepare: false });

const [auth] = await sql`select count(*)::bigint as count from migration.firebase_auth_users`;
const [documents] = await sql`select count(*)::bigint as count from migration.firebase_documents`;
const [revenuecat] = await sql`select count(*)::bigint as count from migration.revenuecat_customers`;
const [catalog] = await sql`select count(*)::bigint as count from public.sessions where is_active`;
const actual = {
  "firebase-auth-users.ndjson": Number(auth.count),
  "firestore-documents.ndjson": Number(documents.count),
  "revenuecat-customers.ndjson": Number(revenuecat.count),
};
const differences = Object.fromEntries(Object.entries(actual).filter(([name, count]) => count < manifest.files[name].count).map(([name, count]) => [name, { expectedAtLeast: manifest.files[name].count, actual: count }]));
await sql.end();
if (Number(catalog.count) !== 35) differences.catalog = { expected: 35, actual: Number(catalog.count) };
console.log(JSON.stringify({ ok: Object.keys(differences).length === 0, actual, catalog: Number(catalog.count), differences }, null, 2));
if (Object.keys(differences).length) process.exitCode = 1;

