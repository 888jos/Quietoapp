// « Accès offert par mon entreprise »: an employee activates Premium with the
// company code. Replaces the Firebase callable accesEntreprise.
//   POST {code}                  → 200 {nom}                    (preview)
//   POST {code, confirmer: true} → 200 {ok, nom, finMs, premium} (seat taken)
// Errors: {error, raison, message}, `message` already written for the screen;
// raison ∈ compte | inconnu | inactif | complet | quota.
// A Supabase account linked to Apple (not anonymous) is required, otherwise
// the access is lost with the phone. One seat per person, never above the
// paid seats; joining another company frees the seat at the previous one.
// Access lasts until the end of the paid period + 10 days and follows
// renewals automatically (trigger on public.enterprises).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { adminClient, readBody } from "../_shared/http.ts";
import { ipKey, json, LIMITS, normalizeCode, preflight, underLimit } from "../_shared/entreprise.ts";

const messages = {
  compte: "Connecte-toi avec Apple pour garder ton accès si tu changes de téléphone.",
  inconnu: "Ce code ne correspond à aucune entreprise. Vérifie-le auprès de ta RH.",
  inactif: "L'accès Quieto de ton entreprise n'est plus actif. Parles-en à ta RH.",
  complet: "Toutes les places de ton entreprise sont prises. Parles-en à ta RH.",
  quota: "Trop d'essais aujourd'hui. Réessaie demain.",
};

function failure(status: number, raison: keyof typeof messages): Response {
  return json(status, { error: raison, raison, message: messages[raison] });
}

Deno.serve(async (request: Request) => {
  const options = preflight(request);
  if (options) return options;
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
  const admin = adminClient();
  if (!admin) return json(503, { error: "server_not_configured" });

  const bearer = request.headers.get("authorization") ?? "";
  if (!bearer.startsWith("Bearer ")) return json(401, { error: "unauthorized" });
  const { data: identity, error: identityError } = await admin.auth.getUser(bearer.slice(7));
  if (identityError || !identity.user) return json(401, { error: "invalid_token" });
  const user = identity.user;
  if (user.is_anonymous) return failure(403, "compte");

  if (!(await underLimit(admin, "entreprise", await ipKey(request), LIMITS.entreprise)) ||
    !(await underLimit(admin, "entreprise_user", user.id, LIMITS.entrepriseUser))) {
    return failure(429, "quota");
  }

  const body = await readBody(request, 4 * 1024);
  if (body === null) return json(413, { error: "payload_too_large" });
  let d: Record<string, unknown> = {};
  try {
    const parsed = JSON.parse(body);
    if (parsed && typeof parsed === "object") d = parsed;
  } catch {
    return json(400, { error: "invalid_json" });
  }
  const codeKey = normalizeCode(d.code);
  if (codeKey.length < 6) return failure(404, "inconnu");
  const confirm = d.confirmer === true;

  if (confirm) {
    // enterprise_access references profiles(user_id).
    const { error: profileError } = await admin.from("profiles").upsert({
      user_id: user.id,
      is_anonymous: false,
    }, { onConflict: "user_id", ignoreDuplicates: true });
    if (profileError) return json(500, { error: "profile_upsert_failed" });
  }

  const { data, error } = await admin.rpc("enterprise_join", { p_user_id: user.id, p_code_key: codeKey, p_confirm: confirm });
  if (error || !data) {
    console.error("[Entreprise] enterprise_join :", error?.message);
    return json(503, { error: "unavailable", message: "L'activation n'a pas abouti. Réessaie dans un instant." });
  }
  const outcome = data as { status: string; name?: string; granted_until?: string };
  switch (outcome.status) {
    case "unknown":
      return failure(404, "inconnu");
    case "inactive":
      return failure(410, "inactif");
    case "full":
      return failure(409, "complet");
    case "preview":
      return json(200, { nom: outcome.name });
    case "joined": {
      const { data: premium } = await admin.rpc("user_has_premium", { p_user_id: user.id });
      return json(200, {
        ok: true,
        nom: outcome.name,
        finMs: outcome.granted_until ? Date.parse(outcome.granted_until) : null,
        premium: premium === true,
      });
    }
    default:
      return json(500, { error: "unexpected_status" });
  }
});
