// Verification of StoreKit 2 signed transactions (JWS, ES256, x5c chain).
// Same checks as Apple's App Store Server Library: chain up to the pinned
// Apple Root CA - G3, Apple OIDs on the leaf and intermediate, certificate
// validity at the signing date, then the ES256 signature itself.
import "npm:reflect-metadata@0.2.2"; // required by @peculiar/x509 (tsyringe)
import * as x509 from "npm:@peculiar/x509@2.1.0";
import { base64ToBytes } from "./http.ts";

x509.cryptoProvider.set(crypto);

// SHA-256 of https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
export const APPLE_ROOT_CA_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";
const leafOID = "1.2.840.113635.100.6.11.1";
const intermediateOID = "1.2.840.113635.100.6.2.1";

export interface AppleTransaction {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  type?: string;
  environment?: string;
  appAccountToken?: string;
  purchaseDate?: number;
  expiresDate?: number;
  revocationDate?: number;
  signedDate: number;
  offerType?: number;
  offerDiscountType?: string;
}

export class AppleJWSError extends Error {}

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function verifyAppleTransaction(
  jws: string,
  options: { rootSHA256?: string; now?: Date } = {},
): Promise<AppleTransaction> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new AppleJWSError("malformed_jws");
  const [encodedHeader, encodedPayload, encodedSignature] = parts;

  let header: { alg?: string; x5c?: string[] };
  let payload: AppleTransaction;
  try {
    header = JSON.parse(new TextDecoder().decode(base64ToBytes(encodedHeader)));
    payload = JSON.parse(new TextDecoder().decode(base64ToBytes(encodedPayload)));
  } catch {
    throw new AppleJWSError("malformed_jws");
  }
  if (header.alg !== "ES256" || !Array.isArray(header.x5c) || header.x5c.length !== 3) {
    throw new AppleJWSError("unexpected_header");
  }

  const [leaf, intermediate, root] = header.x5c.map((certificate) => new x509.X509Certificate(base64ToBytes(certificate)));
  const rootDigest = hex(await crypto.subtle.digest("SHA-256", root.rawData));
  if (rootDigest !== (options.rootSHA256 ?? APPLE_ROOT_CA_G3_SHA256)) throw new AppleJWSError("untrusted_root");
  if (!leaf.getExtension(leafOID) || !intermediate.getExtension(intermediateOID)) {
    throw new AppleJWSError("missing_apple_oid");
  }

  const signedAt = new Date(Number(payload.signedDate) || 0);
  if (signedAt.getTime() <= 0) throw new AppleJWSError("missing_signed_date");
  if (signedAt.getTime() > (options.now ?? new Date()).getTime() + 5 * 60_000) throw new AppleJWSError("signed_in_future");
  const chainValid = await leaf.verify({ publicKey: intermediate.publicKey, date: signedAt }) &&
    await intermediate.verify({ publicKey: root.publicKey, date: signedAt }) &&
    await root.verify({ publicKey: root.publicKey, date: signedAt });
  if (!chainValid) throw new AppleJWSError("invalid_chain");

  const key = await leaf.publicKey.export({ name: "ECDSA", namedCurve: "P-256" }, ["verify"]);
  const signatureValid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    base64ToBytes(encodedSignature),
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
  );
  if (!signatureValid) throw new AppleJWSError("invalid_signature");
  if (!payload.originalTransactionId || !payload.bundleId || !payload.productId) {
    throw new AppleJWSError("incomplete_transaction");
  }
  return payload;
}
