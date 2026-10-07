import { useState } from "react";
import { CohortTable } from "../components/CohortTable";
import { StatTile } from "../components/StatTile";
import { source } from "../lib/api";
import { formatNumber, formatPercent } from "../lib/format";
import { useData } from "../lib/useData";
import { Section, Status } from "./Section";

export function RetentionPage() {
  const [weeks, setWeeks] = useState(8);
  const retention = useData(() => source.retention(weeks), [weeks]);
  const r = retention.data;

  return (
    <>
      <Status loadable={retention} />
      {r && (
        <>
          <Section title="Rétention à J+N" note="Part des inscrits des 90 derniers jours revenus exactement ce jour-là (n’importe quelle activité).">
            <div className="tiles">
              {r.day_n.map((d) => (
                <StatTile key={d.day} hero={d.day === 7} label={`Rétention J${d.day}`} value={formatPercent(d.retained, d.eligible)} hint={`${formatNumber(d.retained)} sur ${formatNumber(d.eligible)} inscrits`} />
              ))}
            </div>
          </Section>
          <Section title="Cohortes hebdomadaires" note="Chaque ligne : les inscrits d’une semaine. Chaque colonne : la part encore active N semaines après.">
            <div className="filters" role="group" aria-label="Nombre de semaines">
              {[4, 8, 12].map((n) => (
                <button key={n} className={`chip${weeks === n ? " active" : ""}`} aria-pressed={weeks === n} onClick={() => setWeeks(n)}>
                  {n} semaines
                </button>
              ))}
            </div>
            <CohortTable data={r} />
          </Section>
        </>
      )}
    </>
  );
}
