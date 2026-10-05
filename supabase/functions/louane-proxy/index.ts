import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const json = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers: json });
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const secretKey = Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
  const proxySecret = Deno.env.get("QUIETO_FIREBASE_PROXY_SECRET") ?? "";
  const firebaseURL = Deno.env.get("QUIETO_LOUANE_FIREBASE_URL") ?? "https://us-central1-quieto-06.cloudfunctions.net/louane";
  const bearer = request.headers.get("authorization") ?? "";
  if (!url || !secretKey || !proxySecret || !bearer.startsWith("Bearer ")) return new Response(JSON.stringify({ error: "not_configured" }), { status: 503, headers: json });
  const admin = createClient(url, secretKey, { auth: { persistSession: false } });
  const { data, error } = await admin.auth.getUser(bearer.slice(7));
  if (error || !data.user) return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: json });

  let body: unknown;
  try { body = await request.json(); } catch { return new Response(JSON.stringify({ error: "invalid_json" }), { status: 400, headers: json }); }
  const upstream = await fetch(firebaseURL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-quieto-proxy-secret": proxySecret,
      "x-quieto-supabase-user": data.user.id,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(40_000),
  });
  return new Response(await upstream.arrayBuffer(), { status: upstream.status, headers: json });
});
