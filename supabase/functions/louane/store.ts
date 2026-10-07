// Server state of Louane in Postgres (migration 20261007090000_louane_supabase.sql),
// replacing the Firestore collections of the Firebase function. Same rule as
// before: a database failure never blocks a message (quotas are a safety net,
// not the product) and never silences the safety message.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";
import { ALERTE_MEMOIRE_MS } from "./logic.ts";

export type Compteurs = { total: number; n: number };

/** Daily quota; false = limit reached. Failure → let through (logged). */
export async function compterParJour(
  admin: SupabaseClient, scope: "ip" | "user", subject: string, field: string, limit: number, weight = 1,
): Promise<boolean> {
  const { data, error } = await admin.rpc("louane_rate_limit_hit", {
    p_scope: scope, p_subject: subject, p_field: field, p_limit: limit, p_weight: weight,
  });
  if (error) {
    console.error("[Quota]", scope, field, "illisible (on laisse passer) :", error.message);
    return true;
  }
  return data !== false;
}

/** {total, n}: n = messages of the Paris day. Null if unreadable. */
export async function lireCompteurs(admin: SupabaseClient, userID: string): Promise<Compteurs | null> {
  const { data, error } = await admin.rpc("louane_read_counters", { p_user_id: userID });
  if (error) {
    console.error("[Compteurs] illisibles :", error.message);
    return null;
  }
  const row = (Array.isArray(data) ? data[0] : data) as { total?: number; day_count?: number } | null;
  return { total: Number(row?.total) || 0, n: Number(row?.day_count) || 0 };
}

export async function incrementerCompteurs(admin: SupabaseClient, userID: string): Promise<void> {
  const { error } = await admin.rpc("louane_increment_counters", { p_user_id: userID });
  if (error) console.error("[Compteurs] incrément échoué :", error.message);
}

/** Was the 3114 message shown to this account in the last 24 h? */
export async function alerteRecente(admin: SupabaseClient, userID: string): Promise<boolean> {
  const { data, error } = await admin.from("louane_safety_alerts").select("alerted_at")
    .eq("user_id", userID).maybeSingle();
  if (error) {
    console.error("[Sécurité] mémoire d'alerte illisible :", error.message);
    return false;
  }
  const ms = data?.alerted_at ? Date.parse(String(data.alerted_at)) : 0;
  return Date.now() - (Number.isFinite(ms) ? ms : 0) < ALERTE_MEMOIRE_MS;
}

export async function marquerAlerte(admin: SupabaseClient, userID: string): Promise<void> {
  const { error } = await admin.from("louane_safety_alerts")
    .upsert({ user_id: userID, alerted_at: new Date().toISOString() }, { onConflict: "user_id" });
  if (error) console.error("[Sécurité] mémoire d'alerte inécrivable :", error.message);
}

/** One anonymous stats row per message (never text, never name, never user id). */
export async function enregistrerStatsLouane(admin: SupabaseClient, donnees: Record<string, unknown>): Promise<void> {
  const { niveau, categorie, paywall, plafond, ...details } = donnees;
  const { error } = await admin.from("louane_stats").insert({
    niveau: typeof niveau === "number" ? niveau : null,
    categorie: typeof categorie === "string" ? categorie : null,
    paywall: paywall === true,
    plafond: plafond === true,
    details,
  });
  if (error) console.error("[Vigie] écriture stats Louane échouée (ignorée) :", error.message);
}
