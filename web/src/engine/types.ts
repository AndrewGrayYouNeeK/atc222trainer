import type { Vec } from "./nav";

export type Difficulty = "relaxed" | "standard" | "intense";

export const DIFFICULTIES: Difficulty[] = ["relaxed", "standard", "intense"];

export const difficultyMeta: Record<
  Difficulty,
  {
    title: string;
    blurb: string;
    initialSpawnInterval: number;
    minSpawnInterval: number;
    trafficCeiling: number;
    scoreMultiplier: number;
    startingLives: number;
  }
> = {
  relaxed: {
    title: "Relaxed",
    blurb: "Gentle pacing. Learn the ropes.",
    initialSpawnInterval: 16,
    minSpawnInterval: 8,
    trafficCeiling: 6,
    scoreMultiplier: 1,
    startingLives: 5,
  },
  standard: {
    title: "Standard",
    blurb: "A steady, building rush.",
    initialSpawnInterval: 11,
    minSpawnInterval: 5,
    trafficCeiling: 9,
    scoreMultiplier: 1.5,
    startingLives: 3,
  },
  intense: {
    title: "Intense",
    blurb: "Relentless traffic. Experts only.",
    initialSpawnInterval: 7,
    minSpawnInterval: 3,
    trafficCeiling: 13,
    scoreMultiplier: 2.25,
    startingLives: 3,
  },
};

export type GameOverReason = "outOfLives" | "midair" | "quit";

export const gameOverHeadline: Record<GameOverReason, string> = {
  outOfLives: "Shift Over",
  midair: "Loss of Separation",
  quit: "Position Relieved",
};

export type AircraftKind = "heavy" | "jet" | "prop";

export const kindPerf: Record<
  AircraftKind,
  { minSpeed: number; maxSpeed: number; turnRate: number; climbRate: number }
> = {
  heavy: { minSpeed: 150, maxSpeed: 320, turnRate: 2.6, climbRate: 28 },
  jet: { minSpeed: 140, maxSpeed: 300, turnRate: 3.0, climbRate: 38 },
  prop: { minSpeed: 90, maxSpeed: 210, turnRate: 3.4, climbRate: 22 },
};

export type FlightIntent = { type: "arrival" } | { type: "departure"; fix: string };
export type AircraftPhase = "enroute" | "established" | "landing" | "completed" | "crashed";
export type TurnDirection = "auto" | "left" | "right";

export type EmergencyType =
  | "birdStrike"
  | "engineFailure"
  | "medical"
  | "lowFuel"
  | "terroristThreat"
  | "microburst";

export const emergencyMeta: Record<EmergencyType, { title: string; severity: number }> = {
  birdStrike: { title: "Bird Strike", severity: 2 },
  engineFailure: { title: "Engine Failure", severity: 3 },
  medical: { title: "Medical Emergency", severity: 2 },
  lowFuel: { title: "Low Fuel", severity: 3 },
  terroristThreat: { title: "Security Threat", severity: 5 },
  microburst: { title: "Microburst Escape", severity: 4 },
};

export const randomEmergencyType = (): EmergencyType => {
  const pool: EmergencyType[] = ["birdStrike", "engineFailure", "medical", "lowFuel", "terroristThreat"];
  return pool[Math.floor(Math.random() * pool.length)]!;
};

export type Aircraft = {
  id: string;
  callsign: string;
  spoken: string;
  kind: AircraftKind;
  intent: FlightIntent;
  position: Vec;
  heading: number;
  altitude: number;
  speed: number;
  targetHeading: number | null;
  targetAltitude: number | null;
  targetSpeed: number | null;
  turnDirection: TurnDirection;
  phase: AircraftPhase;
  clearedToLand: boolean;
  handoffFix: string | null;
  lastInstruction: string;
  trail: Vec[];
  conflict: boolean;
  emergency: EmergencyType | null;
};

export function makeAircraft(partial: {
  callsign: string;
  spoken: string;
  kind: AircraftKind;
  intent: FlightIntent;
  position: Vec;
  heading: number;
  altitude: number;
  speed: number;
  targetAltitude?: number | null;
  targetSpeed?: number | null;
  targetHeading?: number | null;
}): Aircraft {
  return {
    id: crypto.randomUUID(),
    callsign: partial.callsign,
    spoken: partial.spoken,
    kind: partial.kind,
    intent: partial.intent,
    position: { ...partial.position },
    heading: partial.heading,
    altitude: partial.altitude,
    speed: partial.speed,
    targetHeading: partial.targetHeading ?? null,
    targetAltitude: partial.targetAltitude ?? null,
    targetSpeed: partial.targetSpeed ?? null,
    turnDirection: "auto",
    phase: "enroute",
    clearedToLand: false,
    handoffFix: null,
    lastInstruction: "",
    trail: [],
    conflict: false,
    emergency: null,
  };
}

export function isArrival(ac: Aircraft): boolean {
  return ac.intent.type === "arrival";
}

export function altitudeLabel(altitude: number): string {
  return String(Math.round(altitude / 100)).padStart(3, "0");
}

export function speedLabel(speed: number): string {
  return String(Math.round(speed)).padStart(3, "0");
}

export type Emergency = {
  id: string;
  aircraftID: string;
  callsign: string;
  type: EmergencyType;
  deadline: number;
  resolved: boolean;
};

export type Weather = {
  windDirection: number;
  windSpeed: number;
};

export const calmWeather: Weather = { windDirection: 270, windSpeed: 4 };

export type RunResult = {
  score: number;
  landings: number;
  departures: number;
  emergenciesHandled: number;
  bestStreak: number;
  durationSeconds: number;
  difficulty: Difficulty;
  date: number;
};

export type GameEvent =
  | { type: "aircraftSelected" }
  | { type: "commandIssued" }
  | { type: "clearedToLand" }
  | { type: "conflictBegan" }
  | { type: "landed"; points: number; callsign: string }
  | { type: "departed"; points: number; callsign: string }
  | { type: "strike"; remaining: number }
  | { type: "scoreMilestone"; value: number }
  | { type: "emergencyBegan"; emergencyType: EmergencyType; callsign: string }
  | { type: "emergencyResolved"; emergencyType: EmergencyType }
  | { type: "gameOver"; result: RunResult; reason: GameOverReason };

export type Fix = {
  name: string;
  position: Vec;
  isArrival: boolean;
};

export type Runway = {
  name: string;
  heading: number;
  threshold: Vec;
  length: number;
};

export type Airport = {
  icao: string;
  name: string;
  runways: Runway[];
  fixes: Fix[];
};

export type ControllerRank = {
  level: number;
  title: string;
  minHandled: number;
};

export const RANK_LADDER: ControllerRank[] = [
  { level: 0, title: "Trainee", minHandled: 0 },
  { level: 1, title: "Developmental Controller", minHandled: 15 },
  { level: 2, title: "Certified Professional", minHandled: 50 },
  { level: 3, title: "Radar Approach Controller", minHandled: 120 },
  { level: 4, title: "Senior Controller", minHandled: 250 },
  { level: 5, title: "Watch Supervisor", minHandled: 500 },
  { level: 6, title: "Operations Manager", minHandled: 900 },
  { level: 7, title: "TRACON Legend", minHandled: 1500 },
];

export function rankForHandled(handled: number): ControllerRank {
  return RANK_LADDER.filter((r) => handled >= r.minHandled).at(-1) ?? RANK_LADDER[0]!;
}

export function rankProgress(rank: ControllerRank, handled: number): number {
  const next = RANK_LADDER.find((r) => r.level === rank.level + 1);
  if (!next) return 1;
  const span = next.minHandled - rank.minHandled;
  if (span <= 0) return 1;
  return Math.min(1, Math.max(0, (handled - rank.minHandled) / span));
}

export function rankRemaining(rank: ControllerRank, handled: number): number {
  const next = RANK_LADDER.find((r) => r.level === rank.level + 1);
  if (!next) return 0;
  return Math.max(0, next.minHandled - handled);
}
