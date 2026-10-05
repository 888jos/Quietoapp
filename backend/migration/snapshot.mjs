import { mkdir, readFile, writeFile, appendFile } from "node:fs/promises";
import { resolve } from "node:path";
import { applicationDefault, cert, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { sha256File, stableJSON } from "./lib.mjs";

const stamp = new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
const output = resolve(process.env.QUIETO_SNAPSHOT_DIR || `snapshots/${stamp}`);
await mkdir(output, { recursive: true, mode: 0o700 });

let credential = applicationDefault();
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  const raw = JSON.parse(await readFile(resolve(process.env.FIREBASE_SERVICE_ACCOUNT), "utf8"));
  credential = cert(raw);
}
initializeApp({ credential, projectId: process.env.FIREBASE_PROJECT_ID || "quieto-06" });

function serialise(value) {
  if (value === null || value === undefined || ["string", "number", "boolean"].includes(typeof value)) return value;
  if (Array.isArray(value)) return value.map(serialise);
  if (typeof value.toDate === "function") return { __type: "timestamp", value: value.toDate().toISOString() };
  if (typeof value.latitude === "number" && typeof value.longitude === "number") return { __type: "geopoint", latitude: value.latitude, longitude: value.longitude };
  if (typeof value.path === "string" && value.firestore) return { __type: "reference", path: value.path };
  if (Buffer.isBuffer(value) || value instanceof Uint8Array) return { __type: "bytes", base64: Buffer.from(value).toString("base64") };
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, serialise(item)]));
}

const authPath = `${output}/firebase-auth-users.ndjson`;
const firestorePath = `${output}/firestore-documents.ndjson`;
const revenueCatPath = `${output}/revenuecat-customers.ndjson`;
await Promise.all([writeFile(authPath, "", { mode: 0o600 }), writeFile(firestorePath, "", { mode: 0o600 }), writeFile(revenueCatPath, "", { mode: 0o600 })]);

const authUsers = [];
let pageToken;
do {
  const page = await getAuth().listUsers(1000, pageToken);
  for (const user of page.users) {
    const row = {
      uid: user.uid,
      email: user.email ?? null,
      emailVerified: user.emailVerified,
      displayName: user.displayName ?? null,
      disabled: user.disabled,
      providers: user.providerData.map((provider) => ({ providerId: provider.providerId, uid: provider.uid, email: provider.email ?? null })),
      customClaims: user.customClaims ?? {},
      metadata: { creationTime: user.metadata.creationTime, lastSignInTime: user.metadata.lastSignInTime },
      tokensValidAfterTime: user.tokensValidAfterTime,
      isAnonymous: user.providerData.length === 0 && !user.email && !user.phoneNumber,
    };
    authUsers.push(row);
    await appendFile(authPath, `${stableJSON(row)}\n`, { mode: 0o600 });
  }
  pageToken = page.pageToken;
} while (pageToken);

let firestoreCount = 0;
async function exportCollection(collection) {
  const snapshot = await collection.get();
  for (const document of snapshot.docs) {
    const parts = document.ref.path.split("/");
    const row = {
      collectionPath: parts.slice(0, -1).join("/"),
      documentId: parts.at(-1),
      data: serialise(document.data()),
      createTime: document.createTime?.toDate().toISOString() ?? null,
      updateTime: document.updateTime?.toDate().toISOString() ?? null,
    };
    await appendFile(firestorePath, `${stableJSON(row)}\n`, { mode: 0o600 });
    firestoreCount += 1;
    for (const child of await document.ref.listCollections()) await exportCollection(child);
  }
}
for (const collection of await getFirestore().listCollections()) await exportCollection(collection);

let revenueCatCount = 0;
const revenueCatKey = process.env.RC_API_KEY?.trim();
if (revenueCatKey) {
  for (const user of authUsers) {
    const result = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(user.uid)}`, {
      headers: { authorization: `Bearer ${revenueCatKey}`, "x-platform": "ios" },
      signal: AbortSignal.timeout(15000),
    });
    if (result.status === 404) continue;
    if (!result.ok) throw new Error(`RevenueCat ${result.status} pour ${user.uid}`);
    const customer = await result.json();
    await appendFile(revenueCatPath, `${stableJSON({ appUserId: user.uid, customer, fetchedAt: new Date().toISOString() })}\n`, { mode: 0o600 });
    revenueCatCount += 1;
  }
}

const files = {};
for (const [name, path, count] of [
  ["firebase-auth-users.ndjson", authPath, authUsers.length],
  ["firestore-documents.ndjson", firestorePath, firestoreCount],
  ["revenuecat-customers.ndjson", revenueCatPath, revenueCatCount],
]) files[name] = { count, sha256: await sha256File(path) };

const manifest = {
  formatVersion: 1,
  source: { firebaseProject: process.env.FIREBASE_PROJECT_ID || "quieto-06", revenueCatIncluded: Boolean(revenueCatKey) },
  createdAt: new Date().toISOString(),
  files,
};
await writeFile(`${output}/manifest.json`, `${stableJSON(manifest)}\n`, { mode: 0o600 });
console.log(JSON.stringify({ ok: true, output, counts: Object.fromEntries(Object.entries(files).map(([key, value]) => [key, value.count])) }));

