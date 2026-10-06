// Native app → Firebase `louane` callable. Hard paywall: only users with a
// server-verified entitlement get through. The Firebase side trusts the
// headers below only because they come with the shared proxy secret.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, readBody, reply } from "../_shared/http.ts";

const maxBodyBytes = 32 * 1024;
// Below the app's own 35 s timeout so a slow upstream never bills a request
// the user already gave up on.
const upstreamTimeoutMs = 30_000;

function clientIP(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for") ?? "";
  const first = forwarded.split(",").map((part) => part.trim()).find(Boolean);
  return (first ?? request.headers.get("cf-connecting-ip") ?? "").slice(0, 64);
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const admin = adminClient();
  const proxySecret = Deno.env.get("QUIETO_FIREBASE_PROXY_SECRET") ?? "";
  const firebaseURL = Deno.env.get("QUIETO_LOUANE_FIREBASE_URL") ?? "https://us-central1-quieto-06.cloudfunctions.net/louane";
  const bearer = request.headers.get("authorization") ?? "";
  if (!admin || !proxySecret) return reply(503, { error: "not_configured" });
  if (!bearer.startsWith("Bearer ")) return reply(401, { error: "unauthorized" });

  const { data, error } = await admin.auth.getUser(bearer.slice(7));
  if (error || !data.user) return reply(401, { error: "unauthorized" });
  const user = data.user;

  const { data: premium, error: premiumError } = await admin.rpc("user_has_premium", { p_user_id: user.id });
  if (premiumError) return reply(503, { error: "entitlement_unavailable" });
  if (premium !== true) return reply(402, { error: "premium_required" });

  const body = await readBody(request, maxBodyBytes);
  if (body === null) return reply(413, { error: "payload_too_large" });
  try {
    JSON.parse(body);
  } catch {
    return reply(400, { error: "invalid_json" });
  }

  // Users who came from the Flutter app keep their Firebase identity on the
  // Louane side: memory, counters and history live under that UID.
  const { data: profile } = await admin.from("profiles").select("firebase_uid").eq("user_id", user.id).maybeSingle();
  const louaneUID = (profile?.firebase_uid as string | null) ?? user.id;

  let upstream: Response;
  try {
    upstream = await fetch(firebaseURL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-quieto-proxy-secret": proxySecret,
        "x-quieto-supabase-user": louaneUID,
        "x-quieto-premium": "1",
        "x-quieto-anonymous": user.is_anonymous ? "1" : "0",
        "x-quieto-client-ip": clientIP(request),
      },
      body,
      signal: AbortSignal.timeout(upstreamTimeoutMs),
    });
  } catch (cause) {
    const timedOut = cause instanceof DOMException && cause.name === "TimeoutError";
    return reply(timedOut ? 504 : 502, { error: timedOut ? "upstream_timeout" : "upstream_unreachable" });
  }
  return new Response(await upstream.arrayBuffer(), {
    status: upstream.status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
});
