import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, reply } from "../_shared/http.ts";

// GET: export (RGPD art. 15/20). POST {action:"link-legacy"}: inherit the
// Firebase account that used the same Apple identity. DELETE: erasure (art. 17),
// including the imported Firebase/RevenueCat evidence of a linked account.
Deno.serve(async (request: Request) => {
  if (!["GET", "POST", "DELETE"].includes(request.method)) {
    return reply(405, { error: "method_not_allowed" });
  }
  const admin = adminClient();
  const bearer = request.headers.get("authorization") ?? "";
  if (!admin || !bearer.startsWith("Bearer ")) return reply(401, { error: "unauthorized" });

  const { data: identity, error: identityError } = await admin.auth.getUser(bearer.slice("Bearer ".length));
  const user = identity.user;
  if (identityError || !user) return reply(401, { error: "invalid_token" });
  const userID = user.id;

  const { data: profile } = await admin.from("profiles").select("firebase_uid").eq("user_id", userID).maybeSingle();
  const firebaseUID = (profile?.firebase_uid as string | null) ?? null;

  if (request.method === "GET") {
    const tables = [
      "profiles", "user_preferences", "session_progress", "listening_events",
      "programs", "louane_conversations", "louane_messages", "louane_memory",
      "subscription_accounts", "subscription_events", "enterprise_access", "analytics_events",
    ];
    const exported: Record<string, unknown> = {};
    for (const table of tables) {
      const { data, error } = await admin.from(table).select("*").eq("user_id", userID);
      if (error) return reply(500, { error: "export_failed", table });
      exported[table] = data;
    }
    const programIDs = ((exported.programs as { id: string }[]) ?? []).map((program) => program.id);
    if (programIDs.length) {
      const { data, error } = await admin.from("program_steps").select("*").in("program_id", programIDs);
      if (error) return reply(500, { error: "export_failed", table: "program_steps" });
      exported.program_steps = data;
    } else {
      exported.program_steps = [];
    }
    return reply(200, {
      format: "quieto-account-export-v2",
      generated_at: new Date().toISOString(),
      user: { id: userID, email: user.email ?? null, anonymous: user.is_anonymous ?? false, legacy_firebase_uid: firebaseUID },
      data: exported,
    });
  }

  if (request.method === "POST") {
    let action = "";
    try {
      action = String((await request.json()).action ?? "");
    } catch {
      return reply(400, { error: "invalid_json" });
    }
    if (action !== "link-legacy") return reply(400, { error: "unknown_action" });
    const apple = (user.identities ?? []).find((entry) => entry.provider === "apple");
    const appleSub = String(apple?.identity_data?.sub ?? apple?.id ?? "");
    if (!appleSub) return reply(200, { linked: false, reason: "no_apple_identity" });
    await admin.from("profiles").upsert({ user_id: userID, is_anonymous: false }, { onConflict: "user_id", ignoreDuplicates: true });
    const { data: legacy, error } = await admin.rpc("link_legacy_firebase_account", { p_user_id: userID, p_apple_sub: appleSub });
    if (error) return reply(500, { error: "link_failed" });
    return reply(200, { linked: Boolean(legacy) });
  }

  // DELETE. Subscription events have no foreign key: purge them explicitly.
  const { error: eventsError } = await admin.from("subscription_events").delete().eq("user_id", userID);
  if (eventsError) return reply(500, { error: "data_delete_failed" });
  if (firebaseUID) {
    const { error: legacyError } = await admin.rpc("purge_legacy_user", { p_firebase_uid: firebaseUID });
    if (legacyError) return reply(500, { error: "legacy_delete_failed" });
  }
  // Cascades through every user-owned product table; store subscriptions are
  // released (user_id set to null) so a later claim can bind them again.
  const { error: profileError } = await admin.from("profiles").delete().eq("user_id", userID);
  if (profileError) return reply(500, { error: "data_delete_failed" });
  const { error: authError } = await admin.auth.admin.deleteUser(userID);
  if (authError) return reply(500, { error: "auth_delete_failed", product_data_deleted: true });
  // The App Store subscription itself is managed by Apple; the app links to
  // the system subscription settings before deletion.
  return reply(200, { ok: true, subscription_cancelled: false, legacy_firebase_uid: firebaseUID });
});
