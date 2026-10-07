import { BarList } from "../components/BarList";
import { source, type Range } from "../lib/api";
import { formatNumber } from "../lib/format";
import { KIND_LABELS } from "../lib/labels";
import { useData } from "../lib/useData";
import { Section, Status } from "./Section";

const prettify = (id: string) => id.replace(/[_-]+/g, " ").replace(/^\w/, (c) => c.toUpperCase());

export function UsagePage({ range }: { range: Range }) {
  const usage = useData(() => source.usage(range), [range.from.getTime(), range.to.getTime()]);
  const u = usage.data;
  return (
    <>
      <Status loadable={usage} />
      {u && (
        <>
          <div className="grid-2">
            <Section title="Pratiques par type" note="Nombre de pratiques enregistrées.">
              <BarList
                items={u.by_kind.map((k) => ({
                  key: k.kind,
                  label: KIND_LABELS[k.kind] ?? k.kind,
                  value: k.entries,
                  detail: `${formatNumber(k.users)} personnes · ${formatNumber(k.minutes)} min`,
                }))}
              />
            </Section>
            <Section title="Contenus les plus pratiqués" note="Hors check-ins.">
              <BarList items={u.top_content.map((c) => ({ key: c.content, label: c.title ?? prettify(c.content), value: c.entries, detail: `${formatNumber(c.users)} personnes` }))} />
            </Section>
          </div>
          <Section title="Tous les événements" note="Ce que l’app iOS a envoyé pendant la période.">
            <div className="table-scroll">
              <table className="plain">
                <thead>
                  <tr>
                    <th scope="col">Événement</th>
                    <th scope="col" className="num">
                      Occurrences
                    </th>
                    <th scope="col" className="num">
                      Personnes
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {u.events.map((e) => (
                    <tr key={e.event}>
                      <th scope="row">
                        <code>{e.event}</code>
                      </th>
                      <td className="num">{formatNumber(e.count)}</td>
                      <td className="num">{formatNumber(e.users)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Section>
        </>
      )}
    </>
  );
}
