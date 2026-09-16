import { activeRunway, arrivalFixes, departureFixes, KAPX } from "./airport";
import { makeArrival, makeDeparture, seedInitialTraffic } from "./traffic";
import { Nav, rangeFromField } from "./nav";
import {
  calmWeather,
  difficultyMeta,
  isArrival,
  kindPerf,
  makeAircraft,
  randomEmergencyType,
  type Aircraft,
  type Airport,
  type Difficulty,
  type Emergency,
  type GameEvent,
  type GameOverReason,
  type RunResult,
  type TurnDirection,
  type Weather,
} from "./types";
import { commandPhrase, type ParsedTransmission } from "./phraseology";

const SECTOR_RADIUS = 42;
const CONFLICT_RANGE = 3;
const CONFLICT_VERTICAL = 1000;
const COLLISION_RANGE = 0.9;
const COLLISION_VERTICAL = 400;

export class GameEngine {
  aircraft: Aircraft[] = [];
  score = 0;
  lives = 3;
  streak = 0;
  bestStreak = 0;
  landings = 0;
  departures = 0;
  emergenciesHandled = 0;
  elapsed = 0;
  emergencies: Emergency[] = [];
  isRunning = false;
  isPaused = false;
  selectedID: string | null = null;
  commandsIssued = 0;

  readonly airport: Airport;
  readonly weather: Weather;
  readonly activeRunway: ReturnType<typeof activeRunway>;
  readonly difficulty: Difficulty;
  readonly isTraining: boolean;

  onEvent: ((event: GameEvent) => void) | null = null;
  onUi: (() => void) | null = null;

  private loop: number | null = null;
  private lastTs = 0;
  private spawnAccumulator = 0;
  private emergencyAccumulator = 0;
  private nextMilestone = 500;

  constructor(opts: { difficulty: Difficulty; airport?: Airport; training?: boolean }) {
    this.difficulty = opts.difficulty;
    this.airport = opts.airport ?? KAPX;
    this.weather = { ...calmWeather };
    this.activeRunway = activeRunway(this.airport, this.weather.windDirection);
    this.isTraining = opts.training ?? false;
    this.lives = this.isTraining ? 99 : difficultyMeta[this.difficulty].startingLives;
  }

  get selected(): Aircraft | undefined {
    return this.aircraft.find((a) => a.id === this.selectedID);
  }

  get handled(): number {
    return this.landings + this.departures;
  }

  get callsignCandidates() {
    return this.aircraft.map((a) => ({ callsign: a.callsign, spoken: a.spoken }));
  }

  start() {
    if (this.isRunning) return;
    this.isRunning = true;
    this.isPaused = false;
    if (this.isTraining) this.seedTrainingAircraft();
    else this.aircraft = seedInitialTraffic(this.airport, new Set());
    this.launchLoop();
    this.notify();
  }

  pause() {
    this.isPaused = true;
    this.notify();
  }

  resume() {
    this.isPaused = false;
    this.notify();
  }

  quit() {
    if (!this.isRunning) return;
    this.finish("quit");
  }

  teardown() {
    if (this.loop != null) cancelAnimationFrame(this.loop);
    this.loop = null;
    this.isRunning = false;
  }

  select(id: string) {
    this.selectedID = id;
    this.emit({ type: "aircraftSelected" });
    this.notify();
  }

  setHeading(heading: number, turn: TurnDirection = "auto") {
    this.mutateSelected((ac) => {
      ac.targetHeading = Nav.normalize(heading);
      ac.turnDirection = turn;
      ac.lastInstruction = `FLY HDG ${String(Math.round(Nav.normalize(heading))).padStart(3, "0")}`;
    });
  }

  setAltitude(feet: number) {
    this.mutateSelected((ac) => {
      ac.targetAltitude = Math.max(0, feet);
      ac.lastInstruction = `${feet > ac.altitude ? "CLIMB" : "DESCEND"} ${Math.round(feet)}`;
    });
  }

  setSpeed(knots: number) {
    this.mutateSelected((ac) => {
      const perf = kindPerf[ac.kind];
      const clamped = Math.min(Math.max(knots, perf.minSpeed), perf.maxSpeed);
      ac.targetSpeed = clamped;
      ac.lastInstruction = `SPEED ${Math.round(clamped)}`;
    });
  }

  directTo(fixNamed: string) {
    const fix = this.airport.fixes.find((f) => f.name === fixNamed);
    if (!fix) return;
    this.mutateSelected((ac) => {
      ac.targetHeading = Nav.bearing(ac.position, fix.position);
      ac.turnDirection = "auto";
      ac.handoffFix = fixNamed;
      ac.lastInstruction = `DIRECT ${fixNamed}`;
    });
  }

  clearSelectedToLand() {
    const ac = this.selected;
    if (!ac || !isArrival(ac)) return;
    ac.clearedToLand = true;
    ac.lastInstruction = `CLEARED TO LAND ${this.activeRunway.name}`;
    this.emit({ type: "clearedToLand" });
    this.commandsIssued += 1;
    this.notify();
  }

  goAround() {
    this.mutateSelected((ac) => {
      if (!isArrival(ac)) return;
      ac.clearedToLand = false;
      ac.phase = "enroute";
      ac.targetAltitude = 4000;
      ac.targetSpeed = kindPerf[ac.kind].maxSpeed * 0.7;
      ac.lastInstruction = "GO AROUND";
    });
  }

  apply(transmission: ParsedTransmission): boolean {
    const callsign = transmission.targetCallsign;
    if (!callsign) return false;
    const ac = this.aircraft.find((a) => a.callsign === callsign);
    if (!ac) return false;
    this.selectedID = ac.id;
    let applied = false;
    for (const command of transmission.commands) {
      switch (command.type) {
        case "turn":
          ac.targetHeading = Nav.normalize(command.heading);
          ac.turnDirection = command.kind === "left" ? "left" : command.kind === "right" ? "right" : "auto";
          applied = true;
          break;
        case "climb":
        case "descend":
        case "maintainAltitude":
          ac.targetAltitude = Math.max(0, command.altitude);
          applied = true;
          break;
        case "speed": {
          const perf = kindPerf[ac.kind];
          ac.targetSpeed = Math.min(Math.max(command.knots, perf.minSpeed), perf.maxSpeed);
          applied = true;
          break;
        }
        case "direct": {
          const fix = this.airport.fixes.find((f) => f.name === command.fix);
          if (fix) {
            ac.targetHeading = Nav.bearing(ac.position, fix.position);
            ac.turnDirection = "auto";
            ac.handoffFix = command.fix;
            applied = true;
          }
          break;
        }
        case "clearedToLand":
          if (isArrival(ac)) {
            ac.clearedToLand = true;
            applied = true;
            this.emit({ type: "clearedToLand" });
          }
          break;
      }
    }
    if (applied) {
      ac.lastInstruction = transmission.commands.map(commandPhrase).join(" · ").toUpperCase();
      this.commandsIssued += 1;
      this.emit({ type: "commandIssued" });
      this.notify();
    }
    return applied;
  }

  loadScenario(scripted: Aircraft[], select = true) {
    this.aircraft = scripted;
    this.emergencies = [];
    this.spawnAccumulator = 0;
    this.emergencyAccumulator = 0;
    this.selectedID = select ? (scripted[0]?.id ?? null) : null;
    this.notify();
  }

  triggerEmergency(id: string, type: Emergency["type"], seconds = 100) {
    const ac = this.aircraft.find((a) => a.id === id);
    if (!ac || ac.emergency) return;
    ac.emergency = type;
    this.emergencies.push({
      id: crypto.randomUUID(),
      aircraftID: ac.id,
      callsign: ac.callsign,
      type,
      deadline: performance.now() + seconds * 1000,
      resolved: false,
    });
    this.emit({ type: "emergencyBegan", emergencyType: type, callsign: ac.callsign });
    this.notify();
  }

  private seedTrainingAircraft() {
    const fix = arrivalFixes(this.airport).find((f) => f.name === "GOLDN") ?? arrivalFixes(this.airport)[0]!;
    const trainer = makeArrival(fix, new Set());
    trainer.altitude = 6000;
    trainer.speed = 250;
    this.aircraft = [trainer];
    this.selectedID = trainer.id;
  }

  private mutateSelected(body: (ac: Aircraft) => void) {
    const ac = this.selected;
    if (!ac) return;
    body(ac);
    this.commandsIssued += 1;
    this.emit({ type: "commandIssued" });
    this.notify();
  }

  private launchLoop() {
    const step = (ts: number) => {
      this.loop = requestAnimationFrame(step);
      if (!this.isRunning) return;
      if (!this.lastTs) this.lastTs = ts;
      const dt = Math.min(Math.max((ts - this.lastTs) / 1000, 0), 0.1);
      this.lastTs = ts;
      if (this.isPaused || dt <= 0) return;
      this.tick(dt);
    };
    this.loop = requestAnimationFrame(step);
  }

  tick(dt: number) {
    this.elapsed += dt;
    for (const ac of this.aircraft) {
      this.stepHeading(ac, dt);
      this.stepAltitude(ac, dt);
      this.stepSpeed(ac, dt);
      this.move(ac, dt);
      if (isArrival(ac)) this.updateApproach(ac);
      else this.updateDeparture(ac);
    }
    this.detectConflicts();
    if (!this.isTraining) {
      this.handleSpawns(dt);
      this.handleEmergencies(dt);
    }
    this.resolveCompletions();
    this.checkMilestones();
  }

  private stepHeading(ac: Aircraft, dt: number) {
    if (ac.targetHeading == null) return;
    const delta = Nav.signedDelta(ac.heading, ac.targetHeading);
    const maxStep = kindPerf[ac.kind].turnRate * dt;
    let step: number;
    switch (ac.turnDirection) {
      case "auto":
        step = Math.max(-maxStep, Math.min(maxStep, delta));
        break;
      case "left": {
        let left = delta;
        if (left > 0) left -= 360;
        step = Math.max(left, -maxStep);
        break;
      }
      case "right": {
        let right = delta;
        if (right < 0) right += 360;
        step = Math.min(right, maxStep);
        break;
      }
    }
    ac.heading = Nav.normalize(ac.heading + step);
    if (Math.abs(Nav.signedDelta(ac.heading, ac.targetHeading)) <= maxStep) {
      ac.heading = ac.targetHeading;
      ac.targetHeading = null;
      ac.turnDirection = "auto";
    }
  }

  private stepAltitude(ac: Aircraft, dt: number) {
    if (ac.targetAltitude == null) return;
    const maxStep = kindPerf[ac.kind].climbRate * dt;
    const diff = ac.targetAltitude - ac.altitude;
    if (Math.abs(diff) <= maxStep) {
      ac.altitude = ac.targetAltitude;
      ac.targetAltitude = null;
    } else {
      ac.altitude += maxStep * (diff > 0 ? 1 : -1);
    }
  }

  private stepSpeed(ac: Aircraft, dt: number) {
    if (ac.targetSpeed == null) return;
    const maxStep = 9 * dt;
    const diff = ac.targetSpeed - ac.speed;
    if (Math.abs(diff) <= maxStep) {
      ac.speed = ac.targetSpeed;
      ac.targetSpeed = null;
    } else {
      ac.speed += maxStep * (diff > 0 ? 1 : -1);
    }
  }

  private move(ac: Aircraft, dt: number) {
    const v = Nav.vector(ac.heading);
    const nmPerSec = ac.speed / 3600;
    const windV = Nav.vector(Nav.normalize(this.weather.windDirection + 180));
    const windNM = (this.weather.windSpeed / 3600) * 0.35;
    ac.position.x += v.x * nmPerSec * dt + windV.x * windNM * dt;
    ac.position.y += v.y * nmPerSec * dt + windV.y * windNM * dt;
    const last = ac.trail[ac.trail.length - 1];
    if (!last || Nav.distance(last, ac.position) > 0.5) {
      ac.trail.push({ ...ac.position });
      if (ac.trail.length > 16) ac.trail.splice(0, ac.trail.length - 16);
    }
  }

  private runwayFrame(ac: Aircraft) {
    const dir = Nav.vector(this.activeRunway.heading);
    const perp = { x: dir.y, y: -dir.x };
    const w = {
      x: ac.position.x - this.activeRunway.threshold.x,
      y: ac.position.y - this.activeRunway.threshold.y,
    };
    return { along: w.x * dir.x + w.y * dir.y, lateral: w.x * perp.x + w.y * perp.y };
  }

  private updateApproach(ac: Aircraft) {
    if (ac.phase === "completed" || ac.phase === "crashed") return;
    const frame = this.runwayFrame(ac);
    const aligned = Math.abs(Nav.signedDelta(ac.heading, this.activeRunway.heading)) <= 35;
    const onApproachSide = frame.along < 0;
    const nearCenterline = Math.abs(frame.lateral) <= 1.3;
    const lowEnough = ac.altitude <= 4200;
    if (ac.clearedToLand && onApproachSide && nearCenterline && aligned && lowEnough && frame.along > -13) {
      ac.phase = "landing";
    }
    if (ac.phase === "landing") {
      const correction = Math.max(-12, Math.min(12, -frame.lateral * 10));
      ac.targetHeading = Nav.normalize(this.activeRunway.heading + correction);
      ac.turnDirection = "auto";
      const glide = Math.max(0, -frame.along) * 300;
      ac.targetAltitude = Math.min(glide, ac.altitude);
      ac.targetSpeed = kindPerf[ac.kind].minSpeed;
      if (frame.along >= -0.4) {
        if (ac.altitude <= 400 && ac.speed <= kindPerf[ac.kind].minSpeed + 25) {
          ac.phase = "completed";
        } else {
          ac.clearedToLand = false;
          ac.phase = "enroute";
          ac.targetAltitude = 4000;
          ac.targetSpeed = kindPerf[ac.kind].maxSpeed * 0.7;
          ac.lastInstruction = "GO AROUND";
        }
      }
    }
  }

  private updateDeparture(ac: Aircraft) {
    if (ac.phase === "completed" || ac.phase === "crashed") return;
    const intent = ac.intent;
    if (intent.type !== "departure") return;
    const fix = this.airport.fixes.find((f) => f.name === intent.fix);
    if (!fix) return;
    const towardFix = Math.abs(Nav.signedDelta(ac.heading, Nav.bearing(ac.position, fix.position))) <= 30;
    if (rangeFromField(ac.position) >= SECTOR_RADIUS - 2 && ac.altitude >= 4000 && (towardFix || ac.handoffFix === fix.name)) {
      ac.phase = "completed";
    }
  }

  private detectConflicts() {
    for (const ac of this.aircraft) ac.conflict = false;
    const live = this.aircraft.filter((a) => a.phase !== "completed" && a.phase !== "crashed" && a.altitude > 500);
    for (let a = 0; a < live.length; a++) {
      for (let b = a + 1; b < live.length; b++) {
        const i = live[a]!;
        const j = live[b]!;
        const horizontal = Nav.distance(i.position, j.position);
        const vertical = Math.abs(i.altitude - j.altitude);
        if (horizontal < CONFLICT_RANGE && vertical < CONFLICT_VERTICAL) {
          if (!i.conflict && !j.conflict) this.emit({ type: "conflictBegan" });
          i.conflict = true;
          j.conflict = true;
          if (horizontal < COLLISION_RANGE && vertical < COLLISION_VERTICAL && !this.isTraining) {
            i.phase = "crashed";
            j.phase = "crashed";
            this.registerStrike(true);
          }
        }
      }
    }
  }

  private resolveCompletions() {
    const survivors: Aircraft[] = [];
    for (const ac of this.aircraft) {
      if (ac.phase === "completed") {
        this.award(ac);
        continue;
      }
      if (ac.phase === "crashed") continue;
      if (rangeFromField(ac.position) > SECTOR_RADIUS) {
        if (!this.isTraining) this.registerStrike(false);
        if (this.selectedID === ac.id) this.selectedID = null;
      } else {
        survivors.push(ac);
      }
    }
    this.aircraft = survivors;
    if (this.selectedID && !this.aircraft.some((a) => a.id === this.selectedID)) {
      this.selectedID = this.aircraft[0]?.id ?? null;
    }
  }

  private award(ac: Aircraft) {
    this.streak += 1;
    this.bestStreak = Math.max(this.bestStreak, this.streak);
    const base = isArrival(ac) ? 100 : 80;
    const comboBonus = 1 + (this.streak - 1) * 0.1;
    let points = Math.round(base * difficultyMeta[this.difficulty].scoreMultiplier * comboBonus);
    if (ac.emergency) {
      this.emergenciesHandled += 1;
      const em = this.emergencies.find((e) => e.aircraftID === ac.id && !e.resolved);
      points += 150 * (em ? 3 : 2);
      if (em) {
        em.resolved = true;
        this.emit({ type: "emergencyResolved", emergencyType: em.type });
      }
    }
    this.score += points;
    if (isArrival(ac)) {
      this.landings += 1;
      this.emit({ type: "landed", points, callsign: ac.callsign });
    } else {
      this.departures += 1;
      this.emit({ type: "departed", points, callsign: ac.callsign });
    }
    if (this.selectedID === ac.id) this.selectedID = null;
    this.notify();
  }

  private registerStrike(midair: boolean) {
    this.streak = 0;
    this.lives -= 1;
    this.emit({ type: "strike", remaining: Math.max(this.lives, 0) });
    this.notify();
    if (this.lives <= 0) this.finish(midair ? "midair" : "outOfLives");
  }

  private checkMilestones() {
    if (this.score >= this.nextMilestone) {
      this.emit({ type: "scoreMilestone", value: this.nextMilestone });
      this.nextMilestone += 500;
    }
  }

  private handleSpawns(dt: number) {
    this.spawnAccumulator += dt;
    const meta = difficultyMeta[this.difficulty];
    const ramp = Math.min(1, this.elapsed / 180);
    const interval = meta.initialSpawnInterval - (meta.initialSpawnInterval - meta.minSpawnInterval) * ramp;
    if (this.spawnAccumulator < interval) return;
    this.spawnAccumulator = 0;
    if (this.aircraft.length >= meta.trafficCeiling) return;
    this.spawnOne();
    this.notify();
  }

  private spawnOne() {
    const existing = new Set(this.aircraft.map((a) => a.callsign));
    const wantDeparture = Math.random() < 0.32 && this.aircraft.filter((a) => !isArrival(a)).length < 3;
    const exits = departureFixes(this.airport);
    if (wantDeparture && exits.length) {
      const exit = exits[Math.floor(Math.random() * exits.length)]!;
      this.aircraft.push(makeDeparture(this.activeRunway, exit, existing));
    } else {
      const fix = this.leastBusyArrivalFix();
      this.aircraft.push(makeArrival(fix, existing));
    }
  }

  private leastBusyArrivalFix() {
    const fixes = arrivalFixes(this.airport);
    return fixes.reduce((best, fix) => (this.minDistanceToTraffic(fix.position) > this.minDistanceToTraffic(best.position) ? fix : best));
  }

  private minDistanceToTraffic(point: { x: number; y: number }) {
    if (!this.aircraft.length) return Number.POSITIVE_INFINITY;
    return Math.min(...this.aircraft.map((a) => Nav.distance(a.position, point)));
  }

  private handleEmergencies(dt: number) {
    if (this.difficulty === "relaxed") return;
    this.emergencyAccumulator += dt;
    if (this.emergencyAccumulator < 45 || this.elapsed <= 60) return;
    this.emergencyAccumulator = 0;
    if (this.emergencies.some((e) => !e.resolved)) return;
    const candidates = this.aircraft.filter((a) => isArrival(a) && !a.emergency && a.phase === "enroute");
    if (!candidates.length) return;
    const ac = candidates[Math.floor(Math.random() * candidates.length)]!;
    const type = randomEmergencyType();
    ac.emergency = type;
    this.emergencies.push({
      id: crypto.randomUUID(),
      aircraftID: ac.id,
      callsign: ac.callsign,
      type,
      deadline: performance.now() + (110 - 30) * 1000,
      resolved: false,
    });
    this.emit({ type: "emergencyBegan", emergencyType: type, callsign: ac.callsign });
    this.notify();
  }

  private finish(reason: GameOverReason) {
    if (!this.isRunning) return;
    this.isRunning = false;
    this.teardown();
    const result: RunResult = {
      score: this.score,
      landings: this.landings,
      departures: this.departures,
      emergenciesHandled: this.emergenciesHandled,
      bestStreak: this.bestStreak,
      durationSeconds: Math.round(this.elapsed),
      difficulty: this.difficulty,
      date: Date.now(),
    };
    this.emit({ type: "gameOver", result, reason });
    this.notify();
  }

  private emit(event: GameEvent) {
    this.onEvent?.(event);
  }

  private notify() {
    this.onUi?.();
  }
}

export function scriptedArrival(
  callsign: string,
  spoken: string,
  kind: Aircraft["kind"],
  at: { x: number; y: number },
  heading: number,
  alt: number,
  spd: number,
): Aircraft {
  return makeAircraft({
    callsign,
    spoken,
    kind,
    intent: { type: "arrival" },
    position: at,
    heading,
    altitude: alt,
    speed: spd,
  });
}
