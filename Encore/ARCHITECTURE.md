# Encore — Architecture (Flow A)

> The taste-driven recommendation flow. This doc is the decided architecture for
> the "how does it actually run" question. TL;DR: **no backend. On-device store +
> background ingestion.**

## The core loop

```
Apple Music (MusicKit)  ──poll──►  TasteStore (on-device DB)  ──►  RecommendationEngine
   heavy-rotation                   - KnownArtists baseline          matches taste
   recent/played                    - timestamped observations       against District
   music-summaries                  - derived TasteProfile           inventory
   recommendations                                                        │
                                                                          ▼
                              EntityResolver (Apple artist ⇆ District artist)
                                                                          │
                                                                          ▼
                        Match found ──► local notification (+ Apple Watch)
                                   └──► District deep link (book ticket)
                                          │
                                          ▼  opt-in ecosystem
                        Blinkit (before leaving) ──► Zomato/Bistro (after) 
                        via Live Activity + App Intents + push
```

## Why no backend

| Concern | On-device answer |
|---|---|
| "User is busy, never opens the app" | `BGAppRefreshTask` / `BGProcessingTask` — iOS wakes the app in the background to poll + match. Match → local notification. |
| Apple gives no timestamps | **We become the clock.** Each background poll diffs the new `recent/played` vs the stored snapshot; newly-seen artists get a `firstSeenAt` stamped with *device* time. |
| No "newly discovered" endpoint | Velocity: unknown artist crossing ~15% of plays in a 72h window = high-confidence discovery. Computed over our own timestamped log. |
| Auth / Music-User-Token | MusicKit auto-attaches the token on-device. A server would need the token exported off-device — more complex + less private. |

A backend is a **production scaling** option (guaranteed cadence, cross-user analytics), never a correctness requirement. The prototype and v1 are 100% on-device.

## Layers (files)

- `Models/` — data contract (`TasteProfile`, `Event`, `OccasionPlan`, …).
- `Sources/` — `MusicSource` / `EventsSource` / `FoodSource` protocols. Impls:
  - `HardcodedMusicSource` (demo persona — **default**).
  - `MusicKitMusicSource` (real Apple Music; token plugged in later this week).
- `Persistence/TasteStore` — the **on-device "backend"**: KnownArtists baseline,
  timestamped observation log, derived `TasteProfile`, feedback deltas. Codable
  JSON snapshot now; SwiftData is the drop-in upgrade.
- `Ingestion/TasteIngestionService` — one poll cycle: pull raw signals from the
  `MusicSource`, feed `TasteStore` (diff + stamp + velocity), recompute profile.
  Called from foreground refresh AND from the `BGAppRefreshTask` handler.
- `Matching/EntityResolver` — Apple artistName/genre ⇆ District inventory.
- `Engine/RecommendationEngine` — transparent weighted scoring (no ML).
- `Store/EncoreStore` — `@Observable` UI source of truth; owns the sources +
  services + current shortlist/plan.

## Data Ingestion Matrix (endpoint → intent weight)

| Endpoint | Signal | Weight | Use |
|---|---|---|---|
| `v1/me/music-summaries` (Replay) | ranked top artists | Very High | direct match, pre-sale push |
| `v1/me/history/heavy-rotation` | on-repeat | High | headline-show match |
| `v1/me/recent/played/tracks` | chronological | Medium | genre clustering + discovery velocity |
| `v1/me/recommendations` | algorithmic | Low | Explore tab only, never push |

## Demo vs live

- **Demo (now):** `HardcodedMusicSource` persona + hardcoded District events. No
  accounts needed. Everything below the `MusicSource` seam is identical to live.
- **Live (later):** flip the source to `MusicKitMusicSource` once the paid Apple
  Developer account + MusicKit key land. Human adds the capability + Info.plist
  `NSAppleMusicUsageDescription` + `BGTaskSchedulerPermittedIdentifiers`
  (`com.encore.refresh`). Nothing else changes.

## Human-owned setup (not code)

- Apple Developer Program + MusicKit capability & key.
- Info.plist: `NSAppleMusicUsageDescription`, `NSCalendarsWriteOnlyAccessUsageDescription`,
  `NSUserNotificationsUsageDescription`, background modes (fetch + processing),
  `BGTaskSchedulerPermittedIdentifiers = ["com.encore.refresh"]`.
```
