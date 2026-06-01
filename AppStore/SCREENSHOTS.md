# Screenshots & preview capture guide

App Store screenshots must be **real captures from the running app** — they cannot be
mocked up by the build pipeline here (this environment has Command Line Tools only,
no Simulator/Xcode). Capture them once Xcode is available using the steps below.

## Required sizes (App Store Connect, 2026)
You only need to upload the largest size for each device class; smaller sizes are
scaled automatically:
- **iPhone 6.9"** (e.g. iPhone 16 Pro Max) — 1320 × 2868 portrait
- **iPad 13"** (e.g. iPad Pro 13") — 2064 × 2752 portrait

## Recommended shot list (6)
1. **Main menu** — branding, rank badge + difficulty selector.
2. **Academy briefing** — a lesson card showing real phraseology (e.g. "Vectoring to Final").
3. **Mid-rush gameplay** — busy scope, a selected aircraft, command deck visible.
4. **Drag-to-vector** — the dashed heading vector being drawn from an aircraft.
5. **Emergency** — the red emergency banner with the countdown.
6. **Game over** — score breakdown with "NEW PERSONAL BEST" / "PROMOTED".

## Automated capture (recommended)
A UI test target already exists (`YouNeeKATCUITests`). To generate localized,
device-sized screenshots automatically:

```bash
# Capture from the Simulator with xcodebuild + a screenshot UI test, or use fastlane:
fastlane snapshot init
# add Snapshfile devices/languages, then:
fastlane snapshot
```

Manual fallback: run on a Simulator, set up each scene, then `Cmd+S` (Simulator ▸
File ▸ Save Screen). For App Previews (video), screen-record the Simulator and trim
to 15–30s.

## Tips
- Capture with **Reduce Motion off** so the radar sweep reads as motion.
- The dark scope looks best with the device in **light-independent** dark UI (the app
  forces dark mode, so this is automatic).
- Localize captures for `en`, `es`, `fr` to match the listed localizations.
