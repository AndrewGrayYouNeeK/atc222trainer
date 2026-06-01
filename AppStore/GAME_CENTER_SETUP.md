# Game Center setup (App Store Connect)

The app code references these identifiers in `Services/GameCenterManager.swift`.
Create them under **App Store Connect ▸ your app ▸ Features ▸ Game Center** with the
exact IDs below, or the submissions will silently no-op.

## Leaderboards (Classic, higher is better, integer scores)
| Leaderboard reference name | Leaderboard ID            | Notes                    |
|----------------------------|---------------------------|--------------------------|
| Apex Score — Relaxed       | `apex.score.relaxed`      | Per-difficulty board     |
| Apex Score — Standard      | `apex.score.standard`     | Per-difficulty board     |
| Apex Score — Intense       | `apex.score.intense`      | Per-difficulty board     |
| Apex Score — All-Time      | `apex.score.alltime`      | Receives every run       |

- Score format: **Integer**. Sort order: **High to Low**.

## Achievements
| Reference name        | Achievement ID                 | Points | Trigger (in code)                         |
|-----------------------|--------------------------------|--------|-------------------------------------------|
| First Landing         | `apex.ach.first_landing`       | 5      | First successful arrival, ever            |
| On a Roll             | `apex.ach.streak_10`           | 15     | Reach a ×10 streak in one run             |
| Five Grand            | `apex.ach.score_5000`          | 20     | Score 5,000 in a run (progress reported)  |
| Fifteen Grand         | `apex.ach.score_15000`         | 30     | Score 15,000 in a run (progress reported) |
| Emergency Ace         | `apex.ach.emergency_ace`       | 25     | Handle 10 emergencies lifetime            |
| Century Club          | `apex.ach.century_landings`    | 25     | 100 lifetime landings                     |

`apex.ach.score_5000`, `apex.ach.score_15000`, `apex.ach.emergency_ace`, and
`apex.ach.century_landings` are reported with partial `percentComplete`, so mark
them as showing progress in App Store Connect.

## Entitlement
`YouNeeKATC/YouNeeKATC.entitlements` already declares
`com.apple.developer.game-center`. In Xcode, also add the **Game Center**
capability to the target so the provisioning profile includes it.

## Testing
Use a sandbox Game Center account on device. The first launch presents Apple's
sign-in; afterwards `GameCenterManager.authenticate()` resolves silently.
