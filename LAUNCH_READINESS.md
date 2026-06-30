# Roam — Launch Readiness

_Last reviewed: 2026-06-30 · Scope version: `v1.0-launch-scope`_

Roam is a local-first iOS app that automatically colors in the **ZIP Code Areas**
(U.S. Census ZCTAs) you visit and lets you share a private snapshot of your
travels. Everything stays on device — no account, no cloud, no analytics.

> **Launch story:** _"Your travels, colored in automatically and privately."_
> Lead with travel + privacy, not GIS terminology.

---

## 1. Product scope (v1.0)

**The loop:** you move → Roam detects the ZIP Code Area you're in (on-device,
against a bundled Census ZCTA database) → it colors the patch on your map → your
Progress fills up → you share a privacy-safe coverage card. Collection-completion
is the hook; statistics and history are supporting layers.

### In scope
- Passive, on-device ZIP/ZCTA detection (CoreLocation → filter → R*Tree + point-in-polygon → visit segmentation → SwiftData).
- Map coloring with brand overlays (visited = coral, current = teal, selected = indigo).
- **Auto-color confidence gate** — only high-confidence, boundary-clear fixes color a patch (see §4).
- **Progress / completion** — coverage rollups: ZIP-area count, states touched, % of 50 states, per-state estimated coverage, milestones.
- **Shareable coverage card** — one-tap, location-abstracted image (state-level only).
- Pre-permission onboarding (value + privacy first), When-In-Use → Always escalation, graceful limited mode on denial.
- "Stored on this device" trust surface; export (JSON/CSV) and delete-all.
- **Roam Plus** — one-time unlock (StoreKit 2) for the full state breakdown. Core loop, share, and export stay free.

### Out of scope (v1)
Cloud sync / accounts / backend · social features · routing / navigation · venue
search · ads / data sale · subscriptions · Android / iPad · nationwide
guaranteed coverage (beta ships a labeled limited dataset).

---

## 2. Key user flows
1. **First run** → 4-page value+privacy onboarding → "Turn on Roam" → When-In-Use prompt → current area colors in (first win) → Always education sheet → background tracking. "Maybe later" leaves a fully usable app.
2. **Passive collection** → app closed → iOS relaunches on location events → new ZIP areas colored, haptic on discovery.
3. **Progress** → ring + counts + coverage-by-state → "Share my map" → system share sheet with the abstracted card.
4. **Trust** → Settings → "Stored only on this iPhone" → Export / Delete All.

## 3. Per-feature acceptance criteria (high level)
- Detection never colors on fixes worse than **100 m** horizontal accuracy, or within `max(25 m, accuracy)` of a ZCTA boundary. ✔ unit-tested (`AutoColorGateTests`, `BoundaryDistanceTests`).
- State rollups resolve correctly from ZIP prefixes incl. leading zeros. ✔ (`USStateResolverTests`, `CoverageServiceTests`).
- Open-visit lookups never crash SwiftData. ✔ (predicate-free fetch; `VisitTransitionServiceTests`).
- Share card renders state-level data only — no map, coordinates, or per-city ZIP polygons. ✔ by construction (`ShareCardView`).
- App fills the screen and requests location without crashing. ✔ (Info.plist launch screen + usage strings — see §5).

## 4. The accuracy / privacy guarantees (load-bearing)
- **100 m auto-color gate + boundary margin** — `AutoColorGate`. A wrong patch erodes trust faster than a missing one, so coloring is conservative.
- **Location abstraction in shares** — the share card and the Progress rollups are state-level; the precise polygon track never leaves the device in any exported image.

## 5. Bugs fixed this session (were launch-blocking)
1. **SwiftData crash** — `#Predicate { $0.exitedAt == nil }` traps (`EXC_BREAKPOINT`) in the current toolchain; every open-visit fetch crashed. Replaced with a predicate-free latest-row fetch + `isOpenFlag`. (All 6 `VisitTransitionServiceTests` were failing → now pass.)
2. **Missing Info.plist keys** — no launch-screen config (app rendered **letterboxed**, not full-screen) and **no location usage strings / background mode** (the app would crash the instant it requested location, and background tracking couldn't run). Added a complete Info.plist.
3. **CI** — malformed `-destination` in `build-for-testing` step. Fixed.

## 6. Known limitations
- **Sample geography only** in the repo (3 San Francisco ZCTAs, `is_production = false`). Beta should ship a clearly-labeled limited dataset; the production national bundle is a separate data task (`Scripts/README_PREPROCESSING.md`). The app honestly blocks tracking on missing production data in RELEASE.
- Per-state coverage % is an **estimate** against approximate Census ZCTA totals (labeled as such in-app).
- StoreKit product is wired for local testing (`Roam.storekit`); the real App Store Connect product must be created before shipping Plus.
- Swift 6 concurrency warnings remain (non-blocking on the current language mode).

## 7. Launch-blocking vs non-blocking
**Blocking (must close before App Store):** create the real StoreKit product; finalize a labeled beta ZCTA dataset; real device validation of background relaunch + battery; developer team / signing for archive.
**Non-blocking (fast-follow):** nationwide bundle; map color themes; heatmaps; widen unit/UI test coverage; resolve Swift 6 warnings.

## 8. Readiness
**~85%** of a gated v1 launch. The full on-device loop builds, runs, and is
verified in the Simulator across Onboarding / Home / Map / Progress; the core
logic is unit-tested; the launch-blocking crash and Info.plist bugs are fixed;
the growth loop (share) and monetization scaffold are in place. Remaining 15% is
real-device validation, the beta dataset, and store/signing prerequisites (§7).

## 9. Launch checklist
- [ ] Create `com.localfirst.roam.plus` in App Store Connect; reconcile price.
- [ ] Finalize + label the beta ZCTA dataset; validate with `Scripts/validate_zcta_bundle.py`.
- [ ] Set `DEVELOPMENT_TEAM`, archive, and validate on a real device (background relaunch + battery).
- [ ] App Store metadata leads with the travel/privacy story; screenshots from Onboarding + Progress + Share.
- [ ] Confirm privacy manifest + Info.plist usage strings match the listing.
