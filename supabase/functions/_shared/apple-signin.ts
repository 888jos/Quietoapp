// Sign in with Apple: client_secret for appleid.apple.com (token exchange and
// revocation on account deletion). WebCrypto only, no dependency.
import { base64ToBytes, bytesToBase64 } from "./http.ts";

function base64URL(bytes: Uint8Array): string {
  return bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** ES256 client_secret for appleid.apple.com, valid 5 minutes. */
export async function appleClientSecret(
  teamID: string,
  keyID: string,
  privateKeyPEM: string,
  clientID: string,
  now = Date.now(),
): Promise<string> {
  // Secrets set from a shell often keep "\n" literally.
  const body = privateKeyPEM.replace(/\\n/g, "\n").replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s+/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(body),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const issuedAt = Math.floor(now / 1000);
  const encoder = new TextEncoder();
  const header = base64URL(encoder.encode(JSON.stringify({ alg: "ES256", kid: keyID, typ: "JWT" })));
  const payload = base64URL(encoder.encode(JSON.stringify({
    iss: teamID,
    iat: issuedAt,
    exp: issuedAt + 300,
    aud: "https://appleid.apple.com",
    sub: clientID,
  })));
  // WebCrypto ECDSA signatures are already raw r||s, the JWS ES256 format.
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(`${header}.${payload}`)),
  );
  return `${header}.${payload}.${base64URL(signature)}`;
}
