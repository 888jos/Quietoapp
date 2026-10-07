import { assertEquals } from "jsr:@std/assert@1";
import { appleClientSecret } from "./apple-signin.ts";
import { base64ToBytes, bytesToBase64 } from "./http.ts";

Deno.test("the Apple client_secret is a valid ES256 JWT", async () => {
  const keys = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = bytesToBase64(new Uint8Array(await crypto.subtle.exportKey("pkcs8", keys.privateKey)));
  // As stored by `supabase secrets set`, with literal "\n".
  const pem = `-----BEGIN PRIVATE KEY-----\\n${pkcs8.match(/.{1,64}/g)!.join("\\n")}\\n-----END PRIVATE KEY-----`;
  const now = Date.UTC(2026, 9, 7);
  const jwt = await appleClientSecret("TEAM123456", "KEY1234567", pem, "com.quietoapp.app", now);
  const [header, payload, signature] = jwt.split(".");
  const decode = (part: string) => JSON.parse(new TextDecoder().decode(base64ToBytes(part)));
  assertEquals(decode(header), { alg: "ES256", kid: "KEY1234567", typ: "JWT" });
  const claims = decode(payload);
  assertEquals(claims.iss, "TEAM123456");
  assertEquals(claims.sub, "com.quietoapp.app");
  assertEquals(claims.aud, "https://appleid.apple.com");
  assertEquals(claims.exp - claims.iat <= 900, true);
  assertEquals(/[+/=]/.test(jwt), false);
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" }, keys.publicKey, base64ToBytes(signature),
    new TextEncoder().encode(`${header}.${payload}`),
  );
  assertEquals(valid, true);
});
