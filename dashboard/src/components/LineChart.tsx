import { useId, useMemo, useState } from "react";
import { formatDay, formatNumber, niceTicks } from "../lib/format";
import { useWidth } from "./useWidth";

type Point = { x: string; y: number };

/** One daily series: 2px line, 10% wash, end dot, crosshair + tooltip on hover. */
export function LineChart({ title, points, unit = "", height = 180 }: { title: string; points: Point[]; unit?: string; height?: number }) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);
  const clip = useId();
  const pad = { top: 12, right: 14, bottom: 26, left: 44 };
  const w = Math.max(width - pad.left - pad.right, 10);
  const h = height - pad.top - pad.bottom;
  const max = Math.max(...points.map((p) => p.y), 0);
  const ticks = niceTicks(max);
  const top = ticks[ticks.length - 1] || 1;
  const x = (i: number) => (points.length < 2 ? w / 2 : (i / (points.length - 1)) * w);
  const y = (v: number) => h - (v / top) * h;

  const { line, area } = useMemo(() => {
    const coords = points.map((p, i) => `${x(i).toFixed(1)},${y(p.y).toFixed(1)}`);
    return {
      line: coords.length ? `M${coords.join("L")}` : "",
      area: coords.length ? `M${x(0)},${h}L${coords.join("L")}L${x(points.length - 1)},${h}Z` : "",
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [points, w, h, top]);

  const labelEvery = Math.max(1, Math.ceil(points.length / Math.max(2, Math.floor(w / 70))));
  const last = points.length - 1;
  const active = hover ?? null;

  function onMove(event: React.PointerEvent<SVGRectElement>) {
    const box = event.currentTarget.getBoundingClientRect();
    const ratio = (event.clientX - box.left) / box.width;
    setHover(Math.min(last, Math.max(0, Math.round(ratio * last))));
  }

  return (
    <figure className="chart">
      <figcaption className="chart-title">{title}</figcaption>
      <div ref={ref} className="chart-plot" style={{ height }}>
        {width > 0 && points.length > 0 && (
          <svg width={width} height={height} role="img" aria-label={`${title}, ${points.length} jours`}>
            <defs>
              <clipPath id={clip}>
                <rect x={0} y={-4} width={w + 4} height={h + 8} />
              </clipPath>
            </defs>
            <g transform={`translate(${pad.left},${pad.top})`}>
              {ticks.map((t) => (
                <g key={t}>
                  <line className="grid" x1={0} x2={w} y1={y(t)} y2={y(t)} />
                  <text className="tick" x={-8} y={y(t)} dy="0.32em" textAnchor="end">
                    {formatNumber(t)}
                  </text>
                </g>
              ))}
              {points.map((p, i) =>
                i % labelEvery === 0 ? (
                  <text key={p.x} className="tick" x={x(i)} y={h + 18} textAnchor={i === 0 ? "start" : "middle"}>
                    {formatDay(p.x)}
                  </text>
                ) : null,
              )}
              <g clipPath={`url(#${clip})`}>
                <path d={area} className="series-area" />
                <path d={line} className="series-line" />
              </g>
              {active !== null && <line className="crosshair" x1={x(active)} x2={x(active)} y1={0} y2={h} />}
              <circle className="series-dot" cx={x(active ?? last)} cy={y(points[active ?? last].y)} r={4} />
              <rect
                x={0}
                y={0}
                width={w}
                height={h}
                fill="transparent"
                onPointerMove={onMove}
                onPointerLeave={() => setHover(null)}
              />
            </g>
          </svg>
        )}
        {active !== null && (
          <div className="tooltip" style={{ left: Math.min(pad.left + x(active) + 12, width - 150), top: pad.top + y(points[active].y) - 8 }}>
            <span className="tooltip-label">{formatDay(points[active].x, { weekday: "short", day: "numeric", month: "long" })}</span>
            <span className="tooltip-value">
              {formatNumber(points[active].y)}
              {unit}
            </span>
          </div>
        )}
      </div>
      <details className="table-view">
        <summary>Voir les valeurs</summary>
        <table>
          <tbody>
            {points.map((p) => (
              <tr key={p.x}>
                <td>{formatDay(p.x, { weekday: "short", day: "numeric", month: "short" })}</td>
                <td className="num">{formatNumber(p.y)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </details>
    </figure>
  );
}
