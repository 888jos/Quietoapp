import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers });
}

Deno.serve(async (request: Request) => {
  if (request.method !== "GET" && request.method !== "DELETE") {
    return reply(405, { error: "method_not_allowed" });
  }
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const secret = Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
  const bearer = request.headers.get("authorization") ?? "";
  if (!url || !secret || !bearer.startsWith("Bearer ")) {
    return reply(401, { error: "unauthorized" });
  }

  const admin = createClient(url, secret, { auth: { persistSession: false } });
  const token = bearer.slice("Bearer ".length);
  const { data: identity, error: identityError } = await admin.auth.getUser(token);
  const user = identity.user;
  if (identityError || !user) return reply(401, { error: "invalid_token" });
  const userID = user.id;

  if (request.method === "GET") {
    const tables = [
      "profiles", "user_preferences", "session_progress", "listening_events",
      "programs", "louane_conversations", "louane_messages", "louane_memory",
      "subscription_accounts", "subscription_events", "enterprise_access",
    ];
    const exported: Record<string, unknown> = {};
    for (const table of tables) {
      const { data, error } = await admin.from(table).select("*").eq("user_id", userID);
      if (error) return reply(500, { error: "export_failed", table });
      exported[table] = data;
    }
    return reply(200, {
      format: "quieto-account-export-v1",
      generated_at: new Date().toISOString(),
      user: { id: userID, email: user.email ?? null, anonymous: user.is_anonymous ?? false },
      data: exported,
    });
  }

  // Deleting profiles cascades through all user-owned product tables. Immutable
  // migration evidence is deliberately retained for legal/audit migration checks.
  const { error: profileError } = await admin.from("profiles").delete().eq("user_id", userID);
  if (profileError) return reply(500, { error: "data_delete_failed" });
  const { error: authError } = await admin.auth.admin.deleteUser(userID);
  if (authError) return reply(500, { error: "auth_delete_failed", product_data_deleted: true });
  return reply(200, { ok: true, subscription_cancelled: false });
});
