import { Funnel } from "../components/Funnel";
import { StatTile } from "../components/StatTile";
import { source, type Range } from "../lib/api";
import { formatDuration, formatNumber, formatPercent } from "../lib/format";
import { stepLabel } from "../lib/labels";
import { useData } from "../lib/useData";
import { Section, Status } from "./Section";

export function OnboardingPage({ range }: { range: Range }) {
  const key = [range.from.getTime(), range.to.getTime()];
  const funnel = useData(() => source.onboarding(range), key);
  const overview = useData(() => source.overview(range), key);
  const f = funnel.data;

  const slowest = f ? [...f.steps].filter((s) => s.median_seconds != null).sort((a, b) => (b.median_seconds ?? 0) - (a.median_seconds ?? 0))[0] : undefined;

  return (
    <>
      <Status loadable={funnel} />
      {f && (
        <>
          <Section title="Résumé" note="Personnes ayant commencé l’onboarding pendant la période.">
            <div className="tiles">
              <StatTile hero label="Taux de complétion" value={formatPercent(f.completed, f.started)} hint={`${formatNumber(f.completed)} sur ${formatNumber(f.started)}`} />
              <StatTile label="Temps actif médian" value={formatDuration(overview.data?.onboarding_active_seconds_median)} hint="Écrans laissés ouverts plus de 5 min non comptés" />
              <StatTile label="Durée totale médiane" value={formatDuration(overview.data?.onboarding_duration_seconds_median)} hint="Du premier écran à la fin, pauses comprises" />
              <StatTile label="Écran le plus long" value={slowest ? stepLabel(slowest.step) : "—"} hint={slowest ? `${formatDuration(slowest.median_seconds)} en médiane` : undefined} />
            </div>
          </Section>
          <Section title="Funnel écran par écran" note="Abandon = a vu l’écran mais pas le suivant. Les écrans conditionnels (Apple Santé, soutien de crise, relance) ne sont vus que par une partie des gens.">
            <Funnel data={f} />
          </Section>
        </>
      )}
    </>
  );
}
