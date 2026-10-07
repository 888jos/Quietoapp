import type { DailyRow, DataSource, Onboarding, Overview, Range, Retention, Usage } from "./api";
import { ONBOARDING_STEPS } from "./labels";

// Generated data with the same shapes as the SQL functions, used when no
// Supabase project is configured. Deterministic so screenshots are stable.

function seeded(seed: number) {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) % 4294967296;
    return s / 4294967296;
  };
}

const DAY = 86_400_000;
const days = (range: Range) => Math.max(1, Math.round((range.to.getTime() - range.from.getTime()) / DAY));
const dayKey = (d: Date) => d.toISOString().slice(0, 10);

function daily(range: Range): DailyRow[] {
  const rows: DailyRow[] = [];
  for (let t = range.from.getTime(); t < range.to.getTime(); t += DAY) {
    const date = new Date(t);
    const n = Math.floor(t / DAY);
    const rand = seeded(n * 7919 + 13);
    rand();
    const r = rand();
    const weekend = date.getUTCDay() % 6 === 0 ? 1.25 : 1;
    const growth = 1 + (n % 365) / 900;
    const newUsers = Math.round((38 + r * 22) * weekend * growth);
    rows.push({
      day: dayKey(date),
      new_users: newUsers,
      active_users: Math.round((410 + r * 90) * growth * weekend),
      onboarding_completed: Math.round(newUsers * (0.41 + r * 0.08)),
      trial_starters: Math.round(newUsers * (0.19 + r * 0.05)),
      practice_minutes: Math.round((2600 + r * 700) * growth * weekend),
    });
  }
  return rows;
}

function sum(rows: DailyRow[], key: keyof Omit<DailyRow, "day">) {
  return rows.reduce((total, row) => total + row[key], 0);
}

function overview(range: Range): Overview {
  const rows = daily(range);
  const r = seeded(range.to.getTime() / DAY + days(range))();
  const started = sum(rows, "new_users");
  const completed = sum(rows, "onboarding_completed");
  const trials = sum(rows, "trial_starters");
  return {
    new_users: started,
    onboarding_started: started,
    onboarding_completed: completed,
    onboarding_active_seconds_median: 262 + Math.round(r * 30),
    onboarding_duration_seconds_median: 341 + Math.round(r * 50),
    paywall_viewers: Math.round(completed * 1.08),
    trial_starters: trials,
    dau: rows.at(-1)?.active_users ?? 0,
    wau: Math.round((rows.at(-1)?.active_users ?? 0) * 2.6),
    mau: Math.round((rows.at(-1)?.active_users ?? 0) * 5.1),
    practice_entries: Math.round(sum(rows, "practice_minutes") / 7.4),
    practice_users: Math.round((rows.at(-1)?.active_users ?? 0) * 3.2),
    practice_minutes: sum(rows, "practice_minutes"),
    store: {
      trials,
      direct_purchases: Math.round(trials * 0.06),
      trial_conversions: Math.round(trials * 0.44),
      renewals: Math.round(trials * 0.9),
      cancellations: Math.round(trials * 0.31),
      billing_issues: Math.round(trials * 0.03),
      proceeds: Math.round(trials * 0.44 * 34.99 * 0.85 + trials * 0.46 * 4.99 * 0.85),
    },
    access: { trialing: 312, paying: 1846, promotional: 14, not_renewing: 205, enterprise: 63 },
  };
}

function onboarding(range: Range): Onboarding {
  const rand = seeded(days(range) * 7);
  const started = sum(daily(range), "new_users");
  const harder: Record<string, number> = { firstName: 0.06, safety: 0.05, account: 0.09, health: 0.05, paywall: 0.18, trialTimeline: 0.07 };
  let remaining = started;
  const steps = ONBOARDING_STEPS.filter((s) => !["crisisSupport", "relaunch"].includes(s.id)).map((s, i) => {
    const row = { step: s.id, act: s.act, position: i + 1, users: Math.round(remaining), median_seconds: Math.round(4 + rand() * 14 + (s.id === "breathing" ? 60 : 0) + (s.id === "building" ? 4 : 0)) };
    remaining *= 1 - (harder[s.id] ?? 0.004 + rand() * 0.012);
    return row;
  });
  return { started, completed: Math.round(remaining), steps };
}

function retention(weeks: number): Retention {
  const rand = seeded(weeks);
  const monday = new Date();
  monday.setUTCHours(0, 0, 0, 0);
  monday.setUTCDate(monday.getUTCDate() - ((monday.getUTCDay() + 6) % 7));
  const cohorts = Array.from({ length: weeks }, (_, i) => {
    const week = new Date(monday.getTime() - (weeks - 1 - i) * 7 * DAY);
    const size = Math.round(260 + rand() * 90);
    const elapsed = weeks - 1 - i;
    const curve = [1, 0.46, 0.36, 0.31, 0.28, 0.26, 0.245, 0.235, 0.23, 0.225, 0.22, 0.215];
    return { week: dayKey(week), size, weeks: Array.from({ length: elapsed + 1 }, (_, w) => (w === 0 ? size : Math.round(size * (curve[w] ?? 0.21) * (0.94 + rand() * 0.1)))) };
  });
  return {
    cohorts,
    day_n: [
      { day: 1, eligible: 2140, retained: 1006 },
      { day: 7, eligible: 1890, retained: 548 },
      { day: 30, eligible: 1210, retained: 266 },
    ],
  };
}

function usage(range: Range): Usage {
  const scale = days(range) / 30;
  const s = (n: number) => Math.round(n * scale);
  return {
    by_kind: [
      { kind: "meditation", entries: s(9120), users: s(2210), minutes: s(71400) },
      { kind: "breathing", entries: s(5230), users: s(1680), minutes: s(14100) },
      { kind: "check_in", entries: s(4410), users: s(1950), minutes: 0 },
      { kind: "sound", entries: s(2380), users: s(870), minutes: s(41200) },
    ],
    top_content: [
      { content: "decouverte_1", kind: "meditation", entries: s(1890), users: s(1420) },
      { content: "sommeil_lacher_prise", kind: "meditation", entries: s(1410), users: s(902) },
      { content: "coherence_cardiaque", kind: "breathing", entries: s(1302), users: s(774) },
      { content: "express_8", kind: "meditation", entries: s(988), users: s(690) },
      { content: "pluie_douce", kind: "sound", entries: s(861), users: s(402) },
      { content: "pensees_nuages", kind: "meditation", entries: s(734), users: s(511) },
      { content: "respiration_4_7_8", kind: "breathing", entries: s(655), users: s(433) },
    ],
    events: [
      { event: "onboarding_step", count: s(48210), users: s(1490) },
      { event: "session_played", count: s(12930), users: s(2310) },
      { event: "practice_recorded", count: s(11210), users: s(2260) },
      { event: "check_in", count: s(4410), users: s(1950) },
      { event: "streak_day", count: s(3980), users: s(1720) },
      { event: "ambience_played", count: s(2380), users: s(870) },
      { event: "onboarding_started", count: s(1490), users: s(1490) },
      { event: "badge_unlocked", count: s(1320), users: s(940) },
      { event: "paywall_viewed", count: s(1180), users: s(702) },
      { event: "onboarding_completed", count: s(655), users: s(655) },
      { event: "louane_opened", count: s(610), users: s(388) },
      { event: "trial_started", count: s(301), users: s(301) },
    ],
  };
}

const later = <T,>(value: T) => new Promise<T>((resolve) => setTimeout(() => resolve(value), 120));

export const demoSource: DataSource = {
  isDemo: true,
  overview: (range) => later(overview(range)),
  daily: (range) => later(daily(range)),
  onboarding: (range) => later(onboarding(range)),
  retention: (weeks) => later(retention(weeks)),
  usage: (range) => later(usage(range)),
};
