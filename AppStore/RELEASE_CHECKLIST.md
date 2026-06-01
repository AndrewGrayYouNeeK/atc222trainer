# Release checklist — Apex Control v1.0

Work top to bottom in Xcode (this repo was developed in an environment without Xcode,
so the steps below are the manual gates that still require it).

## 1. Open & build
- [ ] Open `YouNeeKATC.xcodeproj` in Xcode 26.5+.
- [ ] Select the `YouNeeKATC` scheme, an iOS 26 Simulator, and **Build** (⌘B).
- [ ] Run the unit tests (`YouNeeKATCTests`) with ⌘U — all should pass.
- [ ] Fix any environment-specific warnings (this code targets Swift 6 with
      `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).

## 2. Capabilities & signing
- [ ] Target ▸ Signing & Capabilities: confirm your team (`DEVELOPMENT_TEAM`).
- [ ] Add the **Game Center** capability (entitlement is already in
      `YouNeeKATC.entitlements`).
- [ ] Confirm automatic signing resolves a provisioning profile that includes
      Game Center.

## 3. Game Center
- [ ] Create the leaderboards and achievements from `GAME_CENTER_SETUP.md` with the
      exact IDs.
- [ ] Test score submission and at least one achievement with a sandbox account.

## 4. Assets & metadata
- [ ] Confirm the App Icon renders (1024² in `Assets.xcassets/AppIcon.appiconset`).
- [ ] Capture screenshots per `SCREENSHOTS.md`.
- [ ] Paste listing text from `METADATA.md`; set Privacy Policy URL (host
      `PRIVACY_POLICY.md`).
- [ ] App privacy: **Data Not Collected**.
- [ ] In-App Purchases: none (see METADATA rationale).

## 5. Device QA
- [ ] Run on a physical iPhone and iPad. Verify 60fps on the oldest supported device
      during an Intense rush (the sim loop is fixed-step; the Canvas render is the
      cost — profile with Instruments ▸ Core Animation if needed).
- [ ] **Academy pass:** play all 6 modules; confirm each drill's objective auto-detects
      completion, the briefings read correctly, and the certification check ride
      graduates straight into a live game with the CERTIFIED moment. Confirm a rank-up
      shows the PROMOTED banner on game-over.
- [ ] **Voice control on device** (does NOT work in Simulator): grant mic + speech on
      first prompt; hold-to-talk and say "Delta 482, turn left heading 270, descend and
      maintain 3000" → aircraft responds + spoken read-back. Test hands-free toggle and
      the denied-permission path (Settings deep-link in the voice bar).
- [ ] VoiceOver pass: every control is reachable and labelled; the scope announces a
      traffic summary. (Voice control is additive — touch controls remain for VoiceOver
      users.)
- [ ] Dynamic Type, Reduce Motion, and the colour-blind palette (Settings) all work.
- [ ] Background the app mid-run → it pauses; foreground → resumes without a jump.

## 6. Archive & submit
- [ ] Product ▸ Archive (Release config, Any iOS Device).
- [ ] Validate, then Distribute ▸ App Store Connect.
- [ ] Submit for review.

## Notes / known follow-ups
- Sound is synthesized at runtime (no bundled audio assets) and mixes with other
  audio; verify on-device tone quality and adjust `SoundManager` envelopes to taste.
- Single airport (KAPX) ships in v1.0; `Airport.catalog` is structured to add more.
