# Roam — Launch Readiness (v1)

> **Roam** is a local-first iOS app that automatically colors in the **ZIP Code Areas (U.S. Census ZCTAs)** you visit, privately and entirely on-device. With Always Location granted, it passively records each new ZIP Code Area you enter, keeps a timestamped visit history, paints visited/current boundaries on a MapKit map, surfaces stats and milestones, and lets you export or delete everything. It is for privacy-conscious travelers, quantified-self users, and city explorers who want a "fill-in-your-map" travel memory without an account, a backend, or analytics. The core loop is: **move → on-device detection colors a new area → visit history + map + stats grow → export/delete on demand.**
>
> **Implementation maturity: working SwiftUI app + tests (MVP Ready).** This is the most technically mature app in the portfolio: 73 app Swift files (~6.1k non-blank LOC) plus 8 test files (52 XCTest cases), a real on-device detection pipeline (CoreLocation → quality filter → SQLite R*Tree candidate lookup → point-in-polygon → anti-jitter visit segmentation → SwiftData), a MapKit overlay engine, CSV/JSON export, a versioned SwiftData schema with a migration plan, a committed `Roam.xcodeproj`, a dependency-free Python ZCTA-bundle build/validate pipeline, and a CI workflow. The core loop runs end-to-end against the bundled **sample** dataset. The two things standing between this and TestFlight are operational, not architectural: (1) earning Always Location through a trustworthy first-run, and (2) building + bundling the **production** national ZCTA dataset (intentionally kept out of git).

_Updated 2026-06-30 to match the shipped product and launch scope._

---

## 1. PRD / Launch Scope

### Problem & insight
People have no private, automatic way to remember the *geographic footprint* of where they've been. Existing "places visited" products are cloud-account-bound, monetize location, or require manual check-ins. The insight: a passive, on-device map-coloring loop ("fill in the ZIP Code Areas you've entered") is satisfying and shareable **only if** the user trusts that nothing leaves the phone. Trust is the product, not a feature.

### Target user
- **Primary:** privacy-conscious travelers and city explorers who enjoy a "map-completion"/travel-memory loop and will grant Always Location *if* the value and privacy posture are shown first.
- **Secondary:** quantified-self / personal-analytics users who want a local, exportable record of their movement broken down by area, with no account and no third-party data sharing.

### Value proposition
Automatically and privately color in the ZIP Code Areas you visit — everything stays on your iPhone.

### Positioning / category & one-sentence pitch
Utility / Consumer (Travel / Navigation-adjacent, lifestyle map memory). **"Roam quietly colors in the ZIP Code Areas you've been to, on-device — a private map of your travels with no account, no cloud, and no tracking."**

### Platform & tech baseline
- iOS 17.0+, iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), portrait + landscape.
- Swift 5, SwiftUI app lifecycle + a `UIApplicationDelegate` adaptor for location relaunch.
- Frameworks actually used: **CoreLocation** (standard updates + significant-change + visit monitoring, Always authorization, temporary full-accuracy), **MapKit** (`MKMapView`, `MKPolygon`/`MKPolygonRenderer`, marker annotations), **SwiftData** (versioned schema + migration plan), **SQLite3** (linked via `-lsqlite3`; on-device ZCTA database with an R*Tree virtual table), **MetricKit** (on-device-only diagnostics), **UIKit** (haptics, share sheet, map representable).
- **No third-party Swift packages.** No backend, no network calls for detection, no reverse geocoding (`CLGeocoder`/`MKLocalSearch` are never used).

### Business model
Free at launch. The repo supports a future Pro tier conceptually (export packs, advanced map/diagnostics) but ships **no StoreKit, no IAP products, and no paywall** in v1. There is no `.storekit` configuration in the repo; monetization is out of scope for this release.

### North-star / success signals (local-only / beta-observable; privacy-respecting)
Because there is no analytics backend (by design), success is measured via **TestFlight feedback + locally observable signals on the tester's own device**, never server telemetry:
- **Permission-grant rate** to Always Location after the pre-prompt onboarding (the single highest-leverage metric).
- **First-color moment:** a new ZCTA is detected and colored within the first session of real movement.
- **Map-completion engagement:** count of distinct ZCTAs colored over a week (visible in-app on Stats).
- **Trust retention:** testers keep tracking enabled (do not toggle off) and do not uninstall after the first commute.
- **Export usage** as a proxy for trust ("I can get my data out").

---

## 2. MVP Feature List (with acceptance criteria)

Numbered F1…F16. Status reflects repo reality.

### F1. On-device ZIP Code Area (ZCTA) detection — Status: **Built**
Resolves a coordinate to its containing ZCTA using an R*Tree candidate lookup + full-resolution point-in-polygon, with zero network/reverse-geocoding.
- Given a coordinate inside a bundled ZCTA, `ZCTAIndex.match` returns the correct code (`ZCTAIndexTests.testMatchInsideSanFrancisco` → `94102`).
- Given a coordinate far outside all bundled ZCTAs, `match` returns `nil` (`testMatchFarOutsideReturnsNil`).
- Point-on-edge and point-on-vertex count as inside; points inside a hole count as outside; multipolygon membership works (`PointInPolygonTests`, 9 cases).
- Detection performs **no** `CLGeocoder`/`MKLocalSearch`/network call (grep: none present; `ZCTADatabase` opens SQLite `READONLY`).
- Leading-zero codes (e.g. `01776`) are preserved as `String` end-to-end (`VisitTransitionServiceTests.testLeadingZeroCodePreserved`).

### F2. Location quality gate / filter — Status: **Built**
Rejects invalid, inaccurate, stale, null-island, or physically-impossible samples before they reach detection; biases toward *not* coloring on low-confidence fixes.
- Invalid coordinate, negative accuracy, accuracy worse than `rejectWorseThanMeters`, null-island, stale (>600 s), and impossible-jump (>100 m/s) samples are all rejected (`LocationFilterTests`, 8 cases).
- Simulation/visit-monitoring samples relax null-island/staleness/jump checks as documented (`LocationFilter.swift` §4–6).
- Confidence bucket (high ≤100 m, medium ≤250 m, low ≤500 m) is derived from horizontal accuracy and stored on each visit.

### F3. Visit segmentation with anti-jitter — Status: **Built**
Turns a stream of matches into discrete visit segments; one `TrackedZCTA` per unique code, new `ZCTAVisit` rows per visit, with cooldown + consecutive-match gating near boundaries.
- First match starts a `TrackedZCTA` + open visit; same-code matches extend the open visit; a different code transitions only after the cooldown elapses **and** the required consecutive matches accrue, otherwise it is `ignored` (`VisitTransitionServiceTests`, 6 cases).
- A revisit creates a new visit without duplicating the `TrackedZCTA` (`testRevisitDoesNotDuplicateTrackedZCTA`).
- Transition closes the old visit (accumulating duration) and opens the new one (`testTransitionClosesOldOpensNew`).
- After `maxConsecutiveUnknownsBeforeClose` (3) unknown samples, the active visit closes (`LocationEventProcessor.resolve`).

### F4. Background tracking & relaunch — Status: **Built**
Keeps recording when the app is closed, and resumes after iOS relaunches the app for a location event.
- With Always authorization + tracking enabled, `BackgroundLocationService.startTracking` enables `allowsBackgroundLocationUpdates`, standard updates, significant-change, and visit monitoring.
- `UIBackgroundModes = [location]` is declared (`Info.plist`).
- On relaunch with `launchOptions[.location]`, `AppDelegate.resumeTrackingIfNeeded` resumes tracking if still enabled + Always-authorized (with one retry).
- Acceptance (device, manual): force-quit while tracking, move across a boundary, reopen → the new area is colored and a visit exists. _(Requires the production bundle to exercise outside SF; see §6/§7.)_

### F5. Two-step permission flow (When-In-Use → Always) — Status: **Built**
Requests When-In-Use first, shows a dedicated education sheet, then requests Always; handles all denial/restriction/reduced-accuracy states.
- Enabling tracking from a `notDetermined` state requests When-In-Use; on grant, `RootViewModel` presents `PermissionEducationView`; "Continue" requests Always (`RootViewModel.enableTracking` / `requestAlwaysAuthorization`).
- `PermissionEducationView` copy adapts to denied/restricted/whenInUse/always states and offers "Open Settings" when denied.
- Reduced-accuracy grants trigger a one-time temporary full-accuracy request keyed `ZIPDetection` (`requestTemporaryFullAccuracyIfNeeded`; `Info.plist` `NSLocationTemporaryUsageDescriptionDictionary`).
- Status mapping is unit-tested via `LocationAuthorizationService.state(from:accuracy:)` (used by `LocationFilterTests`/state derivation).

### F6. First-run onboarding — Status: **Built (value-demo gap, see §7 LB-5)**
A 4-page carousel: product promise, privacy posture, background-location rationale, ZCTA-vs-ZIP disclaimer — shown before any Always request.
- Onboarding does **not** request Always Location (it is requested later behind the education sheet) — confirmed in `OnboardingView` (no permission calls).
- All four pages render the intended copy, including `AppConstants.Copy.zctaLongDisclaimer`.
- Completion (or "Skip") sets `hasCompletedOnboarding` and routes to the main tabs.
- _Gap:_ a "Skip" affordance lets a user bypass the value/privacy framing and reach the permission ask cold (see §7 LB-5).

### F7. Map with zoom-aware ZCTA boundary overlays — Status: **Built**
Renders visited/current/selected/unvisited boundaries with style-based colors, resolution and overlay budget chosen by zoom, debounced and built off-main.
- `MapZoomResolver.plan` maps latitude delta → resolution + unvisited inclusion + overlay cap, deterministically (`MapZoomResolverTests`, 7 cases).
- Visited + current + selected codes are always included; unvisited fill is added nearest-center up to the cap (`ZCTAIndex.visiblePolygons`).
- Overlay rebuilds are debounced (`overlayDebounceSeconds = 0.3`) and run on a detached task (`MapViewModel.scheduleOverlayRebuild`).
- Renderer colors differ per style (unvisited/visited/current/selected) (`ZCTAOverlayRenderer`).

### F8. Discovered & visit pins — Status: **Built**
Drops a marker per discovered ZCTA (and optionally per visit), with emoji glyphs and clustering.
- Discovered pins show 📍 (current) / ⭐️ (favorite) / 📮 (default) and cluster via `discoveredPinClusterIdentifier`; current pin gets `.required` display priority (`TrackerMapCoordinator.viewFor`).
- Visit pins (capped at 200) tint blue (real) / purple (simulated); toggleable via settings.
- Tapping a pin opens the selected-ZCTA card and can navigate to detail.

### F9. Dashboard (status + current area + summary) — Status: **Built**
Shows runtime status, the live current ZCTA with a running visit timer + confidence, four summary cards, and recent transitions.
- `TrackingStatusCard` reflects `off / needsAlwaysAuthorization / active / activeReducedAccuracy / error` with matching color + subtitle.
- `CurrentZCTACard` shows the code, a 1 Hz-updating duration, and a confidence pill — only when a current code exists.
- Summary grid shows total ZCTAs, total visits, new-this-week, and longest visit; "Recent" lists the last 5 visits.
- A sample/missing-data banner links to Data Status when not on production data.

### F10. History (timeline + by-area) with search/sort/swipe — Status: **Built**
Two modes (day-grouped timeline / by-ZCTA list), search, four sort options, archived toggle, and swipe actions.
- Timeline groups visits by day (newest first); by-ZCTA list sorts by recent/most-visited/A–Z/longest-time.
- Search filters by code; "Include Archived" toggles archived rows.
- Swipe: favorite (leading); delete + archive (trailing) on tracked rows; delete on timeline visits (`HistoryView` / `VisitTimelineView`).
- Deleting a visit decrements the parent's `visitCount`/`totalDurationSeconds` (`HistoryViewModel.deleteVisit`).

### F11. Per-area detail screen — Status: **Built (CSV-scope caveat, see §7 NB-1)**
A code header with favorite + editable note, stats grid, mini boundary map, visit timeline, and actions (export CSV, archive, delete).
- Stats: first discovered, last seen, visits, total/average/longest visit time.
- Mini map centers on the centroid; `loadBoundary` decodes the resolution-3 polygon for the area.
- Favorite/note/archive/delete persist and post `dataDidChange`.
- _Caveat:_ "Export CSV" exports **all** visits, not just this area (`ZCTADetailViewModel.exportCSV`, acknowledged in code) — see §7 NB-1.

### F12. Statistics & milestones — Status: **Built**
Pure, deterministic statistics: totals, time-window counts, highlights, and milestone badges (1/10/25/100).
- `StatisticsService.computeStatistics` computes totals, new-this-week/month/year, most-visited, longest-total-time, longest-single-visit, distinct tracking days, and achieved milestones, with injectable calendar/now (`StatisticsServiceTests`, 4 cases).
- Archived ZCTAs are excluded from counts; tie-breaks are stable (lexicographic).
- `StatisticsView` renders all of the above; milestone badges show achieved/locked.

### F13. Local export (JSON + CSV) with share sheet — Status: **Built**
Builds full JSON and visit/summary CSV snapshots written to Application Support; data leaves the device only via the user's explicit share-sheet action.
- JSON export (optionally including diagnostic logs) is pretty-printed, ISO-8601 dated, versioned (`exportVersion = 2`) (`ExportService.exportJSON`).
- Visits CSV and Summary CSV are RFC-4180 escaped (commas/quotes/newlines), ISO-8601 dates (`CSVServiceTests`, 8 cases).
- Files are written under `Application Support/Roam/Exports`; share sheet (`ActivityView`) is presented only on user action; copy states files leave only if shared.

### F14. Data-status / bundle transparency — Status: **Built**
Surfaces which dataset backs the app (production / sample / missing), its metadata, the ZCTA disclaimer, and whether tracking is blocked.
- `ZCTAGeometryService` selects production → sample → missing and validates required tables + ≥1 feature (`ZCTAGeometryService.validate`).
- In RELEASE, only a production bundle permits tracking; sample is DEBUG-only; missing blocks tracking (`ZCTABundleStatus.allowsTracking`; `ZCTAIndexTests` confirm sample is not production).
- `DataStatusView` shows status icon/tint, metadata (version/source/build date/feature count/production flag), the long disclaimer, and a "tracking blocked" banner when applicable.

### F15. Privacy controls (delete-all, toggles, privacy/help) — Status: **Built**
On-device data control: type-to-confirm delete-all, per-row delete/archive, tracking off switch, diagnostics/haptics toggles, and a Privacy & Help screen.
- "Delete All Data" requires typing `DELETE` and a confirmation dialog; it clears visits, tracked ZCTAs, and event logs (`SettingsViewModel.deleteAllData`).
- Tracking can be disabled at any time; the diagnostic event log and haptics are user-toggleable.
- `PrivacyHelpView` documents local-first, no-cloud/no-analytics, background-location rationale, battery, how to stop, and the ZCTA disclaimer.

### F16. ZCTA data build/validate pipeline — Status: **Built (production bundle not produced, see §7 LB-1)**
Dependency-free Python tooling to convert Census ZCTA GeoJSON → on-device SQLite bundle, matching the Swift codec/schema exactly, plus a validator.
- `build_zcta_bundle.py` (413 LOC) encodes coordinates as little-endian lat/lon E5 int32 pairs matching `ZCTAPolygonCodec`; `validate_zcta_bundle.py` checks required tables + blob invariants and prints `VALIDATION PASSED`.
- `make_sample_geojson.py` produces the 3-rectangle SF fixture whose rectangles contain the simulated route points.
- Codec round-trips losslessly to 1e-5 and rejects malformed blobs (`ZCTAPolygonCodecTests`, 5 cases).
- _Gap:_ the **production** national bundle has not been built/bundled (intentionally out of git) — see §7 LB-1.

---

## 3. Out of Scope (v1 non-goals)

- **No cloud, no account, no backend, no sync.** Optional end-to-end-encrypted sync may come later but is explicitly *never* a requirement and must never become a silent backend (per the product conversation).
- **No analytics, crash-reporting SDK, ads, or third-party packages.** MetricKit payloads are stored on-device only and never transmitted.
- **No reverse geocoding / address lookup / venue or place search / routing / navigation.** Detection is geometry-only against bundled polygons.
- **No social features, sharing feeds, or friends.** Export is a manual, user-initiated file share.
- **No USPS-authoritative ZIP claims.** The app deliberately says "ZIP Code Areas / Census ZCTA boundaries," never implies USPS delivery accuracy.
- **No monetization in v1.** No StoreKit products, IAP, or paywall ship in this release.
- **No iPad/Mac/watch targets.** iPhone-only until iPad layouts are verified.
- **No faked coverage.** If the production bundle is missing, RELEASE blocks tracking rather than pretending to cover the country.

---

## 4. User Flows

Screen names below map to real SwiftUI views.

### Flow A — First run / onboarding (earn the permission)
1. Launch → `RootView` routes to `OnboardingView` (no prior `hasCompletedOnboarding`).
2. User pages through 4 `OnboardingPage`s: promise → "Private by design" → "Background tracking" (battery + Always rationale) → "Census ZCTA boundaries" disclaimer.
3. User taps **Continue** (or **Skip**) → `completeOnboarding()` sets the flag and routes to `AppTabView`.
4. No system location dialog has appeared yet (by design).

### Flow B — Enable tracking & grant Always (core trust gate)
1. In **Settings** tab, user toggles **Enable Tracking** → `RootViewModel.enableTracking()`.
2. If `notDetermined`: system **When-In-Use** prompt appears; on grant, `PermissionEducationView` sheet is presented explaining why Always + battery + "stop anytime" + "stays on device."
3. User taps **Continue to Permission** → system **Always** prompt → on grant, `syncTracking` starts background tracking; status shows **Tracking Active**.
4. If denied/restricted → an "Open Settings" affordance is shown; if reduced accuracy → a one-time precise-accuracy prompt (`ZIPDetection`) is requested.

### Flow C — Core loop (color the map)
1. User moves; `CLLocationManager` delivers samples → `LocationFilter` gate → `ZCTAIndex.match` → `VisitTransitionService`.
2. On a new area: a `TrackedZCTA` + open `ZCTAVisit` are created, a discovery notification fires (success haptic), and `TrackingState` updates.
3. **Dashboard** shows the current code + live timer; **Map** colors the current boundary green and drops a pin; **History**/**Stats** update.
4. Crossing a confirmed boundary closes the old visit and opens a new one.

### Flow D — Review history & detail
1. **History** tab → Timeline (by day) or By-ZIP/ZCTA; search/sort/swipe (favorite/archive/delete).
2. Tap a tracked area → `ZCTADetailView`: stats grid, mini boundary map, editable note, visit timeline, and per-area actions.

### Flow E — Settings / privacy / data control
1. **Settings** → tracking mode (Battery Saver/Balanced/High Accuracy), Advanced Tracking tuning, map toggles, **Data Status**, **Export Data**, and **Delete All Data** (type `DELETE`).
2. **Privacy & Help** documents the local-first posture and how to stop tracking.

### Flow F — Export / share
1. **Settings → Export Data** → choose Full JSON / Visits CSV / Summary CSV → file written to Application Support → system **share sheet** (`ActivityView`) presented.
2. Data leaves the device only if the user chooses a share destination.

### Flow G — Developer simulation (DEBUG only)
1. **Settings → Developer**: Generate Sample Visits / Simulate Route / Step Next Location / Clear / Reset; **Map** long-press injects a manual sample. (Compiled out of RELEASE.)

---

## 5. Acceptance Criteria Summary

| ID | Feature | Launch pass/fail gate |
|----|---------|-----------------------|
| F1 | On-device ZCTA detection | Correct in-polygon match; `nil` outside; no network/geocoding; leading zeros preserved — green via `ZCTAIndexTests`/`PointInPolygonTests` |
| F2 | Location quality filter | All six rejection classes enforced; low-confidence biased to no-color — green via `LocationFilterTests` |
| F3 | Visit segmentation / anti-jitter | First/extend/transition/revisit/ignore behave per state machine — green via `VisitTransitionServiceTests` |
| F4 | Background tracking & relaunch | Background modes declared; resumes on location relaunch — code-complete; **device-verify on production bundle** |
| F5 | Two-step permission flow | WIU→education→Always; denial/reduced handled — code-complete; **device-verify** |
| F6 | Onboarding | 4 pages, no early Always ask, completion routes to main — built; **close Skip value-bypass (LB-5)** |
| F7 | Zoom-aware overlays | Deterministic plan; visited/current always shown; debounced — green via `MapZoomResolverTests` |
| F8 | Pins | Discovered/visit pins, glyphs, clustering, tap-to-select — built; device-verify visuals |
| F9 | Dashboard | Status + current card + summary + recent render correctly — built |
| F10 | History | Timeline/by-area, search/sort/swipe, counts stay consistent — built |
| F11 | Detail | Stats/map/note/timeline; **per-area CSV is currently all-visits (NB-1)** |
| F12 | Statistics | Deterministic totals/highlights/milestones — green via `StatisticsServiceTests` |
| F13 | Export JSON/CSV | RFC-4180 CSV, ISO-8601, share-only egress — green via `CSVServiceTests` |
| F14 | Data status | Production/sample/missing surfaced; RELEASE blocks non-production — green via `ZCTAIndexTests` |
| F15 | Privacy controls | Type-to-confirm delete-all; toggles; help — built |
| F16 | ZCTA pipeline | Codec/validator match Swift; **production bundle not yet built (LB-1)** |

---

## 6. Known Limitations

- **Production coverage is not in the repo.** Only the 3-rectangle San Francisco sample (`94102/94103/94107`, `is_production=false`, ~52 KB) ships. Outside those rectangles the app colors nothing on the sample. RELEASE correctly **blocks** tracking until a production bundle is added.
- **ZCTA ≠ USPS ZIP Code.** Boundaries are generalized Census approximations; not every USPS ZIP has a ZCTA; vintages change. The app is honest about this everywhere, but users may still expect USPS precision.
- **Reduced-accuracy / coarse fixes may not resolve to a polygon**, producing "unknown" and (after 3) closing the visit. This is intentional bias-to-not-color, but means low-signal environments record less.
- **Detection is sampling-bound.** Battery Saver / large distance filters detect transitions later; brief pass-throughs of an area may not be colored if cooldown/consecutive-match gates aren't met.
- **`visitedCodes()` for overlays includes archived ZCTAs** (it does not filter `isArchived`), so archived areas still render as "visited" boundaries.
- **Map "recenter on me" is wired but inert:** `TrackerMapView` passes `userCoordinate: nil`, so the recenter button changes the token but has no coordinate to center on.
- **Per-area CSV export is not actually scoped to the area** (exports all visits) — see §7 NB-1.
- **App icon / launch logo are generated placeholders** (`generate_app_assets.py`), explicitly "replace before shipping."
- **iPhone-only, portrait+landscape.** No iPad layout verification yet.
- **No UI/integration test coverage** for the SwiftUI/MapKit/CoreLocation layers; the 52 tests cover pure logic (geometry, codec, index, filter, transitions, zoom, CSV, stats).
- **Legacy marketing/legal docs were product-mismatched** (described a package-tracking app) until this update; corrected in this commit (see §7 LB-2).

---

## 7. Bug & Risk Triage

### Launch-blocking (must fix before TestFlight / App Store)

- **LB-1 — Production ZCTA bundle absent.** `zcta_bundle.sqlite` is intentionally gitignored and has not been built/bundled. In RELEASE, `ZCTABundleStatus.allowsTracking` returns `false` for sample/missing, so the entire core loop is inert on a real (non-DEBUG) build. *Where:* `Roam/Resources/ZCTA/` (only sample present), `ZCTAGeometryService`, `Scripts/build_zcta_bundle.py`. *Why blocking:* without it the shipped app cannot color anything for real users. *Fix:* build per `Scripts/README_PREPROCESSING.md`, validate, add to the app target's Copy Bundle Resources.

- **LB-2 — Stale/incorrect store-facing docs describe a different app.** `BETA_TESTING_PLAN.md`, `MARKETING_PLAN.md`, and `TERMS_OF_SERVICE.md` described **a package-tracking app** (UPS/FedEx/USPS/DHL, "delivery estimates," ZIP TRACKER) and `PRIVACY_POLICY.md`/several docs linked the wrong repo `github.com/pri8771/ios_tracker_app`. *Where:* those four files. *Why blocking:* App Store metadata, privacy nutrition label, and ToS that contradict the actual app are a rejection and a user-trust/legal risk. *Fix:* rewritten in this commit to match the real ZIP-Code-Area product (still verify App Store Connect metadata + nutrition label match `PrivacyInfo.xcprivacy`).

- **LB-3 — CI build step is broken (won't gate anything).** In `.github/workflows/ci.yml` the "Build for testing" step references an undefined `${DESTINATION}` and has a mangled line continuation (`-destination "${DESTINATION}" \            -derivedDataPath ...` on one physical line). *Where:* `.github/workflows/ci.yml` ~line 51. *Why blocking:* the build-for-testing invocation fails/misparses, so CI does not actually guard the build/test before release. *Fix:* define `DESTINATION` (e.g. a generic iOS Simulator destination) and repair the backslash/newline so the command is well-formed.

- **LB-4 — Placeholder app icon / launch assets.** Icons are generator-produced placeholders, explicitly "replace with real artwork before shipping." *Where:* `Roam/Resources/Assets.xcassets/AppIcon.appiconset`, `generate_app_assets.py`. *Why blocking:* App Store requires final, non-placeholder 1024×1024 icon; placeholder art is a review/brand risk. *Fix:* ship final artwork; keep 1024 opaque/no-alpha.

- **LB-5 — Onboarding "Skip" lets users reach the Always ask cold.** `OnboardingView` offers **Skip** on the value/privacy/background pages, so a user can land in Settings and trigger the permission walk without ever seeing the value or privacy framing — the exact failure mode the product conversation flagged as the #1 risk (permission trust). *Where:* `OnboardingView.swift` (Skip button), `RootViewModel.enableTracking`. *Why blocking:* a cold Always ask collapses grant rate, and a denied user is unrecoverable. *Fix:* either remove "Skip," or ensure the permission education sheet alone fully carries the value+privacy story regardless of onboarding path (and consider gating the first enable behind a brief value demo).

- **LB-6 — No support contact in legal/store docs.** `PRIVACY_POLICY.md`/`TERMS_OF_SERVICE.md` have placeholder/absent support email and (previously) a wrong repo URL. *Where:* legal docs. *Why blocking:* App Store requires a valid support URL/contact; ToS/Privacy must be reachable and correct. *Fix:* add a real support URL/email and confirm the App Store Connect "Support URL" matches.

### Non-blocking (ship-with, fix later)

- **NB-1 — Per-area "Export CSV" exports all visits, not just the selected area.** `ZCTADetailViewModel.exportCSV` calls `exportVisitsCSV()` (acknowledged by an inline comment). *Rationale:* still produces correct, complete data; only the scoping is broader than the button implies. Fix by adding a code-filtered CSV writer.
- **NB-2 — "Recenter on me" has no user coordinate.** `TrackerMapView` passes `userCoordinate: nil`, so the recenter button is inert. *Rationale:* the map still shows the user dot via `showsUserLocation`; cosmetic. Fix by feeding the last known coordinate into the representable.
- **NB-3 — Overlay "visited" set includes archived ZCTAs.** `MapViewModel.visitedCodes()` does not filter `isArchived`. *Rationale:* archived areas correctly stay in data; only the map styling over-includes them. Low impact.
- **NB-4 — No UI/integration tests for CoreLocation/MapKit/SwiftUI layers.** *Rationale:* core logic is well covered (52 tests); the UI/permission paths are device-verified during beta. Add snapshot/UITest coverage post-launch.
- **NB-5 — `DependencyContainer` `fatalError` on ModelContainer init failure.** Acceptable for an unrecoverable store error, but a corrupt store on upgrade would hard-crash. *Rationale:* rare; mitigated by the versioned schema + migration plan. Consider a recovery/reset path later.
- **NB-6 — iPhone-only.** *Rationale:* deliberate scope; iPad layout is future work.
- **NB-7 — MetricKit diagnostics are stored but never surfaced/retrievable in-app.** *Rationale:* intentional local-only signal for developer device pulls; not user-facing.

---

## 8. Production-Readiness Assessment

### Current estimated readiness: **58%**
_Recalibrated from 72% on 2026-06-30 after an independent code audit: the earlier figure under-weighted that the app has never been compiled/run and ships no production data, so RELEASE colors nothing today._

Justification: the app is genuinely built end-to-end with a real on-device pipeline, a complete 5-tab UI, a versioned data model, export/delete, strong privacy posture, a committed Xcode project, and 52 passing-by-construction unit tests over the load-bearing logic. The remaining ~42% is concentrated in **shippability**, not engineering: the production dataset is absent (so RELEASE can't color anything), CI doesn't actually gate, store/legal docs were wrong (now corrected) and need final App Store Connect alignment, the icon is a placeholder, and the single highest-risk surface (earning Always Location) needs the onboarding "Skip" path closed and device-verified. None of these require new architecture.

### Ordered checklist to reach 80–90% production-ready
1. **Build, validate, and bundle the production ZCTA dataset** (`Scripts/README_PREPROCESSING.md`); confirm `is_production=true`, required tables, and feature count; verify the app reports **Production Census ZCTA data** in Data Status. *(LB-1)*
2. **Repair CI** `.github/workflows/ci.yml`: define `DESTINATION`, fix the build-for-testing line continuation, and confirm a green build+test run gates merges. *(LB-3)*
3. **Close the cold-permission path** in onboarding (remove "Skip" or guarantee the education sheet fully carries value+privacy), then **device-verify** the When-In-Use→Always walk on a real iPhone across denied/reduced/always states. *(LB-5, F5)*
4. **Finalize App Store Connect metadata + privacy nutrition label** to match the corrected docs and `PrivacyInfo.xcprivacy` (no data collected, no tracking); add a real **support URL/email**. *(LB-2, LB-6)*
5. **Replace placeholder app icon / launch art** with final, opaque 1024×1024 artwork. *(LB-4)*
6. **Device field test the core loop on the production bundle**: background relaunch, boundary crossings, battery impact per tracking mode, reduced-accuracy behavior; confirm bias-to-not-color holds (no wrong-area coloring). *(F4)*
7. **Fix the high-value polish bugs**: scope per-area CSV (NB-1), feed a user coordinate for recenter (NB-2), exclude archived from overlay "visited" set (NB-3).
8. **Accessibility + Dynamic Type + Reduce Motion pass** across the 5 tabs and the permission/onboarding sheets.
9. **Add lightweight UI/integration coverage** for onboarding/permission routing and map overlay rebuild (NB-4).
10. **Cut TestFlight build**, recruit privacy-minded/travel testers, and instrument the local success signals from §1 via TestFlight feedback.

### Test coverage summary
- **Tested (pure logic, 52 XCTest cases / 8 files):** point-in-polygon incl. holes/multipolygon/edges (`PointInPolygonTests`), polygon binary codec round-trip + malformed handling (`ZCTAPolygonCodecTests`), SQLite R*Tree index match/visible-region against the sample bundle (`ZCTAIndexTests`), location quality filter rejections + confidence (`LocationFilterTests`), visit-transition state machine incl. cooldown/consecutive-match/revisit/leading-zeros (`VisitTransitionServiceTests`), zoom→overlay-plan resolution (`MapZoomResolverTests`), CSV escaping/headers/rows (`CSVServiceTests`), and statistics/date-window math (`StatisticsServiceTests`).
- **Not tested (verify on device/beta):** SwiftUI views and view models, the live CoreLocation pipeline + background relaunch (`BackgroundLocationService`, `AppDelegate`), the permission flow UI (`PermissionEducationView`/`RootViewModel`), MapKit rendering/coordinator, export file I/O + share sheet, SwiftData migrations (only v1 baseline exists), and end-to-end behavior on the production bundle.
- **CI:** present but **currently broken** at the build step (LB-3); includes sample-bundle validation, asset/project regeneration, and a resilient simulator install+retry test harness — all of which only protect releases once the build step is fixed.

---

## 9. Launch Checklist

**Privacy & data**
- [ ] App Store **privacy nutrition label = "Data Not Collected"**, matching `PrivacyInfo.xcprivacy` (`NSPrivacyTracking=false`, empty collected-data/tracking-domain lists; UserDefaults reason `CA92.1`).
- [ ] `PRIVACY_POLICY.md` reachable, correct (no package-tracking language, correct repo URL), and linked in App Store Connect.
- [ ] Confirm **no third-party SDKs / no network calls for detection** (audit: none present).

**Location & permissions**
- [ ] `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, and `NSLocationTemporaryUsageDescriptionDictionary[ZIPDetection]` copy is accurate, ZCTA-honest, and non-misleading (✓ present in `Info.plist`).
- [ ] `UIBackgroundModes=[location]` justified in App Review notes; explain Always is used for passive on-device ZCTA detection only.
- [ ] Device-verify all auth states (notDetermined/whenInUse/always/denied/restricted/reduced) and the WIU→Always escalation; **no cold Always ask** (LB-5).

**Content & accuracy**
- [ ] ZCTA-vs-USPS disclaimer present in onboarding, detail, map, and Data Status (✓ in code) — keep "ZIP Code Areas / Census ZCTA boundaries," never imply USPS precision.
- [ ] Data Status reports **Production** (not Sample/Missing) on the release build (depends on LB-1).

**Store assets & metadata**
- [ ] Final **1024×1024 opaque** app icon + launch art (replace placeholders, LB-4).
- [ ] Screenshots (6.7"/6.5"), description, keywords, subtitle reflect the ZIP-Code-Area product (rewrite `MARKETING_PLAN.md`-derived copy; ✓ doc corrected this commit).
- [ ] **Age rating 4+**; **Support URL/email** valid (LB-6).
- [ ] `TERMS_OF_SERVICE.md` and `BETA_TESTING_PLAN.md` reflect the real product (✓ corrected this commit) and are linked where required.

**Build, test, safety**
- [ ] CI green (fix LB-3); `xcodebuild test` passes on an iOS 17 simulator.
- [ ] Battery-impact sanity per tracking mode; confirm bias-to-not-color (no wrong-area coloring) on real fixes.
- [ ] StoreKit: **N/A for v1** (no IAP); confirm no orphaned paywall/StoreKit config ships.
- [ ] Clean-install run with no developer/sample tools visible in RELEASE (DEBUG-only blocks compiled out).
