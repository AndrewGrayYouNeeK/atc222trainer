import { Nav } from "./nav";
import type { Airport, Fix, Runway } from "./types";

function reciprocal(runway: Runway): Runway {
  const recipNum = Math.round(Nav.normalize(runway.heading + 180) / 10) || 36;
  return {
    name: String(recipNum).padStart(2, "0"),
    heading: Nav.normalize(runway.heading + 180),
    threshold: { x: -runway.threshold.x, y: -runway.threshold.y },
    length: runway.length,
  };
}

export function activeRunway(airport: Airport, windFrom: number): Runway {
  const candidates = airport.runways.flatMap((r) => [r, reciprocal(r)]);
  return candidates.reduce((best, rwy) =>
    Math.abs(Nav.signedDelta(rwy.heading, windFrom)) < Math.abs(Nav.signedDelta(best.heading, windFrom))
      ? rwy
      : best,
  );
}

export const KAPX: Airport = {
  icao: "KAPX",
  name: "Apex Approach",
  runways: [{ name: "34", heading: 340, threshold: { x: 0, y: -0.9 }, length: 1.6 }],
  fixes: [
    { name: "GOLDN", position: { x: -30, y: 22 }, isArrival: true },
    { name: "BRAVO", position: { x: 32, y: 16 }, isArrival: true },
    { name: "SIERA", position: { x: 26, y: -28 }, isArrival: true },
    { name: "MAPLE", position: { x: -28, y: -24 }, isArrival: true },
    { name: "NORTH", position: { x: 4, y: 38 }, isArrival: false },
    { name: "SOUTH", position: { x: -6, y: -38 }, isArrival: false },
  ],
};

export const arrivalFixes = (airport: Airport): Fix[] => airport.fixes.filter((f) => f.isArrival);
export const departureFixes = (airport: Airport): Fix[] => airport.fixes.filter((f) => !f.isArrival);
