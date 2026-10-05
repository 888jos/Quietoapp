import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { applicationDefault, cert, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

let credential = applicationDefault();
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  credential = cert(JSON.parse(await readFile(resolve(process.env.FIREBASE_SERVICE_ACCOUNT), "utf8")));
}
initializeApp({ credential, projectId: process.env.FIREBASE_PROJECT_ID || "quieto-06" });

let pageToken;
let updated = 0;
do {
  const page = await getAuth().listUsers(1000, pageToken);
  for (const user of page.users) {
    await getAuth().setCustomUserClaims(user.uid, { ...(user.customClaims ?? {}), role: "authenticated" });
    updated += 1;
  }
  pageToken = page.pageToken;
} while (pageToken);
console.log(JSON.stringify({ ok: true, updated }));
