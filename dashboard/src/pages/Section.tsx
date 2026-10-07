import type { ReactNode } from "react";
import type { Loadable } from "../lib/useData";

export function Section({ title, note, children }: { title: string; note?: string; children: ReactNode }) {
  return (
    <section className="section">
      <header className="section-head">
        <h2>{title}</h2>
        {note && <p className="section-note">{note}</p>}
      </header>
      {children}
    </section>
  );
}

export function Status({ loadable }: { loadable: Loadable<unknown> }) {
  if (loadable.error) return <p className="error" role="alert">{loadable.error}</p>;
  if (loadable.loading && !loadable.data) return <p className="loading">Chargement…</p>;
  return null;
}
