import { LineChart } from "../components/LineChart";
import { StatTile } from "../components/StatTile";
import { source, type Range } from "../lib/api";
import { formatDuration, formatMoney, formatNumber, formatPercent } from "../lib/format";
import { useData } from "../lib/useData";
import { Section, Status } from "./Section";

export function Overview({ range, previous }: { range: Range; previous: Range }) {
  const key = [range.from.getTime(), range.to.getTime()];
  const now = useData(() => source.overview(range), key);
  const before = useData(() => source.overview(previous), key);
  const daily = useData(() => source.daily(range), key);
  const o = now.data;
  const p = before.data;

  return (
    <>
      <Status loadable={now} />
      {o && (
        <>
          <Section title="Abonnements aujourd’hui" note="État actuel, indépendant de la période.">
            <div className="tiles">
              <StatTile hero label="Abonnés payants" value={formatNumber(o.access.paying)} hint={`${formatNumber(o.access.not_renewing)} ne renouvelleront pas`} />
              <StatTile label="En essai gratuit" value={formatNumber(o.access.trialing)} />
              <StatTile label="Accès entreprise" value={formatNumber(o.access.enterprise)} />
              <StatTile label="Accès offerts" value={formatNumber(o.access.promotional)} />
            </div>
          </Section>

          <Section title="Acquisition et conversion">
            <div className="tiles">
              <StatTile label="Nouveaux utilisateurs" value={formatNumber(o.new_users)} current={o.new_users} previous={p?.new_users} />
              <StatTile
                label="Onboarding terminé"
                value={formatPercent(o.onboarding_completed, o.onboarding_started)}
                hint={`${formatNumber(o.onboarding_completed)} sur ${formatNumber(o.onboarding_started)} commencés`}
                current={o.onboarding_started ? o.onboarding_completed / o.onboarding_started : 0}
                previous={p && p.onboarding_started ? p.onboarding_completed / p.onboarding_started : undefined}
              />
              <StatTile
                label="Temps actif médian d’onboarding"
                value={formatDuration(o.onboarding_active_seconds_median)}
                hint={`Durée totale médiane : ${formatDuration(o.onboarding_duration_seconds_median)}`}
              />
              <StatTile
                label="Essais démarrés"
                value={formatNumber(o.trial_starters)}
                hint={`${formatPercent(o.trial_starters, o.onboarding_started)} des onboardings commencés`}
                current={o.trial_starters}
                previous={p?.trial_starters}
              />
            </div>
          </Section>

          <Section title="Revenus et abonnements" note="Webhooks Superwall, production uniquement. Montants nets d’Apple (proceeds), en USD.">
            <div className="tiles">
              <StatTile label="Revenu net" value={formatMoney(o.store.proceeds)} current={o.store.proceeds} previous={p?.store.proceeds} />
              <StatTile
                label="Essais convertis"
                value={formatNumber(o.store.trial_conversions)}
                hint={`${formatPercent(o.store.trial_conversions, o.store.trials)} des essais de la période`}
                current={o.store.trial_conversions}
                previous={p?.store.trial_conversions}
              />
              <StatTile label="Renouvellements" value={formatNumber(o.store.renewals)} current={o.store.renewals} previous={p?.store.renewals} />
              <StatTile
                label="Résiliations"
                value={formatNumber(o.store.cancellations)}
                hint={`${formatNumber(o.store.billing_issues)} problèmes de paiement`}
                current={o.store.cancellations}
                previous={p?.store.cancellations}
                upIsGood={false}
              />
            </div>
          </Section>

          <Section title="Engagement">
            <div className="tiles">
              <StatTile label="Actifs (30 derniers jours)" value={formatNumber(o.mau)} current={o.mau} previous={p?.mau} />
              <StatTile label="Actifs (7 derniers jours)" value={formatNumber(o.wau)} hint={`Stickiness DAU/MAU : ${formatPercent(o.dau, o.mau)}`} current={o.wau} previous={p?.wau} />
              <StatTile label="Minutes de pratique" value={formatNumber(o.practice_minutes)} current={o.practice_minutes} previous={p?.practice_minutes} />
              <StatTile
                label="Pratiques par pratiquant"
                value={o.practice_users ? (o.practice_entries / o.practice_users).toLocaleString("fr-FR", { maximumFractionDigits: 1 }) : "—"}
                hint={`${formatNumber(o.practice_users)} personnes ont pratiqué`}
              />
            </div>
          </Section>
        </>
      )}

      {daily.data && (
        <Section title="Jour par jour">
          <div className="charts">
            <LineChart title="Utilisateurs actifs" points={daily.data.map((d) => ({ x: d.day, y: d.active_users }))} />
            <LineChart title="Nouveaux utilisateurs" points={daily.data.map((d) => ({ x: d.day, y: d.new_users }))} />
            <LineChart title="Essais démarrés" points={daily.data.map((d) => ({ x: d.day, y: d.trial_starters }))} />
            <LineChart title="Minutes de pratique" unit=" min" points={daily.data.map((d) => ({ x: d.day, y: d.practice_minutes }))} />
          </div>
        </Section>
      )}
    </>
  );
}
