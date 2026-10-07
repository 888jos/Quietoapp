import type { Onboarding } from "../lib/api";
import { formatDuration, formatNumber, formatPercent } from "../lib/format";
import { ACTS, CONDITIONAL_STEPS, stepLabel } from "../lib/labels";

/**
 * Onboarding funnel as a table: one row per screen, a bar for the share of
 * starters who reached it, and how many left on that screen (reached it but
 * not the next one). The three screens with the highest abandon rate are flagged.
 */
export function Funnel({ data }: { data: Onboarding }) {
  const start = data.started || data.steps[0]?.users || 0;
  const rows = data.steps.map((step, i) => {
    // Compared with the next screen everyone sees: a conditional screen shown
    // to a few people is not an abandon on the one before it.
    const following = data.steps.slice(i + 1).find((s) => !CONDITIONAL_STEPS.has(s.step));
    const next = following ? following.users : data.completed;
    const lost = Math.max(0, step.users - next);
    return { ...step, lost, lossRate: step.users > 0 ? lost / step.users : 0 };
  });
  const worst = new Set(
    [...rows]
      .filter((r) => r.lost > 0)
      .sort((a, b) => b.lossRate - a.lossRate)
      .slice(0, 3)
      .map((r) => r.step),
  );

  if (!rows.length) return <p className="empty">Aucun onboarding commencé sur la période.</p>;

  return (
    <div className="funnel-wrap">
      <table className="funnel">
        <thead>
          <tr>
            <th scope="col">Écran</th>
            <th scope="col" className="bar-col">
              Atteint par
            </th>
            <th scope="col" className="num">
              Personnes
            </th>
            <th scope="col" className="num">
              Abandon sur cet écran
            </th>
            <th scope="col" className="num">
              Temps médian
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => {
            const newAct = row.act != null && row.act !== rows[i - 1]?.act;
            return (
              <FunnelRow
                key={row.step}
                act={newAct && row.act != null ? `Acte ${row.act} · ${ACTS[row.act] ?? ""}` : null}
                label={stepLabel(row.step)}
                users={row.users}
                share={start ? row.users / start : 0}
                lost={row.lost}
                lossRate={row.lossRate}
                seconds={row.median_seconds}
                flagged={worst.has(row.step)}
              />
            );
          })}
          <tr className="funnel-total">
            <th scope="row">Onboarding terminé</th>
            <td className="bar-col">
              <Bar share={start ? data.completed / start : 0} />
            </td>
            <td className="num">
              {formatNumber(data.completed)} <span className="muted">· {formatPercent(data.completed, start)}</span>
            </td>
            <td className="num">—</td>
            <td className="num">—</td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}

function FunnelRow(props: {
  act: string | null;
  label: string;
  users: number;
  share: number;
  lost: number;
  lossRate: number;
  seconds: number | null;
  flagged: boolean;
}) {
  return (
    <>
      {props.act && (
        <tr className="funnel-act">
          <th colSpan={5} scope="rowgroup">
            {props.act}
          </th>
        </tr>
      )}
      <tr className={props.flagged ? "flagged" : undefined}>
        <th scope="row">
          {props.label}
          {props.flagged && (
            <span className="badge-warning">
              <span aria-hidden="true">⚠</span> Fort drop-off
            </span>
          )}
        </th>
        <td className="bar-col">
          <Bar share={props.share} />
        </td>
        <td className="num">
          {formatNumber(props.users)} <span className="muted">· {(Math.round(props.share * 1000) / 10).toLocaleString("fr-FR")} %</span>
        </td>
        <td className="num">{props.lost ? `−${formatNumber(props.lost)} (${(Math.round(props.lossRate * 1000) / 10).toLocaleString("fr-FR")} %)` : "—"}</td>
        <td className="num">{formatDuration(props.seconds)}</td>
      </tr>
    </>
  );
}

function Bar({ share }: { share: number }) {
  return (
    <span className="bar-track" title={`${(Math.round(share * 1000) / 10).toLocaleString("fr-FR")} % des personnes qui ont commencé`}>
      <span className="bar-fill" style={{ width: `${Math.max(0, Math.min(1, share)) * 100}%` }} />
    </span>
  );
}
