# The Academy — training curriculum & graduation

Apex Control's on-ramp is a genuine controller-training pipeline. It aims to teach a
real-world trainee the actual concepts and standard phraseology — not just the
game's buttons — and then graduates the player into the live game.

Content: `YouNeeKATC/Models/Academy.swift` · Flow: `YouNeeKATC/Views/AcademyView.swift`

## Pedagogy
- Each lesson opens with a **briefing** (the WHY + the real procedure), shows the
  **standard FAA/ICAO phraseology** to say, then drops the student onto the live scope
  to **demonstrate** the skill with tap **or** voice.
- Phraseology is real: "turn left heading 270", "descend and maintain 5,000", "reduce
  speed to 180", "cleared to land runway 34", "contact Center". Pilots read instructions
  back; the controller leads with the callsign.
- Where the game simplifies real operations, the lesson **says so** (a `realismNote`).

## Curriculum (6 modules → certification)
1. **Fundamentals** — Scope & data block (range rings, callsign/altitude/speed,
   velocity leader, magnetic 3-digit headings, flight levels); then headings & altitudes.
2. **Separation** — The standard minima: **3 NM laterally OR 1,000 ft vertically**.
   Resolve a conflict by altitude or a diverging vector; issue a traffic advisory.
3. **Arrivals & Final** — Vectoring onto the final approach course, a ~3° glidepath,
   shallow (≤30°) intercepts, and approach/landing clearance; plus sequencing.
4. **Arrivals & Final (cont.)** — Speed control for in-trail spacing (210 → 170 → final),
   so arrivals don't compress on final.
5. **Departures** — Climb-out, on-course turns to the departure fix, and handoff to the
   next sector while staying clear of arrivals.
6. **Emergencies** — Priority handling: make the emergency number one, expedite, and move
   other traffic out of the way.
7. **Certification Check Ride** — Live traffic. Handle 6 aircraft cleanly to certify.

> Standard-of-accuracy note: separation minima, phraseology, instruction order, and
> vectoring/sequencing technique follow common FAA approach-control (TRACON) practice.
> The sim folds Approach's "cleared for the approach" and Tower's "cleared to land" into
> a single clearance, models handoffs as routing to the exit fix, and uses one runway —
> each simplification is called out in-lesson.

## Graduation → live game (the payoff)
- Passing the check ride sets `AppSettings.isCertified`, plays a celebratory **CERTIFIED**
  moment, and routes **straight into a live shift** at the player's chosen difficulty.
- Post-graduation **progression**: `ControllerRank` (Trainee → Developmental → Certified
  Professional → Radar Approach Controller → Senior → Watch Supervisor → Operations
  Manager → TRACON Legend) is earned from lifetime aircraft handled and surfaced on the
  menu, the stats screen, and as a **promotion** banner on game-over.
- The live game keeps the realism's vocabulary but turns up the fun: streak/combo
  multipliers, score pops, escalating spawn pacing, emergencies, haptics + synthesized
  audio cues, Game Center leaderboards and achievements.

## Replay & accessibility
- Replayable any time from **Settings ▸ Replay the Academy**.
- Fully operable by touch for VoiceOver users (voice control is additive, never required).
