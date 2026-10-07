import type { Retention } from "../lib/api";
import { formatDay, formatNumber } from "../lib/format";

/**
 * Weekly retention cohorts. Each cell is the share of the cohort active that
 * week; its fill is one hue mixed into the surface, darker = more retained.
 */
export function CohortTable({ data }: { data: Retention }) {
  const columns = Math.max(0, ...data.cohorts.map((c) => c.weeks.length));
  if (!data.cohorts.length) return <p className="empty">Pas encore de cohorte sur la période.</p>;
  return (
    <div className="cohort-wrap">
      <table className="cohorts">
        <thead>
          <tr>
            <th scope="col">Semaine d’inscription</th>
            <th scope="col" className="num">
              Personnes
            </th>
            {Array.from({ length: columns }, (_, w) => (
              <th key={w} scope="col" className="num">
                {w === 0 ? "S0" : `S+${w}`}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.cohorts.map((cohort) => (
            <tr key={cohort.week}>
              <th scope="row">{formatDay(cohort.week, { day: "numeric", month: "short" })}</th>
              <td className="num">{formatNumber(cohort.size)}</td>
              {Array.from({ length: columns }, (_, w) => {
                const users = cohort.weeks[w];
                if (users == null) return <td key={w} className="cell-empty" />;
                const rate = cohort.size ? users / cohort.size : 0;
                const pct = Math.round(rate * 100);
                // 12% floor keeps a 0 % cell visible; strong fills switch to light ink.
                const mix = 12 + Math.round(rate * 78);
                return (
                  <td
                    key={w}
                    className={`cell ${mix > 55 ? "cell-strong" : ""}`}
                    style={{ background: `color-mix(in oklab, var(--series-1) ${mix}%, var(--surface-1))` }}
                    title={`${formatNumber(users)} personnes sur ${formatNumber(cohort.size)}`}
                  >
                    {pct} %
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
