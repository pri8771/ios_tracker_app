# ZCTA Data Bundles

Roam resolves coordinates to ZIP-like codes **entirely on-device**. There
are no network calls for ZIP detection — the polygon data ships as a local
SQLite file that this folder is responsible for holding.

## Files the app expects

The app looks for two files in this folder (`Roam/Resources/ZCTA/`):

| File                 | Purpose                              | `is_production` |
|----------------------|--------------------------------------|-----------------|
| `zcta_bundle.sqlite` | **Production** dataset (full U.S.)    | `true`          |
| `zcta_sample.sqlite` | Dev / sample fixture (3 SF areas)     | `false`         |

`zcta_bundle.sqlite` is **intentionally absent** from the repository. The app is
written to handle its absence gracefully and fall back to the sample fixture
(or to a "no data" state) during development. See
`Scripts/README_PREPROCESSING.md` for how to build the production bundle.

## The sample fixture

`zcta_sample.sqlite` contains only **three San Francisco test areas** — ZCTAs
`94102`, `94103`, and `94107`, each a simple rectangle. It exists so the
detection pipeline, map overlays, and the simulated route work out of the box
without shipping the multi-hundred-megabyte national dataset.

- `metadata.is_production` is `"false"`.
- The rectangles are sized to contain the points along the app's simulated
  route, so ZIP detection produces real results in the simulator.
- It is **not** a substitute for production data: only those three areas exist.

## Schema (summary)

- `metadata(key, value)` — `version`, `source_name`, `build_date`,
  `feature_count`, `is_production`.
- `zcta(code, min_lat, min_lon, max_lat, max_lon, centroid_lat, centroid_lon, polygon_count, ring_count, area_hint)`
- `zcta_rtree` — R*Tree virtual table `(id, min_lon, max_lon, min_lat, max_lat)`
  for spatial candidate lookups.
- `zcta_rtree_map(id, code)` — maps an R*Tree row id to a ZCTA code.
- `rings(...)` — per-ring geometry at four simplification resolutions, with the
  coordinates stored as a compact binary blob (see `ZCTAPolygonCodec.swift`).

## Important: ZCTA is not the same as a USPS ZIP Code

The boundaries in these bundles are **U.S. Census Bureau ZIP Code Tabulation
Areas (ZCTAs)**. ZCTAs are **generalized statistical approximations** of the
geography served by USPS ZIP Codes — they are built from census blocks and are
**not** official USPS delivery boundaries.

Consequences to keep in mind:

- A ZCTA boundary may differ from the actual area a USPS ZIP Code serves.
- **Not every USPS ZIP Code has a corresponding ZCTA** (e.g. ZIPs assigned to a
  single large building or a PO-Box-only ZIP often have no ZCTA), so some valid
  ZIPs cannot be detected from geography alone.
- ZCTAs are periodically re-tabulated by the Census (e.g. the 2020 vintage), so
  codes and boundaries can change between vintages.

Treat detected codes as *approximate ZIP geography*, not authoritative postal
routing information.
