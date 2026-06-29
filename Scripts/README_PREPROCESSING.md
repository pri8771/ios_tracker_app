# ZCTA Bundle Preprocessing

This folder holds the dependency-free (Python standard library only) tooling that
turns U.S. Census ZCTA polygons into the on-device SQLite bundle Roam
reads. No third-party packages (no `shapely`, no `geopandas`) are required.

| Script                   | Purpose                                              |
|--------------------------|------------------------------------------------------|
| `make_sample_geojson.py` | Writes the 3-rectangle San Francisco sample GeoJSON. |
| `build_zcta_bundle.py`   | GeoJSON FeatureCollection -> `.sqlite` bundle.       |
| `validate_zcta_bundle.py`| Structural/semantic validation of a built bundle.    |

The binary encoding produced here **must** match the Swift decoder in
`Roam/ZCTA/ZCTAPolygonCodec.swift` and the schema queried by
`Roam/ZCTA/ZCTADatabase.swift`. If you change one side, change the other.

## Building the sample fixture (already checked in)

```sh
python3 Scripts/make_sample_geojson.py --output /tmp/sf_sample.geojson

python3 Scripts/build_zcta_bundle.py \
  --input  /tmp/sf_sample.geojson \
  --output Roam/Resources/ZCTA/zcta_sample.sqlite \
  --version "sample-1.0" \
  --source-name "Roam sample fixture (San Francisco)"

python3 Scripts/validate_zcta_bundle.py \
  --input Roam/Resources/ZCTA/zcta_sample.sqlite
```

Note: **no `--production` flag** for the sample — it sets `is_production=false`.

## Building the production bundle

### 1. Download the Census ZCTA shapefile

Get the cartographic-boundary ZCTA file from the Census Bureau, e.g.
`cb_2020_us_zcta520_500k` (the `500k` generalized resolution is recommended for
a smaller bundle; substitute the latest available `YYYY` vintage):

> https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html

Download `cb_YYYY_us_zcta520_500k.zip` and unzip it to get the `.shp` (plus its
sidecar `.dbf`, `.shx`, `.prj`, ...).

### 2. Convert to GeoJSON with ogr2ogr (GDAL)

```sh
ogr2ogr -f GeoJSON -t_srs EPSG:4326 zcta.geojson cb_2020_us_zcta520_500k.shp
```

`-t_srs EPSG:4326` reprojects to WGS84 lon/lat, which is what the build script
expects. The ZCTA code is read from the feature properties, trying these keys in
order: `ZCTA5CE20`, `ZCTA5CE`, `GEOID20`, `GEOID`, `NAME20`.

### 3. Build the production bundle (note the `--production` flag)

```sh
python3 Scripts/build_zcta_bundle.py \
  --input  zcta.geojson \
  --output Roam/Resources/ZCTA/zcta_bundle.sqlite \
  --version "2020-500k" \
  --source-name "U.S. Census Bureau cb_2020_us_zcta520_500k" \
  --production
```

The `--production` flag sets `metadata.is_production=true`. The national dataset
is large; expect the build to take a while and to produce a multi-hundred-MB
file. (The full national bundle is intentionally **not** committed to the repo.)

### 4. Validate

```sh
python3 Scripts/validate_zcta_bundle.py \
  --input Roam/Resources/ZCTA/zcta_bundle.sqlite
```

Validation must print `VALIDATION PASSED`.

### 5. Add the bundle to the Xcode app target

Add `zcta_bundle.sqlite` to the Roam app target's **Build Phases ->
Copy Bundle Resources**, under the `ZCTA` folder
(`Roam/Resources/ZCTA/`). Make sure it is a *folder reference / file
reference* included in the app target so it is copied into the app bundle. The
app opens it read-only at runtime; it never writes to it and never fetches
polygons over the network.

## Important: ZCTA is not the same as a USPS ZIP Code

The boundaries are **U.S. Census ZIP Code Tabulation Areas (ZCTAs)** —
generalized statistical approximations of ZIP geography built from census
blocks. They are **not** official USPS delivery boundaries, and **not every USPS
ZIP Code has a corresponding ZCTA**. See
`Roam/Resources/ZCTA/README_ZCTA_DATA.md` for the full disclaimer.
