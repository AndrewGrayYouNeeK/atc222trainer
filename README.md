# Apex Control

A premium, touch-first **air traffic control** game for iPhone and iPad, built in
SwiftUI (Swift 6, iOS 26). You run an approach sector: vector arrivals onto the
runway, climb departures out to their fix, keep everyone separated, and survive the
building rush.

> Bundle ID `com.andrew.YouNeeKATC` · Display name "Apex Control"

## Training → certification → live (the on-ramp + the payoff)
- **The Academy** is a real controller-training pipeline that progresses through six
  modules: fundamentals (scope & data block, headings/altitudes) → **separation**
  standards (3 NM / 1,000 ft) → **vectoring to final & sequencing** arrivals → **speed
  control** for spacing → **departures & handoffs** → **emergencies & priority** → a
  final **certification check ride** against live traffic. Each lesson teaches the
  *why* (real FAA/ICAO procedure) and the matching standard phraseology, then has you
  demonstrate it on the live scope (tap **or** voice). Where the game simplifies real
  ops, the lesson says so honestly.
- **Graduation is the bridge:** passing the check ride certifies you and leads straight
  into live play. Curriculum lives in `Models/Academy.swift`; the flow is
  `Views/AcademyView.swift`.
- **Progression after graduation:** a `ControllerRank` ladder (Trainee → Developmental →
  Certified Professional → … → TRACON Legend) is earned from lifetime aircraft handled
  (`PlayerStore`), shown on the menu and stats, with a celebratory **promotion** moment
  on the game-over screen. Realism in training; fun, juicy, escalating play in the game —
  they coexist.

## Gameplay loop
- **Command by voice** (hold-to-talk or hands-free): speak real phraseology like
  *"Delta 482, descend and maintain 3000, cleared to land"* — on-device recognition,
  with spoken pilot read-back. Or **by touch**: select an aircraft (tap) → **vector**
  it (drag a heading / heading dial) → set **altitude/speed** → **clear to land** /
  **direct** to a fix. Voice and touch work interchangeably (hybrid).
- Land arrivals and hand off departures for points. Chain clean handoffs for a
  **streak multiplier**.
- **Lose separation** (a midair) or let too many slip out of the sector unhandled and
  you burn a life. Out of lives ends the shift.
- **Emergencies** (medical, low fuel, engine failure…) demand priority handling under
  a countdown.
- Three **difficulties** ramp spawn pacing, traffic ceiling and the score multiplier.

## Architecture
Clean separation between a UIKit/SwiftUI-free simulation core and the presentation
layer, so the engine is unit-testable in isolation.

```
YouNeeKATC/
  App/            AppEnvironment (DI container), RootView (router), App entry
  Engine/         GameEngine (the sim), GameEvent, TrafficFactory
  Models/         Aircraft, Airport, Geometry, GameModels, Weather, Emergency, Academy, ControllerRank
  Services/       AppSettings, PlayerStore (save/load), GameCenterManager, VoiceCommandManager, Haptics, SoundManager
  Theme/          Theme (palette + typography + phosphor glow)
  Views/          MainMenu, Onboarding, Academy, Settings, Stats, PrivacyPolicy, GameCenterDashboard
    Game/         GameContainerView, RadarScopeView, HUD, ControlPanel, Pause/GameOver overlays
    Components/   Reusable buttons, panel, CRT backdrop
  Utils/          ATCPhraseology (phraseology parser + readback generation; tested)
  Localizable.xcstrings   en (base), es, fr
```

Key decisions:
- **`GameEngine`** is `@MainActor @Observable` and owns a fixed-step (~60 Hz) loop in a
  `Task`. It emits `GameEvent`s through an `onEvent` closure; the view layer turns those
  into haptics, audio and Game Center reporting. Mutating game state in the loop (not in
  the SwiftUI render pass) keeps view updates clean.
- **Rendering** is a single `Canvas` inside `TimelineView(.animation)` — one draw call
  per frame for the whole scope (rings, sweep, runway, fixes, traffic, trails).
- **Persistence**: `PlayerStore` (JSON career profile in Application Support) +
  `AppSettings` (`UserDefaults`). Failures degrade to empty state, never crash.
- **Accessibility**: VoiceOver labels/values on the scope and every control, an
  adjustable heading action, a colour-blind palette, and Reduce Motion support.
- **No bundled audio**: `SoundManager` synthesizes short sine-burst cues at runtime and
  mixes with other audio.

## Building
Requires **Xcode 26.5+**. Open `YouNeeKATC.xcodeproj`, pick the `YouNeeKATC` scheme and
an iOS 26 device/simulator, and Run. Unit tests: ⌘U.

The project uses Xcode **synchronized file groups** (`objectVersion 77`), so files are
included by their folder membership — no manual `.pbxproj` edits needed to add sources.

## Shipping
See `AppStore/` for the full release path:
- `RELEASE_CHECKLIST.md` — the end-to-end gate list (build, signing, QA, archive).
- `GAME_CENTER_SETUP.md` — exact leaderboard/achievement IDs to create.
- `METADATA.md` — listing copy, keywords, category, IAP rationale.
- `PRIVACY_POLICY.md` — policy text (also mirrored in-app).
- `SCREENSHOTS.md` — capture sizes and shot list.

## Status
v1.0 is feature-complete in code: the realistic training **Academy** (6 modules +
certification check ride) that graduates into the full gameplay loop, rank-based career
progression, onboarding, settings, save/load, Game Center, three difficulties,
emergencies, weather, voice control, accessibility and localization. Real-device
performance profiling, screenshot capture, Game Center dashboard config, signing and
submission require Xcode + an Apple Developer account (tracked in
`RELEASE_CHECKLIST.md`).
