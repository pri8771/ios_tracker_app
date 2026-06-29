#!/usr/bin/env python3
"""Build the Roam ZCTA SQLite bundle from a GeoJSON FeatureCollection.

This script is the producer side of the binary encoding contract documented in
`Roam/ZCTA/ZCTAPolygonCodec.swift` and the schema consumed by
`Roam/ZCTA/ZCTADatabase.swift`. It is intentionally dependency-free
(Python standard library only) so it can run anywhere without installing
shapely/geopandas.

Coordinate blob encoding (MUST match the Swift decoder):
- Each point is two little-endian signed Int32 values: FIRST latitude*100000
  (rounded), THEN longitude*100000 (rounded). 8 bytes per point.
- Rings are stored CLOSED (first point repeated as the last point).
"""

import argparse
import json
import math
import sqlite3
import struct
import sys


# Quantization scale (1e5) -- must match ZCTAPolygonCodec.scale.
SCALE = 100000.0

# Property keys to try, in order, when reading the ZCTA code.
CODE_KEYS = ("ZCTA5CE20", "ZCTA5CE", "GEOID20", "GEOID", "NAME20")

# Douglas-Peucker tolerances (degrees) for resolutions 0..3.
RESOLUTION_TOLERANCES = {
    0: 0.020,
    1: 0.005,
    2: 0.001,
    3: 0.0001,
}

# Never simplify a ring below this many points (keeps it a valid polygon).
MIN_RING_POINTS = 4


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

def _perpendicular_distance(pt, line_start, line_end):
    """Perpendicular distance from `pt` to the segment line_start->line_end.

    Points are (lon, lat) tuples. Distance is in degree-space, which is fine
    for simplification purposes at this scale.
    """
    x0, y0 = pt
    x1, y1 = line_start
    x2, y2 = line_end

    dx = x2 - x1
    dy = y2 - y1
    if dx == 0.0 and dy == 0.0:
        return math.hypot(x0 - x1, y0 - y1)

    # Distance from point to the infinite line through the two endpoints.
    numerator = abs(dy * x0 - dx * y0 + x2 * y1 - y2 * x1)
    denominator = math.hypot(dx, dy)
    return numerator / denominator


def douglas_peucker(points, tolerance):
    """Ramer-Douglas-Peucker simplification of an open polyline.

    `points` is a list of (lon, lat) tuples. Returns a simplified list that
    always keeps the first and last point.
    """
    if len(points) < 3:
        return list(points)

    dmax = 0.0
    index = 0
    end = len(points) - 1
    for i in range(1, end):
        d = _perpendicular_distance(points[i], points[0], points[end])
        if d > dmax:
            index = i
            dmax = d

    if dmax > tolerance:
        left = douglas_peucker(points[: index + 1], tolerance)
        right = douglas_peucker(points[index:], tolerance)
        # Concatenate, dropping the duplicated junction point.
        return left[:-1] + right

    return [points[0], points[end]]


def _is_closed(ring):
    return len(ring) >= 2 and ring[0] == ring[-1]


def ensure_closed(ring):
    """Return a ring whose first and last point are identical."""
    if not ring:
        return ring
    if _is_closed(ring):
        return ring
    return ring + [ring[0]]


def simplify_ring(ring, tolerance):
    """Simplify a closed ring, keeping it closed and valid.

    `ring` is a list of (lon, lat) tuples, expected to be closed on input.
    Returns a closed, simplified list of (lon, lat) with at least
    MIN_RING_POINTS points.
    """
    ring = ensure_closed(ring)
    # Simplify the open polyline (without the duplicated closing point), then
    # re-close. RDP keeps endpoints, so the start point is preserved.
    open_line = ring[:-1] if _is_closed(ring) else ring

    # If we already have very few points, just keep them.
    if len(open_line) <= MIN_RING_POINTS:
        return ensure_closed(open_line)

    simplified = douglas_peucker(open_line, tolerance)

    # Guarantee a minimum number of distinct points so the ring stays a valid
    # polygon. If RDP collapsed it too far, fall back to evenly sampled points
    # from the original open line.
    if len(simplified) < MIN_RING_POINTS:
        n = len(open_line)
        needed = min(MIN_RING_POINTS, n)
        step = max(1, n // needed)
        sampled = open_line[::step]
        # Ensure the first original point is present.
        if sampled[0] != open_line[0]:
            sampled = [open_line[0]] + sampled
        # Pad with trailing points until we reach the minimum.
        idx = 0
        while len(sampled) < MIN_RING_POINTS and idx < n:
            if open_line[idx] not in sampled:
                sampled.append(open_line[idx])
            idx += 1
        simplified = sampled[:max(MIN_RING_POINTS, len(simplified))]

    return ensure_closed(simplified)


def ring_bbox(ring):
    """Return (min_lat, min_lon, max_lat, max_lon) for a (lon, lat) ring."""
    lons = [p[0] for p in ring]
    lats = [p[1] for p in ring]
    return min(lats), min(lons), max(lats), max(lons)


def encode_ring_blob(ring):
    """Encode a closed (lon, lat) ring into the coordinate blob.

    Each point -> struct.pack('<ii', lat_e5, lon_e5). lat FIRST, then lon.
    """
    ring = ensure_closed(ring)
    parts = bytearray()
    for lon, lat in ring:
        lat_e5 = int(round(lat * SCALE))
        lon_e5 = int(round(lon * SCALE))
        parts += struct.pack("<ii", lat_e5, lon_e5)
    return bytes(parts)


# ---------------------------------------------------------------------------
# GeoJSON parsing
# ---------------------------------------------------------------------------

def read_code(properties):
    for key in CODE_KEYS:
        if key in properties and properties[key] is not None:
            return str(properties[key])
    return None


def iter_polygons(geometry):
    """Yield polygons as lists of rings, where ring 0 is exterior.

    Each ring is a list of (lon, lat) tuples.
    """
    gtype = geometry.get("type")
    coords = geometry.get("coordinates")
    if gtype == "Polygon":
        yield [[(float(x), float(y)) for x, y, *_ in ring] for ring in coords]
    elif gtype == "MultiPolygon":
        for polygon in coords:
            yield [[(float(x), float(y)) for x, y, *_ in ring] for ring in polygon]
    else:
        # Unsupported geometry type -- skip.
        return


# ---------------------------------------------------------------------------
# Database creation
# ---------------------------------------------------------------------------

def create_schema(conn):
    conn.executescript(
        """
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE zcta (
            code TEXT PRIMARY KEY,
            min_lat REAL,
            min_lon REAL,
            max_lat REAL,
            max_lon REAL,
            centroid_lat REAL,
            centroid_lon REAL,
            polygon_count INTEGER,
            ring_count INTEGER,
            area_hint REAL
        );

        CREATE VIRTUAL TABLE zcta_rtree USING rtree(
            id, min_lon, max_lon, min_lat, max_lat
        );

        CREATE TABLE zcta_rtree_map (
            id INTEGER PRIMARY KEY,
            code TEXT NOT NULL
        );

        CREATE TABLE rings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT,
            resolution INTEGER,
            polygon_index INTEGER,
            ring_index INTEGER,
            is_hole INTEGER,
            min_lat REAL,
            min_lon REAL,
            max_lat REAL,
            max_lon REAL,
            point_count INTEGER,
            coordinates_blob BLOB
        );

        CREATE INDEX index_rings_code_resolution ON rings(code, resolution);
        CREATE INDEX index_rtree_map_code ON zcta_rtree_map(code);
        """
    )


def build(args):
    with open(args.input, "r", encoding="utf-8") as fh:
        geojson = json.load(fh)

    if geojson.get("type") != "FeatureCollection":
        print("ERROR: input is not a GeoJSON FeatureCollection", file=sys.stderr)
        return 1

    features = geojson.get("features", [])
    if not features:
        print("ERROR: FeatureCollection has no features", file=sys.stderr)
        return 1

    conn = sqlite3.connect(args.output)
    try:
        conn.execute("PRAGMA journal_mode = OFF;")
        create_schema(conn)

        feature_count = 0
        ring_rows = 0
        next_id = 1

        for feature in features:
            properties = feature.get("properties") or {}
            code = read_code(properties)
            geometry = feature.get("geometry")
            if code is None or not geometry:
                continue

            polygons = list(iter_polygons(geometry))
            if not polygons:
                continue

            feature_count += 1

            exterior_vertices = []  # for centroid (vertex mean of exteriors)
            feature_min_lat = math.inf
            feature_min_lon = math.inf
            feature_max_lat = -math.inf
            feature_max_lon = -math.inf
            polygon_count = 0
            ring_count = 0

            for polygon_index, rings in enumerate(polygons):
                if not rings:
                    continue
                polygon_count += 1
                for ring_index, ring in enumerate(rings):
                    if len(ring) < 3:
                        continue
                    ring_count += 1
                    is_hole = 1 if ring_index > 0 else 0

                    closed = ensure_closed(ring)
                    if is_hole == 0:
                        # Accumulate exterior vertices (excluding closing dup).
                        exterior_vertices.extend(closed[:-1])
                        b = ring_bbox(closed)
                        feature_min_lat = min(feature_min_lat, b[0])
                        feature_min_lon = min(feature_min_lon, b[1])
                        feature_max_lat = max(feature_max_lat, b[2])
                        feature_max_lon = max(feature_max_lon, b[3])

                    for resolution, tolerance in RESOLUTION_TOLERANCES.items():
                        simplified = simplify_ring(closed, tolerance)
                        if len(simplified) < 3:
                            continue
                        b = ring_bbox(simplified)
                        blob = encode_ring_blob(simplified)
                        conn.execute(
                            """
                            INSERT INTO rings(
                                code, resolution, polygon_index, ring_index,
                                is_hole, min_lat, min_lon, max_lat, max_lon,
                                point_count, coordinates_blob
                            ) VALUES (?,?,?,?,?,?,?,?,?,?,?);
                            """,
                            (
                                code, resolution, polygon_index, ring_index,
                                is_hole, b[0], b[1], b[2], b[3],
                                len(simplified), blob,
                            ),
                        )
                        ring_rows += 1

            if not exterior_vertices:
                # Degenerate feature (only holes?) -- skip it cleanly.
                feature_count -= 1
                continue

            centroid_lat = sum(p[1] for p in exterior_vertices) / len(exterior_vertices)
            centroid_lon = sum(p[0] for p in exterior_vertices) / len(exterior_vertices)
            area_hint = (feature_max_lat - feature_min_lat) * (feature_max_lon - feature_min_lon)

            conn.execute(
                """
                INSERT OR REPLACE INTO zcta(
                    code, min_lat, min_lon, max_lat, max_lon,
                    centroid_lat, centroid_lon, polygon_count, ring_count, area_hint
                ) VALUES (?,?,?,?,?,?,?,?,?,?);
                """,
                (
                    code, feature_min_lat, feature_min_lon,
                    feature_max_lat, feature_max_lon,
                    centroid_lat, centroid_lon, polygon_count, ring_count, area_hint,
                ),
            )

            rtree_id = next_id
            next_id += 1
            conn.execute(
                "INSERT INTO zcta_rtree(id, min_lon, max_lon, min_lat, max_lat) VALUES (?,?,?,?,?);",
                (rtree_id, feature_min_lon, feature_max_lon, feature_min_lat, feature_max_lat),
            )
            conn.execute(
                "INSERT INTO zcta_rtree_map(id, code) VALUES (?,?);",
                (rtree_id, code),
            )

        metadata = {
            "version": args.version,
            "source_name": args.source_name,
            "build_date": _today(),
            "feature_count": str(feature_count),
            "is_production": "true" if args.production else "false",
        }
        for key, value in metadata.items():
            conn.execute(
                "INSERT OR REPLACE INTO metadata(key, value) VALUES (?,?);",
                (key, value),
            )

        conn.commit()
    finally:
        conn.close()

    print("Built ZCTA bundle: %s" % args.output)
    print("  version       : %s" % args.version)
    print("  source_name   : %s" % args.source_name)
    print("  is_production  : %s" % ("true" if args.production else "false"))
    print("  feature_count : %d" % feature_count)
    print("  ring rows     : %d" % ring_rows)
    return 0


def _today():
    import datetime
    return datetime.date.today().isoformat()


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build the Roam ZCTA SQLite bundle.")
    parser.add_argument("--input", required=True, help="Path to GeoJSON FeatureCollection")
    parser.add_argument("--output", required=True, help="Path to output .sqlite file")
    parser.add_argument("--version", required=True, help="Bundle version string")
    parser.add_argument("--source-name", required=True, help="Human-readable source name")
    parser.add_argument("--production", action="store_true", help="Mark bundle as production")
    args = parser.parse_args(argv)
    return build(args)


if __name__ == "__main__":
    sys.exit(main())
