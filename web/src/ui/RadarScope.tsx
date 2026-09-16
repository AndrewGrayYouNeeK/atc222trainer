import { useEffect, useRef } from "react";
import { Nav } from "../engine/nav";
import { altitudeLabel, isArrival, speedLabel, type Aircraft } from "../engine/types";
import type { GameEngine } from "../engine/engine";

const DISPLAY_RANGE = 42;
const SCOPE_FRACTION = 0.78;

type Palette = {
  traffic: string;
  selected: string;
  conflict: string;
  emergency: string;
  grid: string;
  hud: string;
  hudDim: string;
};

const standard: Palette = {
  traffic: "#33ff8c",
  selected: "#ffd94d",
  conflict: "#ff4d3d",
  emergency: "#ff3359",
  grid: "rgba(51, 217, 140, 0.22)",
  hud: "#b3f2cc",
  hudDim: "#73b38c",
};

function screenPoint(nm: { x: number; y: number }, center: { x: number; y: number }, scale: number) {
  return { x: center.x + nm.x * scale, y: center.y - nm.y * scale };
}

export function RadarScope({ engine }: { engine: GameEngine }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const drag = useRef<{ id: string | null; heading: number | null; point: { x: number; y: number } | null }>({
    id: null,
    heading: null,
    point: null,
  });

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    let frame = 0;

    const draw = (ts: number) => {
      frame = requestAnimationFrame(draw);
      const rect = canvas.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const width = Math.max(1, Math.floor(rect.width * dpr));
      const height = Math.max(1, Math.floor(rect.height * dpr));
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, rect.width, rect.height);

      const center = { x: rect.width / 2, y: rect.height / 2 };
      const radius = (Math.min(rect.width, rect.height) / 2) * SCOPE_FRACTION;
      const scale = radius / DISPLAY_RANGE;
      const sweep = ((ts / 1000) * 60) % 360;
      paint(ctx, engine, center, radius, scale, sweep, drag.current, standard);
    };
    frame = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(frame);
  }, [engine]);

  const eventPoint = (e: React.PointerEvent) => {
    const canvas = canvasRef.current!;
    const rect = canvas.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  };

  const layout = () => {
    const canvas = canvasRef.current!;
    const rect = canvas.getBoundingClientRect();
    const center = { x: rect.width / 2, y: rect.height / 2 };
    const radius = (Math.min(rect.width, rect.height) / 2) * SCOPE_FRACTION;
    return { center, scale: radius / DISPLAY_RANGE };
  };

  const nearest = (point: { x: number; y: number }, tolerance = 46) => {
    const { center, scale } = layout();
    let best: { id: string; dist: number } | null = null;
    for (const ac of engine.aircraft) {
      const p = screenPoint(ac.position, center, scale);
      const d = Math.hypot(p.x - point.x, p.y - point.y);
      if (!best || d < best.dist) best = { id: ac.id, dist: d };
    }
    return best && best.dist <= tolerance ? best.id : null;
  };

  return (
    <div className="scope-wrap">
      <canvas
        ref={canvasRef}
        onPointerDown={(e) => {
          (e.target as HTMLCanvasElement).setPointerCapture(e.pointerId);
          const point = eventPoint(e);
          const id = nearest(point, 60);
          if (id) {
            drag.current = { id, heading: null, point };
            engine.select(id);
          }
        }}
        onPointerMove={(e) => {
          if (!drag.current.id) return;
          const ac = engine.aircraft.find((a) => a.id === drag.current.id);
          if (!ac) return;
          const { center, scale } = layout();
          const from = screenPoint(ac.position, center, scale);
          const point = eventPoint(e);
          const dx = point.x - from.x;
          const dy = point.y - from.y;
          if (Math.hypot(dx, dy) > 18) {
            drag.current.heading = Nav.normalize((Math.atan2(dx, -dy) * 180) / Math.PI);
            drag.current.point = point;
          }
        }}
        onPointerUp={() => {
          if (drag.current.heading != null) engine.setHeading(drag.current.heading);
          drag.current = { id: null, heading: null, point: null };
        }}
      />
    </div>
  );
}

function paint(
  ctx: CanvasRenderingContext2D,
  engine: GameEngine,
  center: { x: number; y: number },
  radius: number,
  scale: number,
  sweep: number,
  drag: { id: string | null; heading: number | null; point: { x: number; y: number } | null },
  palette: Palette,
) {
  ctx.save();
  drawGrid(ctx, center, radius, palette);
  drawSweep(ctx, center, radius, sweep, palette.traffic);
  drawRunway(ctx, engine, center, scale, palette);
  drawFixes(ctx, engine, center, scale, palette);
  for (const ac of engine.aircraft) drawAircraft(ctx, engine, ac, center, scale, palette);
  drawDrag(ctx, engine, center, scale, drag, palette);
  ctx.restore();
}

function drawGrid(ctx: CanvasRenderingContext2D, center: { x: number; y: number }, radius: number, palette: Palette) {
  ctx.strokeStyle = palette.grid;
  ctx.lineWidth = 1;
  for (let fraction = 0.25; fraction <= 1; fraction += 0.25) {
    const r = radius * fraction;
    ctx.beginPath();
    ctx.arc(center.x, center.y, r, 0, Math.PI * 2);
    ctx.stroke();
  }
  for (let deg = 0; deg < 360; deg += 30) {
    const rad = (deg * Math.PI) / 180;
    ctx.beginPath();
    ctx.strokeStyle = "rgba(51, 217, 140, 0.09)";
    ctx.moveTo(center.x, center.y);
    ctx.lineTo(center.x + Math.sin(rad) * radius, center.y - Math.cos(rad) * radius);
    ctx.stroke();
    ctx.fillStyle = palette.hudDim;
    ctx.font = "10px IBM Plex Mono, monospace";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(
      String(deg === 0 ? 36 : deg / 10).padStart(2, "0"),
      center.x + Math.sin(rad) * (radius - 14),
      center.y - Math.cos(rad) * (radius - 14),
    );
  }
}

function drawSweep(
  ctx: CanvasRenderingContext2D,
  center: { x: number; y: number },
  radius: number,
  angle: number,
  color: string,
) {
  for (let i = 0; i < 48; i++) {
    const a = ((angle - i) * Math.PI) / 180;
    ctx.strokeStyle = color;
    ctx.globalAlpha = (1 - i / 48) * 0.2;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(center.x, center.y);
    ctx.lineTo(center.x + Math.sin(a) * radius, center.y - Math.cos(a) * radius);
    ctx.stroke();
  }
  ctx.globalAlpha = 0.85;
  const a = (angle * Math.PI) / 180;
  ctx.beginPath();
  ctx.moveTo(center.x, center.y);
  ctx.lineTo(center.x + Math.sin(a) * radius, center.y - Math.cos(a) * radius);
  ctx.stroke();
  ctx.globalAlpha = 1;
}

function drawRunway(
  ctx: CanvasRenderingContext2D,
  engine: GameEngine,
  center: { x: number; y: number },
  scale: number,
  palette: Palette,
) {
  const rwy = engine.activeRunway;
  const dir = Nav.vector(rwy.heading);
  const halfLen = (rwy.length / 2) * scale;
  const t = screenPoint(rwy.threshold, center, scale);
  ctx.strokeStyle = palette.hud;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(t.x - dir.x * halfLen, t.y + dir.y * halfLen);
  ctx.lineTo(t.x + dir.x * halfLen, t.y - dir.y * halfLen);
  ctx.stroke();
  ctx.setLineDash([4, 6]);
  ctx.strokeStyle = palette.grid;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(t.x, t.y);
  ctx.lineTo(t.x - dir.x * 14 * scale, t.y + dir.y * 14 * scale);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.fillStyle = palette.hud;
  ctx.font = "bold 11px IBM Plex Mono, monospace";
  ctx.textAlign = "center";
  ctx.fillText(rwy.name, t.x, t.y - 12);
}

function drawFixes(
  ctx: CanvasRenderingContext2D,
  engine: GameEngine,
  center: { x: number; y: number },
  scale: number,
  palette: Palette,
) {
  for (const fix of engine.airport.fixes) {
    const p = screenPoint(fix.position, center, scale);
    ctx.strokeStyle = fix.isArrival ? palette.grid : palette.hudDim;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(p.x, p.y - 4);
    ctx.lineTo(p.x - 4, p.y + 4);
    ctx.lineTo(p.x + 4, p.y + 4);
    ctx.closePath();
    ctx.stroke();
    ctx.fillStyle = palette.hudDim;
    ctx.font = "10px IBM Plex Mono, monospace";
    ctx.textAlign = "center";
    ctx.fillText(fix.name, p.x, p.y + 16);
  }
}

function drawAircraft(
  ctx: CanvasRenderingContext2D,
  engine: GameEngine,
  ac: Aircraft,
  center: { x: number; y: number },
  scale: number,
  palette: Palette,
) {
  const p = screenPoint(ac.position, center, scale);
  const selected = ac.id === engine.selectedID;
  const tint = ac.emergency ? palette.emergency : ac.conflict ? palette.conflict : selected ? palette.selected : palette.traffic;

  ac.trail.forEach((t, i) => {
    const tp = screenPoint(t, center, scale);
    ctx.fillStyle = tint;
    ctx.globalAlpha = (i / Math.max(ac.trail.length, 1)) * 0.5;
    ctx.beginPath();
    ctx.arc(tp.x, tp.y, 1.2, 0, Math.PI * 2);
    ctx.fill();
  });
  ctx.globalAlpha = 1;

  const v = Nav.vector(ac.heading);
  const leadLen = 12 + ac.speed / 16;
  ctx.strokeStyle = tint;
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(p.x, p.y);
  ctx.lineTo(p.x + v.x * leadLen, p.y - v.y * leadLen);
  ctx.stroke();

  if (ac.conflict || ac.emergency) {
    ctx.beginPath();
    ctx.arc(p.x, p.y, 14, 0, Math.PI * 2);
    ctx.stroke();
  }

  ctx.fillStyle = tint;
  ctx.beginPath();
  ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
  ctx.fill();
  if (selected) {
    ctx.strokeRect(p.x - 9, p.y - 9, 18, 18);
  }

  ctx.fillStyle = selected ? palette.selected : palette.hud;
  ctx.font = `${selected ? "bold " : ""}11px IBM Plex Mono, monospace`;
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  const arrow = isArrival(ac) ? "▼" : "▲";
  ctx.fillText(ac.callsign, p.x + 13, p.y - 14);
  ctx.fillText(`${altitudeLabel(ac.altitude)} ${arrow} ${speedLabel(ac.speed)}`, p.x + 13, p.y - 2);
}

function drawDrag(
  ctx: CanvasRenderingContext2D,
  engine: GameEngine,
  center: { x: number; y: number },
  scale: number,
  drag: { id: string | null; heading: number | null; point: { x: number; y: number } | null },
  palette: Palette,
) {
  if (!drag.id || drag.heading == null || !drag.point) return;
  const ac = engine.aircraft.find((a) => a.id === drag.id);
  if (!ac) return;
  const from = screenPoint(ac.position, center, scale);
  ctx.setLineDash([6, 4]);
  ctx.strokeStyle = palette.selected;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(from.x, from.y);
  ctx.lineTo(drag.point.x, drag.point.y);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.fillStyle = palette.selected;
  ctx.font = "bold 13px IBM Plex Mono, monospace";
  ctx.textAlign = "center";
  ctx.fillText(`${String(Math.round(drag.heading)).padStart(3, "0")}°`, drag.point.x, drag.point.y - 18);
}
