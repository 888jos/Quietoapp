import { formatNumber } from "../lib/format";

type Item = { key: string; label: string; value: number; detail?: string };

/** Horizontal ranking: label, thin bar, value at the tip. */
export function BarList({ items, unit = "" }: { items: Item[]; unit?: string }) {
  const max = Math.max(1, ...items.map((i) => i.value));
  if (!items.length) return <p className="empty">Rien sur la période.</p>;
  return (
    <ul className="barlist">
      {items.map((item) => (
        <li key={item.key} title={item.detail}>
          <span className="barlist-label">{item.label}</span>
          <span className="barlist-bar">
            <span className="bar-fill" style={{ width: `${(item.value / max) * 100}%` }} />
          </span>
          <span className="barlist-value">
            {formatNumber(item.value)}
            {unit}
          </span>
        </li>
      ))}
    </ul>
  );
}
