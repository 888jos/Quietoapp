import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { demoSource } from "./demo";

// Shapes returned by the `dashboard_*` SQL functions
// (supabase/migrations/20261006200000_analytics_dashboard.sql).

export type Overview = {
  new_users: number;
  onboarding_started: number;
  onboarding_completed: number;
  onboarding_active_seconds_median: number | null;
  onboarding_duration_seconds_median: number | null;
  paywall_viewers: number;
  trial_starters: number;
  dau: number;
  wau: number;
  mau: number;
  practice_entries: number;
  practice_users: number;
  practice_minutes: number;
  store: {
    trials: number;
    direct_purchases: number;
    trial_conversions: number;
    renewals: number;
    cancellations: number;
    billing_issues: number;
    proceeds: number;
  };
  access: {
    trialing: number;
    paying: number;
    promotional: number;
    not_renewing: number;
    enterprise: number;
  };
};

export type DailyRow = {
  day: string;
  new_users: number;
  active_users: number;
  onboarding_completed: number;
  trial_starters: number;
  practice_minutes: number;
};

export type OnboardingStepRow = {
  step: string;
  act: number | null;
  position: number;
  users: number;
  median_seconds: number | null;
};

export type Onboarding = {
  started: number;
  completed: number;
  steps: OnboardingStepRow[];
};

export type Retention = {
  cohorts: { week: string; size: number; weeks: number[] }[];
  day_n: { day: number; eligible: number; retained: number }[];
};

export type Usage = {
  by_kind: { kind: string; entries: number; users: number; minutes: number }[];
  top_content: { content: string; title?: string | null; kind: string; entries: number; users: number }[];
  events: { event: string; count: number; users: number }[];
};

export type Range = { from: Date; to: Date };

export interface DataSource {
  readonly isDemo: boolean;
  overview(range: Range): Promise<Overview>;
  daily(range: Range): Promise<DailyRow[]>;
  onboarding(range: Range): Promise<Onboarding>;
  retention(weeks: number): Promise<Retention>;
  usage(range: Range): Promise<Usage>;
}

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;

export const supabase: SupabaseClient | null =
  url && key && !url.includes("xxxx") ? createClient(url, key) : null;

const numeric = <T>(value: T): T => JSON.parse(JSON.stringify(value), (_, v) => (typeof v === "string" && /^-?\d+(\.\d+)?$/.test(v) ? Number(v) : v));

async function rpc<T>(client: SupabaseClient, fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await client.rpc(fn, args);
  if (error) throw new Error(error.message === "dashboard_access_denied" ? "Accès refusé : cet email n’est pas autorisé." : error.message);
  return numeric(data as T);
}

const span = (range: Range) => ({ p_from: range.from.toISOString(), p_to: range.to.toISOString() });

function supabaseSource(client: SupabaseClient): DataSource {
  return {
    isDemo: false,
    overview: (range) => rpc(client, "dashboard_overview", span(range)),
    daily: (range) => rpc(client, "dashboard_daily", { ...span(range), p_tz: "Europe/Paris" }),
    onboarding: (range) => rpc(client, "dashboard_onboarding", span(range)),
    retention: (weeks) => rpc(client, "dashboard_retention", { p_weeks: weeks, p_tz: "Europe/Paris" }),
    usage: (range) => rpc(client, "dashboard_usage", span(range)),
  };
}

export const source: DataSource = supabase ? supabaseSource(supabase) : demoSource;
