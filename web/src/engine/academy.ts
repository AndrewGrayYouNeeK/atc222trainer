import { GameEngine, scriptedArrival } from "./engine";
import { makeAircraft, type Aircraft } from "./types";
import { Nav } from "./nav";

export type LessonKind = "drill" | "checkRide";

export type LessonScenario =
  | "orientation"
  | "vectorBasics"
  | "separation"
  | "finalApproach"
  | "sequencing"
  | "departure"
  | "emergency"
  | "checkRide";

export type LessonGoal =
  | { type: "select" }
  | { type: "vector"; heading: number; altitudeAtOrBelow: number | null }
  | { type: "separate" }
  | { type: "land"; count: number }
  | { type: "spacing"; maxTrailingSpeed: number }
  | { type: "handoff"; count: number }
  | { type: "handleEmergency" }
  | { type: "certify"; handled: number };

export type AcademyLesson = {
  id: number;
  moduleNumber: number;
  moduleTitle: string;
  title: string;
  kind: LessonKind;
  concept: string;
  phraseology: string[];
  realismNote: string | null;
  objective: string;
  scenario: LessonScenario;
  goal: LessonGoal;
};

export const curriculum: AcademyLesson[] = [
  {
    id: 0,
    moduleNumber: 1,
    moduleTitle: "Fundamentals",
    title: "The Scope & the Data Block",
    kind: "drill",
    concept:
      "Welcome to Apex Approach. You're a TRACON-style approach controller working traffic within about 40 NM of the field. The rings are spaced 10 NM apart; the airport sits at the center. Aircraft enter at named fixes and you guide them to the runway or out to a departure gate.\n\nEvery target carries a data block: callsign, altitude in hundreds of feet (“070” = 7,000 ft), and groundspeed. The line off the target is the velocity leader — it points where the aircraft is going, and it grows with speed. Headings are magnetic and spoken as three digits (360 = north, 090 = east).",
    phraseology: [
      "You identify yourself as “Apex Approach.”",
      "Pilots read instructions back to you — that read-back is how you confirm they heard it right.",
    ],
    realismNote: "Real scopes show far more (Mode C, full data tags, automatic conflict alerts, weather). We keep the data block to callsign / altitude / speed.",
    objective: "Tap the highlighted aircraft to select it and read its data block.",
    scenario: "orientation",
    goal: { type: "select" },
  },
  {
    id: 1,
    moduleNumber: 1,
    moduleTitle: "Fundamentals",
    title: "Headings & Altitudes",
    kind: "drill",
    concept:
      "Your two primary tools are vectors (headings) and altitudes. Assign a heading and the aircraft turns at a standard rate, taking the shortest way around unless you specify a direction. Assign an altitude with “climb/descend and maintain.”\n\nInstructions are given in a consistent order — generally turn, then altitude, then speed — and always addressed to the callsign first.",
    phraseology: [
      "“United 319, turn left heading 270.”",
      "“United 319, descend and maintain 5,000.”",
      "Pilot read-back: “Left 270, down to 5,000, United 319.”",
    ],
    realismNote: null,
    objective: "Turn United 319 to heading 270 and descend to 5,000 or below.",
    scenario: "vectorBasics",
    goal: { type: "vector", heading: 270, altitudeAtOrBelow: 5000 },
  },
  {
    id: 2,
    moduleNumber: 2,
    moduleTitle: "Separation",
    title: "Separation Standards",
    kind: "drill",
    concept:
      "Your #1 job is separation. In approach control the standard minima are 3 NM laterally OR 1,000 ft vertically. As long as ONE of those is satisfied between any two aircraft, they’re legally separated.\n\nWhen two targets close inside the minima you’ll get a conflict alert (the halo). Fix it early: assign different altitudes, or turn one onto a diverging vector.",
    phraseology: [
      "“United 319, traffic 12 o’clock, 3 miles, opposite direction — descend and maintain 4,000.”",
      "Or vector: “United 319, turn right heading 090 for traffic.”",
    ],
    realismNote: "Real separation also factors wake-turbulence categories and facility-specific rules. We model the common 3 NM / 1,000 ft approach standard.",
    objective: "Two aircraft are in conflict. Restore 3 NM apart OR 1,000 ft of vertical.",
    scenario: "separation",
    goal: { type: "separate" },
  },
  {
    id: 3,
    moduleNumber: 3,
    moduleTitle: "Arrivals & Final",
    title: "Vectoring to Final",
    kind: "drill",
    concept:
      "To land, an arrival must be lined up with the final approach course — the extended runway centerline — then descended on a roughly 3° glidepath to the runway. You vector the aircraft to intercept the centerline at a shallow angle (30° or less), get it down to the intercept altitude, and clear it for the approach.",
    phraseology: [
      "“Delta 482, turn left heading 340 to join the final approach course.”",
      "“Delta 482, descend and maintain 2,000.”",
      "“Delta 482, cleared to land runway 34.”",
    ],
    realismNote: "Real ops split this between Approach (vectors + “cleared ILS”) and Tower (“cleared to land”). We fold it into one “cleared to land.”",
    objective: "Vector Delta 482 onto final, descend it, and clear it to land.",
    scenario: "finalApproach",
    goal: { type: "land", count: 1 },
  },
  {
    id: 4,
    moduleNumber: 3,
    moduleTitle: "Arrivals & Final",
    title: "Sequencing & Speed Control",
    kind: "drill",
    concept:
      "When several arrivals funnel to one runway, speed is how you build and protect the spacing between them. Slow a fast trailing aircraft so it doesn’t compress on the one ahead; you generally work down from around 210 knots to 170, then to final-approach speed.",
    phraseology: [
      "“American 502, reduce speed to 180.”",
      "“American 502, reduce speed to 170, you’re number two following traffic on final.”",
    ],
    realismNote: null,
    objective: "Two are in trail and compressing. Slow the trailing jet to 180 knots or less.",
    scenario: "sequencing",
    goal: { type: "spacing", maxTrailingSpeed: 180 },
  },
  {
    id: 5,
    moduleNumber: 4,
    moduleTitle: "Departures",
    title: "Departures & Handoffs",
    kind: "drill",
    concept:
      "Departures come off the runway climbing. You give them a climb and turn them on course toward their departure fix, keeping them clear of your arrivals. Once they’re established and leaving your airspace, you hand them off to the next sector (Center).",
    phraseology: [
      "“JetBlue 412, climb and maintain 5,000.”",
      "“JetBlue 412, proceed direct NORTH.”",
      "“JetBlue 412, contact Center. Good day.”",
    ],
    realismNote: "We model the handoff as sending the aircraft direct to its exit fix and out of the sector, rather than a frequency change.",
    objective: "Climb the departure and send it direct NORTH to hand it off.",
    scenario: "departure",
    goal: { type: "handoff", count: 1 },
  },
  {
    id: 6,
    moduleNumber: 5,
    moduleTitle: "Emergencies",
    title: "Priority & Emergency Handling",
    kind: "drill",
    concept:
      "An aircraft in distress gets priority over everything else. When a pilot declares an emergency, you make them number one: shortest routing to the runway, expedited descent, and you move other traffic out of their way.",
    phraseology: [
      "“Delta 482, roger your emergency. You’re number one. Descend and maintain 3,000, cleared to land runway 34.”",
      "“Delta 482, say souls on board and fuel remaining.”",
    ],
    realismNote: "We simplify the radio back-and-forth. The skill that matters: drop everything and get the emergency safely on the ground first.",
    objective: "An aircraft is declaring an emergency. Get it down first — before its time runs out.",
    scenario: "emergency",
    goal: { type: "handleEmergency" },
  },
  {
    id: 7,
    moduleNumber: 6,
    moduleTitle: "Certification",
    title: "Certification Check Ride",
    kind: "checkRide",
    concept:
      "Put it all together against live traffic, exactly like a real certification check ride. Maintain separation, sequence arrivals onto final, climb and hand off departures, and handle whatever the day throws at you — all at once.\n\nYou’re cleared to certify once you’ve handled 6 aircraft without losing the picture.",
    phraseology: [
      "Everything you’ve learned — turns, altitudes, speed control, approach clearances, handoffs.",
      "Work the callsigns. Keep your scan moving.",
    ],
    realismNote: "A real check ride is graded live by a training supervisor over a full session. Here, success is handling 6 aircraft cleanly on relaxed-pace traffic.",
    objective: "Handle 6 aircraft cleanly to earn your certification.",
    scenario: "checkRide",
    goal: { type: "certify", handled: 6 },
  },
];

export function scenarioAircraft(scenario: LessonScenario, engine: GameEngine): Aircraft[] {
  switch (scenario) {
    case "orientation":
      return [scriptedArrival("DAL482", "Delta 482", "jet", { x: -18, y: 16 }, 225, 7000, 220)];
    case "vectorBasics":
      return [scriptedArrival("UAL319", "United 319", "jet", { x: 24, y: 14 }, 240, 11000, 300)];
    case "separation":
      return [
        scriptedArrival("DAL482", "Delta 482", "jet", { x: -1.5, y: 6 }, 360, 6000, 220),
        scriptedArrival("UAL319", "United 319", "jet", { x: 1.0, y: 6 }, 360, 6000, 220),
      ];
    case "finalApproach":
      return [scriptedArrival("DAL482", "Delta 482", "jet", { x: 4, y: -13 }, 20, 5000, 220)];
    case "sequencing":
      return [
        scriptedArrival("DAL482", "Delta 482", "jet", { x: 4, y: -10 }, 340, 2500, 180),
        scriptedArrival("AAL502", "American 502", "jet", { x: 4.7, y: -22 }, 340, 4000, 260),
      ];
    case "departure": {
      const dep = makeAircraft({
        callsign: "JBU412",
        spoken: "JetBlue 412",
        kind: "jet",
        intent: { type: "departure", fix: "NORTH" },
        position: { ...engine.activeRunway.threshold },
        heading: engine.activeRunway.heading,
        altitude: 1000,
        speed: 165,
        targetAltitude: 5000,
        targetSpeed: 180,
      });
      return [dep];
    }
    case "emergency":
      return [scriptedArrival("DAL482", "Delta 482", "jet", { x: 16, y: 16 }, 225, 7000, 250)];
    case "checkRide":
      return [];
  }
}

export function goalMet(
  goal: LessonGoal,
  engine: GameEngine,
  baseline: { landings: number; departures: number; emergencies: number; handled: number },
): boolean {
  switch (goal.type) {
    case "select":
      return engine.selectedID != null;
    case "vector": {
      const a = engine.aircraft[0];
      if (!a) return false;
      const hdg = a.targetHeading ?? a.heading;
      const okHeading = Math.abs(Nav.signedDelta(hdg, goal.heading)) <= 20;
      const okAlt = goal.altitudeAtOrBelow == null || (a.targetAltitude ?? a.altitude) <= goal.altitudeAtOrBelow + 1;
      return okHeading && okAlt;
    }
    case "separate": {
      const live = engine.aircraft.filter((a) => a.phase !== "completed" && a.phase !== "crashed");
      if (live.length < 2 || engine.commandsIssued <= 0) return false;
      for (let i = 0; i < live.length; i++) {
        for (let j = i + 1; j < live.length; j++) {
          const horizontal = Nav.distance(live[i]!.position, live[j]!.position);
          const vertical = Math.abs(live[i]!.altitude - live[j]!.altitude);
          if (horizontal < 3 && vertical < 1000) return false;
        }
      }
      return true;
    }
    case "land":
      return engine.landings - baseline.landings >= goal.count;
    case "spacing": {
      const arrivals = engine.aircraft.filter((a) => a.intent.type === "arrival");
      if (engine.commandsIssued <= 0 || !arrivals.length) return false;
      const trailer = arrivals.reduce((best, ac) =>
        Math.hypot(ac.position.x, ac.position.y) > Math.hypot(best.position.x, best.position.y) ? ac : best,
      );
      return (trailer.targetSpeed ?? trailer.speed) <= goal.maxTrailingSpeed + 1;
    }
    case "handoff":
      return engine.departures - baseline.departures >= goal.count;
    case "handleEmergency":
      return engine.emergenciesHandled - baseline.emergencies >= 1;
    case "certify":
      return engine.handled - baseline.handled >= goal.handled;
  }
}
