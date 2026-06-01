# Apex Control — App Store Connect Metadata

Copy-paste source for the App Store Connect listing. Bundle ID: `com.andrew.YouNeeKATC`.

## Name & subtitle
- **App Name:** Apex Control
- **Subtitle (30 char max):** Radar air traffic controller

## Promotional text (170 char)
Take the scope. Vector arrivals to the runway, climb departures out, and keep every aircraft safely separated as the rush builds. How long can you hold the line?

## Description
You are the approach controller. Aircraft stream into your airspace from every direction — your job is to keep them apart and guide each one home.

Start in the Academy: a real controller-training pipeline that teaches genuine ATC — separation standards, vectoring to final, sequencing, departures and emergencies — with authentic phraseology. Pass the certification check ride and you're cleared into live traffic, where you climb the ranks shift after shift.

Command your traffic by VOICE, just like a real controller — hold the transmit button and say “Delta 482, descend and maintain 3000, cleared to land.” Prefer touch? Tap an aircraft and drag a heading, or use the command deck. Use either, anytime. Line arrivals up with the runway and clear them to land. Climb departures out to their fix. Build streaks of clean handoffs for bonus points — but lose separation and the shift is over.

• A real training Academy: learn actual ATC — separation, vectoring, sequencing, departures, emergencies — then pass a certification check ride to unlock live play
• Climb the ranks: career progression from Trainee to TRACON Legend
• Speak real ATC phraseology — on-device speech recognition with authentic pilot read-back
• Push-to-talk or hands-free (your choice in Settings); audio never leaves your device
• Authentic phosphor-green radar scope with sweep, range rings and live data blocks
• Intuitive touch control too: drag-to-vector, a heading dial, and altitude/speed steppers
• Three difficulties that ramp from a relaxed warm-up to a relentless rush
• In-flight emergencies that demand priority handling
• Game Center leaderboards and achievements
• A hands-on interactive tutorial — learn by doing in under a minute
• Fully playable with VoiceOver, a colour-blind palette, and Reduce Motion support
• No ads, no tracking, no in-app purchases. Just you and the traffic.

## Keywords (100 char, comma-separated)
atc,air traffic,voice,control,radar,airport,airplane,flight,controller,approach,tower,vector,training

## What's New (v1.0)
Initial release. Take the scope and keep the skies safe.

## URLs
- **Support URL:** https://apexcontrol.example/support
- **Marketing URL:** https://apexcontrol.example
- **Privacy Policy URL:** https://apexcontrol.example/privacy  (text mirrored in-app and in `AppStore/PRIVACY_POLICY.md`)

## Category
- **Primary:** Games → Simulation
- **Secondary:** Games → Strategy

## Age rating
4+ — no objectionable content, no data collection, no purchases.

## App privacy ("nutrition label")
Select **Data Not Collected**. The app has no analytics, no ads, no third-party SDKs. Game Center is Apple-provided; declare it only if you treat Game Center identifiers as collected (typically not required since data stays with Apple).

**Microphone / voice:** the app requests microphone + speech recognition for optional voice control, but uses **on-device** recognition — audio is not recorded, stored, or transmitted — so it remains "Data Not Collected." Be ready to explain this in App Review notes (see below). The usage-description strings are set in the project (`INFOPLIST_KEY_NSMicrophoneUsageDescription`, `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription`).

## App Review notes (paste into "Notes for Reviewer")
Voice control is optional and uses on-device speech recognition only; no audio leaves the device and nothing is recorded. To test: Settings ▸ Voice control (on by default) ▸ start a game ▸ hold the mic button and say e.g. "Delta 482, turn left heading 270, descend and maintain 3000." The game is fully playable by touch if microphone permission is declined.

## In-App Purchases
**None.** This is a free, fully unlocked game with no monetization hooks, which keeps the review surface minimal and the experience clean. If monetization is desired later, the recommended path is a single non-consumable "Apex Pro" unlock (extra airports/difficulties) via StoreKit 2 — no consumables, no subscriptions. Not implemented in v1.0 by design.

## Build settings of note
- Marketing version `1.0`, build `1` (see `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`).
- Game Center capability enabled via `YouNeeKATC.entitlements` (`com.apple.developer.game-center`).
- Localizations: English (base), Spanish, French (see `Localizable.xcstrings`).
