#!/usr/bin/env python3
"""Validate a Roam ZCTA SQLite bundle.

Checks structural and semantic invariants that the Swift app (`ZCTADatabase`)
relies on. Exits non-zero with a clear message on the first failure; prints
"VALIDATION PASSED" on success.

Standard library only.
"""

import argparse
import sqlite3
import struct
import sys


SCALE = 100000.0
BYTES_PER_POINT = 8

REQUIRED_TABLES = ["metadata", "zcta", "zcta_rtree", "zcta_rtree_map", "rings"]


class ValidationError(Exception):
    pass


def _table_names(conn):
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type IN ('table','view');"
    ).fetchall()
    return {r[0] for r in rows}


def decode_blob(blob):
    """Decode a coordinate blob into a list of (lat, lon) tuples."""
    if not blob or len(blob) % BYTES_PER_POINT != 0:
        raise ValidationError("coordinate blob has invalid length: %d" % (len(blob) if blob else 0))
    count = len(blob) // BYTES_PER_POINT
    coords = []
    for i in range(count):
        base = i * BYTES_PER_POINT
        lat_e5, lon_e5 = struct.unpack_from("<ii", blob, base)
        coords.append((lat_e5 / SCALE, lon_e5 / SCALE))
    return coords


def validate(path):
    conn = sqlite3.connect(path)
    try:
        names = _table_names(conn)
        for table in REQUIRED_TABLES:
            if table not in names:
                raise ValidationError("missing required table/view: %s" % table)

        # metadata feature_count
        meta = dict(conn.execute("SELECT key, value FROM metadata;").fetchall())
        if "feature_count" not in meta:
            raise ValidationError("metadata is missing 'feature_count'")
        try:
            feature_count = int(meta["feature_count"])
        except ValueError:
            raise ValidationError("metadata feature_count is not an integer: %r" % meta["feature_count"])
        if feature_count <= 0:
            raise ValidationError("metadata feature_count must be > 0, got %d" % feature_count)

        zcta_count = conn.execute("SELECT COUNT(*) FROM zcta;").fetchone()[0]
        if zcta_count != feature_count:
            raise ValidationError(
                "feature_count (%d) does not match COUNT(*) from zcta (%d)"
                % (feature_count, zcta_count)
            )

        # is_production sanity (should be "true"/"false" if present)
        if meta.get("is_production") not in (None, "true", "false"):
            raise ValidationError("metadata is_production must be 'true'/'false', got %r" % meta.get("is_production"))

        # Every zcta has a matching rtree_map row and rtree row.
        codes = [r[0] for r in conn.execute("SELECT code FROM zcta;").fetchall()]
        for code in codes:
            map_row = conn.execute(
                "SELECT id FROM zcta_rtree_map WHERE code = ? LIMIT 1;", (code,)
            ).fetchone()
            if map_row is None:
                raise ValidationError("zcta %s has no zcta_rtree_map row" % code)
            rtree_row = conn.execute(
                "SELECT id FROM zcta_rtree WHERE id = ? LIMIT 1;", (map_row[0],)
            ).fetchone()
            if rtree_row is None:
                raise ValidationError("zcta %s (id %d) has no zcta_rtree row" % (code, map_row[0]))

            # At least one ring at resolution 3.
            ring_count = conn.execute(
                "SELECT COUNT(*) FROM rings WHERE code = ? AND resolution = 3;", (code,)
            ).fetchone()[0]
            if ring_count < 1:
                raise ValidationError("zcta %s has no rings at resolution 3" % code)

        # Decode a few blobs and sanity-check coordinates.
        sample = conn.execute(
            "SELECT code, coordinates_blob FROM rings LIMIT 10;"
        ).fetchall()
        if not sample:
            raise ValidationError("rings table is empty")
        for code, blob in sample:
            coords = decode_blob(blob)
            if len(coords) < 3:
                raise ValidationError("ring for %s decoded to < 3 points" % code)
            for lat, lon in coords:
                if lat != lat or lon != lon:  # NaN check
                    raise ValidationError("ring for %s has NaN coordinate" % code)
                if not (-90.0 <= lat <= 90.0):
                    raise ValidationError("ring for %s has lat out of range: %f" % (code, lat))
                if not (-180.0 <= lon <= 180.0):
                    raise ValidationError("ring for %s has lon out of range: %f" % (code, lon))

    finally:
        conn.close()


def main(argv=None):
    parser = argparse.ArgumentParser(description="Validate a Roam ZCTA SQLite bundle.")
    parser.add_argument("--input", required=True, help="Path to .sqlite bundle")
    args = parser.parse_args(argv)

    try:
        validate(args.input)
    except ValidationError as exc:
        print("VALIDATION FAILED: %s" % exc, file=sys.stderr)
        return 1
    except sqlite3.Error as exc:
        print("VALIDATION FAILED: sqlite error: %s" % exc, file=sys.stderr)
        return 1

    print("VALIDATION PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
