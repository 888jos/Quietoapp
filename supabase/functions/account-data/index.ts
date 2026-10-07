import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, readBody, reply } from "../_shared/http.ts";
import { appleClientSecret } from "../_shared/apple-signin.ts";

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
      "practice_entries",
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

  // DELETE. public.purge_user_data() runs in one transaction: subscription
  // events (no foreign key, payload carries originalAppUserId), store
  // subscriptions anonymised and detached (raw appAccountToken removed, so a
  // later device claim can bind them again), rate-limit rows, then the profile,
  // which cascades through every user-owned product table (practice_entries,
  // analytics_events, listening_events, Louane, programs, enterprise seat…).
  // Optional body {"apple_authorization_code": "..."}: a DELETE without a body
  // (or with invalid JSON) still deletes the account.
  let appleAuthorizationCode = "";
  try {
    const raw = await readBody(request, 16 * 1024);
    const parsed = raw ? JSON.parse(raw) : null;
    const code = parsed && typeof parsed === "object" ? (parsed as Record<string, unknown>).apple_authorization_code : null;
    if (typeof code === "string" && code.length > 0 && code.length < 2048) appleAuthorizationCode = code;
  } catch {
    // No usable body: nothing to revoke at Apple.
  }

  const { error: purgeError } = await admin.rpc("purge_user_data", { p_user_id: userID });
  if (purgeError) return reply(500, { error: "data_delete_failed" });
  if (firebaseUID) {
    const { error: legacyError } = await admin.rpc("purge_legacy_user", { p_firebase_uid: firebaseUID });
    if (legacyError) return reply(500, { error: "legacy_delete_failed" });
  }
  const { error: authError } = await admin.auth.admin.deleteUser(userID);
  if (authError) return reply(500, { error: "auth_delete_failed", product_data_deleted: true });
  // Third parties: best effort, never blocks the erasure (null = not configured).
  const [revenuecat, amplitude, apple] = await Promise.all([
    firebaseUID ? deleteRevenueCatSubscriber(firebaseUID) : Promise.resolve(null),
    deleteAmplitudeUsers([userID, ...(firebaseUID ? [firebaseUID] : [])]),
    appleAuthorizationCode ? revokeSignInWithApple(appleAuthorizationCode) : Promise.resolve(null),
  ]);
  // The App Store subscription itself is managed by Apple; the app links to
  // the system subscription settings before deletion.
  return reply(200, {
    ok: true,
    subscription_cancelled: false,
    legacy_firebase_uid: firebaseUID,
    third_parties: { revenuecat, amplitude, apple },
  });
});

const thirdPartyTimeoutMs = 8_000;

// Legacy Flutter subscribers (RevenueCat app_user_id = Firebase UID), same call
// as the Firebase `supprimerDonnees` function. Secret key "sk_…" only.
async function deleteRevenueCatSubscriber(appUserID: string): Promise<boolean | null> {
  const key = Deno.env.get("REVENUECAT_SECRET_API_KEY") ?? "";
  if (!key.startsWith("sk_")) return null;
  try {
    const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserID)}`, {
      method: "DELETE",
      headers: { authorization: `Bearer ${key}` },
      signal: AbortSignal.timeout(thirdPartyTimeoutMs),
    });
    if (!response.ok && response.status !== 404) console.error("[account-data] RevenueCat HTTP", response.status);
    return response.ok || response.status === 404;
  } catch (error) {
    console.error("[account-data] RevenueCat unreachable:", error instanceof Error ? error.message : error);
    return false;
  }
}

// Amplitude User Privacy API (deletion job, processed by Amplitude within
// 30 days). EU data centre: AMPLITUDE_DELETION_URL =
// https://analytics.eu.amplitude.com/api/2/deletions/users
async function deleteAmplitudeUsers(userIDs: string[]): Promise<boolean | null> {
  const apiKey = Deno.env.get("AMPLITUDE_API_KEY") ?? "";
  const secretKey = Deno.env.get("AMPLITUDE_SECRET_KEY") ?? "";
  if (!apiKey || !secretKey) return null;
  const url = Deno.env.get("AMPLITUDE_DELETION_URL") ?? "https://amplitude.com/api/2/deletions/users";
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        authorization: `Basic ${btoa(`${apiKey}:${secretKey}`)}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ user_ids: userIDs, requester: "quieto-account-data", ignore_invalid_id: "True" }),
      signal: AbortSignal.timeout(thirdPartyTimeoutMs),
    });
    if (!response.ok) console.error("[account-data] Amplitude HTTP", response.status);
    return response.ok;
  } catch (error) {
    console.error("[account-data] Amplitude unreachable:", error instanceof Error ? error.message : error);
    return false;
  }
}

// Sign in with Apple (App Store Review Guideline 5.1.1(v)): exchange the fresh
// authorization code sent by the app for a refresh token, then revoke it.
// Needs APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (.p8 PEM) and
// APPLE_CLIENT_ID (bundle id). Logs never contain the code nor a token.
async function revokeSignInWithApple(authorizationCode: string): Promise<boolean | null> {
  const teamID = Deno.env.get("APPLE_TEAM_ID") ?? "";
  const keyID = Deno.env.get("APPLE_KEY_ID") ?? "";
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY") ?? "";
  const clientID = Deno.env.get("APPLE_CLIENT_ID") ?? "";
  if (!teamID || !keyID || !privateKey || !clientID) return null;
  try {
    const clientSecret = await appleClientSecret(teamID, keyID, privateKey, clientID);
    const tokenResponse = await fetch("https://appleid.apple.com/auth/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: clientID,
        client_secret: clientSecret,
        code: authorizationCode,
        grant_type: "authorization_code",
      }),
      signal: AbortSignal.timeout(thirdPartyTimeoutMs),
    });
    if (!tokenResponse.ok) {
      console.error("[account-data] Apple token exchange HTTP", tokenResponse.status);
      return false;
    }
    const tokens = await tokenResponse.json() as { refresh_token?: unknown; access_token?: unknown };
    const refreshToken = typeof tokens.refresh_token === "string" ? tokens.refresh_token : "";
    const accessToken = typeof tokens.access_token === "string" ? tokens.access_token : "";
    if (!refreshToken && !accessToken) {
      console.error("[account-data] Apple token exchange returned no token");
      return false;
    }
    const revokeResponse = await fetch("https://appleid.apple.com/auth/revoke", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: clientID,
        client_secret: clientSecret,
        token: refreshToken || accessToken,
        token_type_hint: refreshToken ? "refresh_token" : "access_token",
      }),
      signal: AbortSignal.timeout(thirdPartyTimeoutMs),
    });
    if (!revokeResponse.ok) console.error("[account-data] Apple revoke HTTP", revokeResponse.status);
    return revokeResponse.ok;
  } catch (error) {
    console.error("[account-data] Apple revocation failed:", error instanceof Error ? error.name : "unknown");
    return false;
  }
}
