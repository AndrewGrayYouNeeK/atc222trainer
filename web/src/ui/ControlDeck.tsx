import { Nav } from "../engine/nav";
import { isArrival } from "../engine/types";
import type { GameEngine } from "../engine/engine";

export function ControlDeck({
  engine,
  onTransmit,
}: {
  engine: GameEngine;
  onTransmit: (text: string) => void;
}) {
  const selected = engine.selected;
  const heading = selected ? (selected.targetHeading ?? selected.heading) : 0;
  const departureFix = selected?.intent.type === "departure" ? selected.intent.fix : null;

  return (
    <div className="deck">
      <TransmitBar onTransmit={onTransmit} />
      <div className="panel" style={{ padding: 14 }}>
        {selected ? (
          <>
            <div className="selected-strip">
              <span
                className="dot"
                style={{
                  background: selected.emergency ? "var(--emergency)" : selected.conflict ? "var(--conflict)" : "var(--selected)",
                }}
              />
              <strong style={{ color: "var(--selected)" }}>{selected.callsign}</strong>
              <span style={{ color: "var(--hud-dim)", fontSize: 10, fontWeight: 600 }}>
                {isArrival(selected) ? "ARRIVAL" : "DEPARTURE"}
              </span>
              <span style={{ marginLeft: "auto", color: "var(--hud-dim)", fontSize: 11 }}>{selected.lastInstruction}</span>
            </div>
            <div className="controls">
              <HeadingDial heading={heading} onChange={(h) => engine.setHeading(h)} />
              <div className="steppers">
                <Stepper
                  label="ALT"
                  value={`${Math.round(selected.targetAltitude ?? selected.altitude)}′`}
                  onDown={() => {
                    const current = selected.targetAltitude ?? selected.altitude;
                    const rounded = Math.round(current / 1000) * 1000;
                    engine.setAltitude(Math.min(Math.max(rounded - 1000, 0), 16000));
                  }}
                  onUp={() => {
                    const current = selected.targetAltitude ?? selected.altitude;
                    const rounded = Math.round(current / 1000) * 1000;
                    engine.setAltitude(Math.min(Math.max(rounded + 1000, 0), 16000));
                  }}
                />
                <Stepper
                  label="SPD"
                  value={`${Math.round(selected.targetSpeed ?? selected.speed)}kt`}
                  onDown={() => {
                    const current = selected.targetSpeed ?? selected.speed;
                    const rounded = Math.round(current / 10) * 10;
                    engine.setSpeed(rounded - 10);
                  }}
                  onUp={() => {
                    const current = selected.targetSpeed ?? selected.speed;
                    const rounded = Math.round(current / 10) * 10;
                    engine.setSpeed(rounded + 10);
                  }}
                />
              </div>
            </div>
            {isArrival(selected) ? (
              <button
                className={selected.clearedToLand ? "action warn" : "action"}
                onClick={() => (selected.clearedToLand ? engine.goAround() : engine.clearSelectedToLand())}
              >
                {selected.clearedToLand ? "GO AROUND" : `CLEARED TO LAND ${engine.activeRunway.name}`}
              </button>
            ) : departureFix ? (
              <button className="action" onClick={() => engine.directTo(departureFix)}>
                DIRECT {departureFix}
              </button>
            ) : null}
            <div className="note" style={{ marginTop: 8 }}>
              Drag a heading on the scope, or type: “{selected.spoken}, turn left heading 270, descend and maintain 3000.”
            </div>
          </>
        ) : (
          <div style={{ textAlign: "center", color: "var(--hud-dim)", fontWeight: 600, padding: "18px 0" }}>
            TAP AN AIRCRAFT TO TAKE CONTROL
          </div>
        )}
      </div>
    </div>
  );
}

function Stepper({
  label,
  value,
  onDown,
  onUp,
}: {
  label: string;
  value: string;
  onDown: () => void;
  onUp: () => void;
}) {
  return (
    <div className="stepper">
      <span style={{ width: 34, color: "var(--hud-dim)", fontWeight: 700 }}>{label}</span>
      <button className="round" onClick={onDown} aria-label={`Decrease ${label}`}>
        −
      </button>
      <span className="val">{value}</span>
      <button className="round" onClick={onUp} aria-label={`Increase ${label}`}>
        +
      </button>
    </div>
  );
}

function HeadingDial({ heading, onChange }: { heading: number; onChange: (h: number) => void }) {
  return (
    <div
      style={{ width: 104, height: 104, position: "relative" }}
      onPointerDown={(e) => {
        const rect = (e.currentTarget as HTMLDivElement).getBoundingClientRect();
        const apply = (ev: PointerEvent | React.PointerEvent) => {
          const dx = ev.clientX - (rect.left + rect.width / 2);
          const dy = ev.clientY - (rect.top + rect.height / 2);
          if (Math.hypot(dx, dy) > 13) onChange(Nav.normalize((Math.atan2(dx, -dy) * 180) / Math.PI));
        };
        apply(e);
        const move = (ev: PointerEvent) => apply(ev);
        const up = () => {
          window.removeEventListener("pointermove", move);
          window.removeEventListener("pointerup", up);
        };
        window.addEventListener("pointermove", move);
        window.addEventListener("pointerup", up);
      }}
    >
      <svg viewBox="0 0 104 104" width="104" height="104">
        <circle cx="52" cy="52" r="48" fill="none" stroke="rgba(51,255,140,0.35)" strokeWidth="2" />
        {Array.from({ length: 12 }, (_, i) => {
          const deg = i * 30;
          const cardinal = i % 3 === 0;
          return (
            <rect
              key={i}
              x="51"
              y="6"
              width={cardinal ? 2 : 1}
              height={cardinal ? 9 : 5}
              fill={cardinal ? "rgba(51,255,140,0.8)" : "rgba(51,255,140,0.35)"}
              transform={`rotate(${deg} 52 52)`}
            />
          );
        })}
        <circle cx="52" cy="12" r="4.5" fill="#ffd94d" transform={`rotate(${heading} 52 52)`} />
      </svg>
      <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", pointerEvents: "none" }}>
        <div style={{ textAlign: "center" }}>
          <div style={{ color: "var(--selected)", fontWeight: 700, fontSize: 20 }}>{String(Math.round(heading)).padStart(3, "0")}</div>
          <div style={{ color: "var(--hud-dim)", fontSize: 8, fontWeight: 600 }}>HDG</div>
        </div>
      </div>
    </div>
  );
}

function TransmitBar({ onTransmit }: { onTransmit: (text: string) => void }) {
  return (
    <form
      className="tx"
      onSubmit={(e) => {
        e.preventDefault();
        const form = e.currentTarget;
        const input = form.elements.namedItem("tx") as HTMLInputElement;
        const text = input.value.trim();
        if (!text) return;
        onTransmit(text);
        input.value = "";
      }}
    >
      <input name="tx" placeholder="PTT · Delta 482, turn left heading 270" aria-label="Transmit ATC instruction" />
      <button type="submit">PTT</button>
    </form>
  );
}
