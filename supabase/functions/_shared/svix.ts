// Superwall delivers webhooks through Svix: HMAC-SHA256 over
// `${svix-id}.${svix-timestamp}.${raw body}` with the base64 secret that follows
// the `whsec_` prefix. The header carries space-separated `v1,<base64>` entries.
import { base64ToBytes, timingSafeEqual } from "./http.ts";

const toleranceSeconds = 5 * 60;

export async function verifySvixSignature(
  secret: string,
  headers: Headers,
  body: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<boolean> {
  const id = headers.get("svix-id") ?? headers.get("webhook-id") ?? "";
  const timestamp = headers.get("svix-timestamp") ?? headers.get("webhook-timestamp") ?? "";
  const signatures = headers.get("svix-signature") ?? headers.get("webhook-signature") ?? "";
  if (!secret || !id || !timestamp || !signatures) return false;
  const sentAt = Number(timestamp);
  if (!Number.isFinite(sentAt) || Math.abs(nowSeconds - sentAt) > toleranceSeconds) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    base64ToBytes(secret.startsWith("whsec_") ? secret.slice("whsec_".length) : secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const expected = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${id}.${timestamp}.${body}`)),
  );
  return signatures.split(" ").some((entry) => {
    const [version, signature] = entry.split(",", 2);
    if (version !== "v1" || !signature) return false;
    try {
      return timingSafeEqual(base64ToBytes(signature), expected);
    } catch {
      return false;
    }
  });
}
