// deno test --allow-net=none supabase/functions/_shared
import "npm:reflect-metadata@0.2.2";
import * as x509 from "npm:@peculiar/x509@2.1.0";
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { AppleJWSError, verifyAppleTransaction } from "./apple-jws.ts";
import { bytesToBase64 } from "./http.ts";

x509.cryptoProvider.set(crypto);
const algorithm = { name: "ECDSA", namedCurve: "P-256", hash: "SHA-256" };

function appleOID(oid: string) {
  return new x509.Extension(oid, false, new Uint8Array([0x05, 0x00]));
}

async function chain(options: { leafOID?: boolean } = {}) {
  const rootKeys = await crypto.subtle.generateKey(algorithm, true, ["sign", "verify"]);
  const interKeys = await crypto.subtle.generateKey(algorithm, true, ["sign", "verify"]);
  const leafKeys = await crypto.subtle.generateKey(algorithm, true, ["sign", "verify"]);
  const notBefore = new Date(Date.now() - 86_400_000);
  const notAfter = new Date(Date.now() + 365 * 86_400_000);
  const root = await x509.X509CertificateGenerator.createSelfSigned({
    serialNumber: "01", name: "CN=Test Root", notBefore, notAfter, keys: rootKeys, signingAlgorithm: algorithm,
    extensions: [new x509.BasicConstraintsExtension(true, undefined, true)],
  });
  const intermediate = await x509.X509CertificateGenerator.create({
    serialNumber: "02", subject: "CN=Test Intermediate", issuer: root.subject, notBefore, notAfter,
    publicKey: interKeys.publicKey, signingKey: rootKeys.privateKey, signingAlgorithm: algorithm,
    extensions: [new x509.BasicConstraintsExtension(true, 0, true), appleOID("1.2.840.113635.100.6.2.1")],
  });
  const leaf = await x509.X509CertificateGenerator.create({
    serialNumber: "03", subject: "CN=Test Leaf", issuer: intermediate.subject, notBefore, notAfter,
    publicKey: leafKeys.publicKey, signingKey: interKeys.privateKey, signingAlgorithm: algorithm,
    extensions: options.leafOID === false ? [] : [appleOID("1.2.840.113635.100.6.11.1")],
  });
  const rootSHA256 = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", root.rawData)), (b) => b.toString(16).padStart(2, "0")).join("");
  return { certificates: [leaf, intermediate, root], leafKey: leafKeys.privateKey, rootSHA256 };
}

function base64url(bytes: Uint8Array) {
  return bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function sign(payload: Record<string, unknown>, certificates: x509.X509Certificate[], key: CryptoKey) {
  const header = { alg: "ES256", x5c: certificates.map((certificate) => bytesToBase64(new Uint8Array(certificate.rawData))) };
  const encoded = `${base64url(new TextEncoder().encode(JSON.stringify(header)))}.${base64url(new TextEncoder().encode(JSON.stringify(payload)))}`;
  const signature = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(encoded)));
  return `${encoded}.${base64url(signature)}`;
}

const transaction = {
  transactionId: "2000000001", originalTransactionId: "2000000000", bundleId: "com.quietoapp.app",
  productId: "quieto.premium.annual", type: "Auto-Renewable Subscription", environment: "Sandbox",
  expiresDate: Date.now() + 86_400_000, signedDate: Date.now(),
};

Deno.test("accepts a correctly signed transaction from the pinned root", async () => {
  const { certificates, leafKey, rootSHA256 } = await chain();
  const verified = await verifyAppleTransaction(await sign(transaction, certificates, leafKey), { rootSHA256 });
  assertEquals(verified.originalTransactionId, "2000000000");
});

Deno.test("rejects a chain that does not end at Apple's root", async () => {
  const { certificates, leafKey } = await chain();
  const jws = await sign(transaction, certificates, leafKey);
  await assertRejects(() => verifyAppleTransaction(jws), AppleJWSError, "untrusted_root");
});

Deno.test("rejects a tampered payload", async () => {
  const { certificates, leafKey, rootSHA256 } = await chain();
  const [header, , signature] = (await sign(transaction, certificates, leafKey)).split(".");
  const forged = base64url(new TextEncoder().encode(JSON.stringify({ ...transaction, expiresDate: Date.now() + 1e12 })));
  await assertRejects(() => verifyAppleTransaction(`${header}.${forged}.${signature}`, { rootSHA256 }), AppleJWSError, "invalid_signature");
});

Deno.test("rejects a leaf without the App Store receipt OID", async () => {
  const { certificates, leafKey, rootSHA256 } = await chain({ leafOID: false });
  const jws = await sign(transaction, certificates, leafKey);
  await assertRejects(() => verifyAppleTransaction(jws, { rootSHA256 }), AppleJWSError, "missing_apple_oid");
});

Deno.test("rejects a key that is not the leaf's", async () => {
  const { certificates, rootSHA256 } = await chain();
  const other = await crypto.subtle.generateKey(algorithm, true, ["sign", "verify"]);
  const jws = await sign(transaction, certificates, other.privateKey);
  await assertRejects(() => verifyAppleTransaction(jws, { rootSHA256 }), AppleJWSError, "invalid_signature");
});
