import type { PlanFunnelRow } from "../lib/api";
import { formatNumber, formatPercent } from "../lib/format";
import { planLabel } from "../lib/labels";

type PlanTotals = { plan: string; started: number; week2: number; week3: number; abandoned: number; completedDays: number | null };

/** Sums the statuses of each plan (plan_funnel has one row per plan and status). */
export function planTotals(rows: PlanFunnelRow[]): PlanTotals[] {
  const byPlan = new Map<string, PlanTotals & { weighted: number; weight: number }>();
  for (const row of rows) {
    const t = byPlan.get(row.plan_id) ?? { plan: row.plan_id, started: 0, week2: 0, week3: 0, abandoned: 0, completedDays: null, weighted: 0, weight: 0 };
    t.started += row.programs;
    t.week2 += row.reached_week_2;
    t.week3 += row.reached_week_3;
    if (row.status === "abandoned") t.abandoned += row.programs;
    if (row.avg_completed_days != null) {
      t.weighted += row.avg_completed_days * row.programs;
      t.weight += row.programs;
    }
    byPlan.set(row.plan_id, t);
  }
  return [...byPlan.values()]
    .map(({ weighted, weight, ...t }) => ({ ...t, completedDays: weight ? weighted / weight : null }))
    .sort((a, b) => b.started - a.started);
}

/**
 * Retention by goal plan: of the plans started, the share that reached 7 and
 * 14 completed steps, and the share abandoned for another plan.
 */
export function PlanRetention({ rows }: { rows: PlanFunnelRow[] }) {
  const plans = planTotals(rows);
  if (!plans.length) return <p className="empty">Aucun plan commencé pour l’instant.</p>;
  return (
    <div className="funnel-wrap">
      <table className="funnel plans">
        <thead>
          <tr>
            <th scope="col">Plan</th>
            <th scope="col" className="num">
              Commencés
            </th>
            <th scope="col" className="bar-col">
              7 étapes faites
            </th>
            <th scope="col" className="bar-col">
              14 étapes faites
            </th>
            <th scope="col" className="num">
              Étapes faites (moy.)
            </th>
            <th scope="col" className="num">
              Abandonnés
            </th>
          </tr>
        </thead>
        <tbody>
          {plans.map((p) => (
            <tr key={p.plan}>
              <th scope="row">{planLabel(p.plan)}</th>
              <td className="num">{formatNumber(p.started)}</td>
              <td className="bar-col">
                <Share part={p.week2} total={p.started} label={`${planLabel(p.plan)} : 7 étapes faites`} />
              </td>
              <td className="bar-col">
                <Share part={p.week3} total={p.started} label={`${planLabel(p.plan)} : 14 étapes faites`} />
              </td>
              <td className="num">{p.completedDays == null ? "—" : (Math.round(p.completedDays * 10) / 10).toLocaleString("fr-FR")}</td>
              <td className="num">
                {formatNumber(p.abandoned)} <span className="muted">· {formatPercent(p.abandoned, p.started)}</span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Share({ part, total, label }: { part: number; total: number; label: string }) {
  const share = total > 0 ? part / total : 0;
  return (
    <span className="plan-share" title={`${label} : ${formatNumber(part)} sur ${formatNumber(total)} (${formatPercent(part, total)})`}>
      <span className="bar-track">
        <span className="bar-fill" style={{ width: `${Math.max(0, Math.min(1, share)) * 100}%` }} />
      </span>
      <span className="plan-share-value">{formatPercent(part, total)}</span>
    </span>
  );
}
