import { Nav } from "./nav";
import { arrivalFixes } from "./airport";
import { makeAircraft, type Aircraft, type AircraftKind, type Airport, type Fix, type Runway } from "./types";

const airlines = [
  { code: "DAL", spoken: "Delta" },
  { code: "UAL", spoken: "United" },
  { code: "AAL", spoken: "American" },
  { code: "SWA", spoken: "Southwest" },
  { code: "JBU", spoken: "JetBlue" },
  { code: "FFT", spoken: "Frontier" },
  { code: "ASA", spoken: "Alaska" },
  { code: "NKS", spoken: "Spirit" },
] as const;

const letters = "ABCDEFGHJKLMNPQRSTUVWXYZ";

export function uniqueCallsign(existing: Set<string>, prop: boolean): { code: string; spoken: string } {
  for (let i = 0; i < 40; i++) {
    if (prop) {
      const digits = Array.from({ length: 4 }, () => Math.floor(Math.random() * 10)).join("");
      const letter = letters[Math.floor(Math.random() * letters.length)]!;
      const code = `N${digits}${letter}`;
      if (!existing.has(code)) return { code, spoken: code };
    } else {
      const airline = airlines[Math.floor(Math.random() * airlines.length)]!;
      const number = Math.floor(Math.random() * 900) + 100;
      const code = `${airline.code}${number}`;
      if (!existing.has(code)) return { code, spoken: `${airline.spoken} ${number}` };
    }
  }
  const fallback = `GA${Math.floor(Math.random() * 9000) + 1000}`;
  return { code: fallback, spoken: fallback };
}

export function makeArrival(fix: Fix, existing: Set<string>): Aircraft {
  const prop = Math.random() < 0.18;
  const kind: AircraftKind = prop ? "prop" : Math.random() < 0.5 ? "jet" : "heavy";
  const { code, spoken } = uniqueCallsign(existing, prop);
  const inbound = Nav.bearing(fix.position, { x: 0, y: 0 });
  return makeAircraft({
    callsign: code,
    spoken,
    kind,
    intent: { type: "arrival" },
    position: { ...fix.position },
    heading: inbound + (Math.random() * 16 - 8),
    altitude: (Math.floor(Math.random() * 51) + 60) * 100,
    speed: Math.floor(Math.random() * 61) + 230,
  });
}

export function makeDeparture(runway: Runway, exitFix: Fix, existing: Set<string>): Aircraft {
  const prop = Math.random() < 0.22;
  const kind: AircraftKind = prop ? "prop" : "jet";
  const { code, spoken } = uniqueCallsign(existing, prop);
  const minSpeed = kind === "prop" ? 90 : 140;
  return makeAircraft({
    callsign: code,
    spoken,
    kind,
    intent: { type: "departure", fix: exitFix.name },
    position: { ...runway.threshold },
    heading: runway.heading,
    altitude: 1000,
    speed: minSpeed + 20,
    targetAltitude: 5000,
    targetSpeed: minSpeed + 60,
  });
}

export function seedInitialTraffic(airport: Airport, existing: Set<string>): Aircraft[] {
  const shuffled = [...arrivalFixes(airport)].sort(() => Math.random() - 0.5);
  const out: Aircraft[] = [];
  const used = new Set(existing);
  for (const fix of shuffled.slice(0, 2)) {
    const ac = makeArrival(fix, used);
    used.add(ac.callsign);
    out.push(ac);
  }
  return out;
}
