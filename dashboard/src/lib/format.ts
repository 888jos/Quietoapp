const fr = new Intl.NumberFormat("fr-FR");
const compact = new Intl.NumberFormat("fr-FR", { notation: "compact", maximumFractionDigits: 1 });

export const formatNumber = (n: number | null | undefined) => (n == null ? "—" : n >= 100_000 ? compact.format(n) : fr.format(Math.round(n)));

export const formatPercent = (part: number, total: number) => (total > 0 ? `${(Math.round((part / total) * 1000) / 10).toLocaleString("fr-FR")} %` : "—");

export const formatDuration = (seconds: number | null | undefined) => {
  if (seconds == null) return "—";
  const s = Math.round(seconds);
  if (s < 60) return `${s} s`;
  const m = Math.floor(s / 60);
  const rest = s % 60;
  return rest ? `${m} min ${String(rest).padStart(2, "0")}` : `${m} min`;
};

export const formatMoney = (n: number) => new Intl.NumberFormat("fr-FR", { style: "currency", currency: "USD", maximumFractionDigits: 0 }).format(n);

export const formatDay = (iso: string, options: Intl.DateTimeFormatOptions = { day: "numeric", month: "short" }) =>
  new Date(`${iso.slice(0, 10)}T12:00:00Z`).toLocaleDateString("fr-FR", options);

/** Signed change against the previous period, or null when there is nothing to compare. */
export const change = (current: number, previous: number) => (previous > 0 ? (current - previous) / previous : null);

/** Clean axis ticks (0, 250, 500…) covering `max`. */
export function niceTicks(max: number, count = 4): number[] {
  if (max <= 0) return [0];
  const raw = max / count;
  const magnitude = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 2.5, 5, 10].map((m) => m * magnitude).find((s) => s >= raw) ?? raw;
  const ticks: number[] = [];
  for (let v = 0; v <= max + step * 0.001; v += step) ticks.push(v);
  if (ticks[ticks.length - 1] < max) ticks.push(ticks[ticks.length - 1] + step);
  return ticks;
}
