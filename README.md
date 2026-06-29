# Roam

**Automatically collect the ZIP Code Areas you visit, privately on your iPhone.**

Roam is a local-first iOS app that tracks your movement in the background
and records each new **ZIP Code Area** you enter — dropping a pin, keeping a
timestamped visit history, and highlighting boundaries on the map as you zoom.
Everything stays on your device.

> **About "ZIP Code Areas" / ZCTAs.** The map boundaries come from **U.S. Census
> ZIP Code Tabulation Areas (ZCTAs)**. ZCTAs are generalized Census areas that
> *approximate* ZIP Code geographies. They are **not** official USPS
> delivery-route boundaries, and **not every** valid USPS ZIP Code has a matching
> ZCTA polygon. Throughout the app, technical/help copy uses "ZIP Code Areas,"
> "ZIP/ZCTA," or "Census ZCTA boundaries."

---

## Privacy & data model

Roam is built to be private by construction:

- **Fully local.** All app data lives in on-device SwiftData. There is **no
  cloud sync, no account, and no backend.**
- **No analytics SDKs, no third-party packages.**
- **No network calls for ZIP/ZCTA detection.** Detection is done entirely
  on-device against a **bundled SQLite database** of Census ZCTA polygons using a
  local R\*Tree spatial index + point-in-polygon test.
- **No reverse geocoding.** The app never uses `CLGeocoder`, `MKLocalSearch`, or
  any external ZIP API.
- **Privacy manifest** (`PrivacyInfo.xcprivacy`) declares `NSPrivacyTracking =
  false` with empty collected-data and tracking-domain lists.
- Data leaves the device **only** if you explicitly use **Export** and choose to
  share a file via the system share sheet.

## Location & permissions

- Tracking is **opt-in**. Nothing is recorded until you enable it.
- The app requests **When In Use** first, then — only after showing a dedicated
  **education screen** explaining the battery and privacy implications — requests
  **Always** authorization.
- **Background tracking requires Always authorization.** With Always granted, the
  app keeps recording ZIP/ZCTAs even when it isn't open (and can be relaunched by
  iOS for location events).
- The app gracefully handles **Denied**, **Reduced Accuracy**, **When-In-Use
  only**, and **Location Services disabled** states, surfacing clear guidance.
- You can stop tracking at any time from **Settings**.

## ZIP/ZCTA vs ZIP Code

A USPS **ZIP Code** is a set of mail delivery routes, not a precise polygon. The
Census Bureau publishes **ZCTAs** as polygon approximations of those areas for
statistical use. Roam detects and displays **ZCTAs**, which is why help
and accuracy copy consistently refers to **ZIP Code Areas / Census ZCTA
boundaries**.

---

## Building & running

### Requirements
- Xcode 15+ / iOS 17.0+ deployment target.
- No third-party dependencies. The only system library linked is `libsqlite3`
  (via `-lsqlite3`).

### Open the project
A ready-to-open Xcode project is committed at `Roam.xcodeproj`. Just open it
and run the **Roam** scheme.

The canonical project definition lives in `project.yml`
([XcodeGen](https://github.com/yonaskolb/XcodeGen)). If you change the file list,
regenerate with either:

```bash
xcodegen generate            # if you have XcodeGen installed
# or, dependency-free:
python3 Scripts/generate_xcodeproj.py
```

### ZCTA data bundle
- The repo ships a tiny **sample** dataset:
  `Roam/Resources/ZCTA/zcta_sample.sqlite` (3 San Francisco test areas,
  `is_production = false`). In **DEBUG** the app falls back to this and shows a
  "Sample ZCTA data" warning in **Data Status**.
- The **production** dataset (`zcta_bundle.sqlite`) is intentionally **not**
  committed. The app never fakes full coverage: if the production bundle is
  missing, DEBUG uses the sample (with a warning) and **RELEASE blocks tracking**
  and shows a Data Status error.
- To build the production bundle, see
  [`Scripts/README_PREPROCESSING.md`](Scripts/README_PREPROCESSING.md) and
  [`Roam/Resources/ZCTA/README_ZCTA_DATA.md`](Roam/Resources/ZCTA/README_ZCTA_DATA.md).

### Running in the Simulator (DEBUG)
1. Build & run the **Roam** scheme on an iOS 17 simulator.
2. Complete onboarding and enable tracking (When-In-Use is enough in DEBUG demo).
3. Open **Settings → Developer** and use:
   - **Generate Sample Visits** — seeds a few discovered ZCTAs + timestamps.
   - **Simulate Route** — plays a scripted route across the sample ZCTAs through
     the *real* detection pipeline, creating 2+ discovered ZIP/ZCTA records.
   - **Step Next Location** — advances the simulated route one sample at a time.
4. Check the **Map** (pins + boundaries), **History** (timestamped visits),
   **Stats**, and **Export** (writes JSON/CSV and opens the share sheet).
5. On the Map you can also **long-press** (DEBUG only) to inject a manual sample.

## Tests

Unit tests live in `Tests/` and cover the core logic: point-in-polygon, polygon
codec round-tripping, the spatial index against the sample bundle, the location
filter, visit-transition state machine, map zoom resolution selection, export CSV
formatting, and statistics.

Run them from Xcode (**⌘U**) or:

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Architecture

MVVM + services + a local geometry/data layer.

```
Roam/
  App/        App lifecycle, AppDelegate (location relaunch), DI container, constants
  Models/     SwiftData models + value types (enums/structs)
  Location/   CoreLocation service, authorization, filter, event processor (actor), sim player
  ZCTA/       SQLite wrapper, spatial index, polygon codec, point-in-polygon, bundle status
  Map/        MKMapView wrapper + coordinator, overlay factory/renderer, zoom resolver
  Services/   Visit transitions, statistics, export, CSV, file store, haptics, sample data
  ViewModels/ One per screen
  Views/      SwiftUI screens + reusable Components
  Resources/  Info.plist, PrivacyInfo.xcprivacy, ZCTA SQLite bundle(s)
Scripts/      Census ZCTA GeoJSON → SQLite builder + validator (+ project generator)
Tests/        XCTest unit tests
```

### Detection pipeline (all on-device)
`CLLocationManager` → `LocationFilter` (quality gate) → `ZCTAIndex.match`
(R\*Tree candidates + point-in-polygon at full resolution) → `VisitTransitionService`
(anti-jitter visit segmentation) → SwiftData. UI refreshes via `NotificationCenter`.

## Scope (intentionally excluded)
No cloud sync, accounts, social features, routing, or venue search.
