import { change } from "../lib/format";

type Props = {
  label: string;
  value: string;
  hint?: string;
  current?: number;
  previous?: number;
  /** False when a rise is bad news (cancellations, billing issues). */
  upIsGood?: boolean;
  hero?: boolean;
};

export function StatTile({ label, value, hint, current, previous, upIsGood = true, hero }: Props) {
  const delta = current != null && previous != null ? change(current, previous) : null;
  const direction = delta == null || Math.abs(delta) < 0.005 ? "flat" : delta > 0 ? "up" : "down";
  const good = direction === "flat" ? "neutral" : (direction === "up") === upIsGood ? "good" : "bad";
  return (
    <div className={`tile${hero ? " tile-hero" : ""}`}>
      <span className="tile-label">{label}</span>
      <span className="tile-value">{value}</span>
      {delta != null && (
        <span className={`tile-delta ${good}`}>
          <span aria-hidden="true">{direction === "up" ? "▲" : direction === "down" ? "▼" : "■"}</span>{" "}
          {delta > 0 ? "+" : ""}
          {(Math.round(delta * 1000) / 10).toLocaleString("fr-FR")} % vs période précédente
        </span>
      )}
      {hint && <span className="tile-hint">{hint}</span>}
    </div>
  );
}
