import type { Session } from "@supabase/supabase-js";
import { useEffect, useMemo, useState } from "react";
import { source, supabase, type Range } from "./lib/api";
import { Login } from "./Login";
import { OnboardingPage } from "./pages/OnboardingPage";
import { Overview } from "./pages/Overview";
import { RetentionPage } from "./pages/RetentionPage";
import { UsagePage } from "./pages/UsagePage";

const TABS = [
  { id: "overview", label: "Vue d’ensemble" },
  { id: "onboarding", label: "Onboarding" },
  { id: "retention", label: "Rétention" },
  { id: "usage", label: "Usage" },
] as const;
type Tab = (typeof TABS)[number]["id"];

const PERIODS = [7, 30, 90] as const;
const DAY = 86_400_000;

function rangeFor(days: number): { range: Range; previous: Range } {
  // Whole days ending tonight, so the current day is included.
  const to = new Date();
  to.setHours(24, 0, 0, 0);
  const from = new Date(to.getTime() - days * DAY);
  return { range: { from, to }, previous: { from: new Date(from.getTime() - days * DAY), to: from } };
}

function readTab(): Tab {
  const hash = window.location.hash.slice(1);
  return (TABS.find((t) => t.id === hash)?.id ?? "overview") as Tab;
}

export function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [checked, setChecked] = useState(!supabase);
  const [allowed, setAllowed] = useState<boolean | null>(supabase ? null : true);

  useEffect(() => {
    if (!supabase) return;
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setChecked(true);
    });
    const { data } = supabase.auth.onAuthStateChange((_, next) => setSession(next));
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!supabase || !session) return;
    setAllowed(null);
    supabase.rpc("is_dashboard_admin").then(({ data, error }) => setAllowed(!error && data === true));
  }, [session]);

  if (!checked) return null;
  if (supabase && !session) return <Login />;
  if (allowed === null) return <p className="loading center">Vérification de l’accès…</p>;
  if (!allowed)
    return (
      <div className="login">
        <h1 className="brand">quieto</h1>
        <p>
          <strong>{session?.user.email}</strong> n’a pas accès au dashboard.
        </p>
        <p className="muted">Ajoute cet email dans la table <code>private.dashboard_admins</code> de Supabase.</p>
        <button className="link" onClick={() => supabase?.auth.signOut()}>
          Changer de compte
        </button>
      </div>
    );

  return <Dashboard email={session?.user.email} />;
}

function Dashboard({ email }: { email?: string }) {
  const [tab, setTab] = useState<Tab>(readTab);
  const [days, setDays] = useState<number>(() => {
    try {
      return Number(localStorage.getItem("quieto.dashboard.days")) || 30;
    } catch {
      return 30;
    }
  });
  const { range, previous } = useMemo(() => rangeFor(days), [days]);

  useEffect(() => {
    const onHash = () => setTab(readTab());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  function choosePeriod(value: number) {
    setDays(value);
    try {
      localStorage.setItem("quieto.dashboard.days", String(value));
    } catch {
      /* private mode: the choice just isn't remembered */
    }
  }

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand-row">
          <span className="brand">quieto</span>
          <span className="brand-sub">Analytics</span>
        </div>
        <nav className="tabs" aria-label="Sections">
          {TABS.map((t) => (
            <a key={t.id} href={`#${t.id}`} className={`tab${tab === t.id ? " active" : ""}`} aria-current={tab === t.id ? "page" : undefined}>
              {t.label}
            </a>
          ))}
        </nav>
        <div className="account">
          {email && <span className="muted">{email}</span>}
          {supabase && (
            <button className="link" onClick={() => supabase?.auth.signOut()}>
              Déconnexion
            </button>
          )}
        </div>
      </header>

      {source.isDemo && (
        <p className="demo-banner" role="status">
          <span aria-hidden="true">ⓘ</span> Données de démonstration. Renseigne <code>VITE_SUPABASE_URL</code> et <code>VITE_SUPABASE_PUBLISHABLE_KEY</code> dans <code>.env.local</code> pour voir les vrais chiffres.
        </p>
      )}

      <main className="content">
        <div className="page-head">
          <h1>{TABS.find((t) => t.id === tab)?.label}</h1>
          {tab !== "retention" && (
            <div className="filters" role="group" aria-label="Période">
              {PERIODS.map((p) => (
                <button key={p} className={`chip${days === p ? " active" : ""}`} aria-pressed={days === p} onClick={() => choosePeriod(p)}>
                  {p} jours
                </button>
              ))}
            </div>
          )}
        </div>
        {tab === "overview" && <Overview range={range} previous={previous} />}
        {tab === "onboarding" && <OnboardingPage range={range} />}
        {tab === "retention" && <RetentionPage />}
        {tab === "usage" && <UsagePage range={range} />}
      </main>
    </div>
  );
}
