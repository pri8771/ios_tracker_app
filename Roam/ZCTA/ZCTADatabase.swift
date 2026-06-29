import Foundation
import SQLite3
import CoreLocation

/// Thin, dependency-free wrapper around the bundled ZCTA SQLite database.
///
/// Links `libsqlite3` directly (no third-party packages). The database is opened
/// read-only; Roam never writes to it and never fetches polygons over the
/// network. Spatial candidate lookups use the `zcta_rtree` virtual table.
final class ZCTADatabase: @unchecked Sendable {

    enum DatabaseError: Error, LocalizedError {
        case cannotOpen(String)
        case notOpen

        var errorDescription: String? {
            switch self {
            case .cannotOpen(let path): return "Could not open ZCTA database at \(path)."
            case .notOpen: return "ZCTA database is not open."
            }
        }
    }

    // SQLITE_TRANSIENT tells SQLite to copy bound text/blob values.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var db: OpaquePointer?
    let path: String

    init(path: String) throws {
        self.path = path
        var handle: OpaquePointer?
        // FULLMUTEX: the single read-only connection is shared by the detection
        // actor and the map overlay builder, so let SQLite serialize access.
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, handle != nil else {
            if let handle { sqlite3_close(handle) }
            throw DatabaseError.cannotOpen(path)
        }
        self.db = handle
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - Metadata

    func loadMetadata() -> ZCTABundleMetadata {
        var pairs: [String: String] = [:]
        let sql = "SELECT key, value FROM metadata;"
        forEachRow(sql) { stmt in
            guard let keyC = sqlite3_column_text(stmt, 0),
                  let valC = sqlite3_column_text(stmt, 1) else { return }
            pairs[String(cString: keyC)] = String(cString: valC)
        }
        return ZCTABundleMetadata(rawPairs: pairs)
    }

    /// Total ZCTA feature count (used for validation/UI).
    func featureCount() -> Int {
        var count = 0
        forEachRow("SELECT COUNT(*) FROM zcta;") { stmt in
            count = Int(sqlite3_column_int64(stmt, 0))
        }
        return count
    }

    // MARK: - Candidate lookups

    /// Returns candidate ZCTA codes whose bounding box contains `coordinate`,
    /// using the R*Tree spatial index.
    func queryCandidateCodes(coordinate: Coordinate) -> [String] {
        let sql = """
        SELECT m.code FROM zcta_rtree r
        JOIN zcta_rtree_map m ON m.id = r.id
        WHERE r.min_lon <= ?1 AND r.max_lon >= ?1
          AND r.min_lat <= ?2 AND r.max_lat >= ?2;
        """
        var codes: [String] = []
        query(sql) { stmt in
            sqlite3_bind_double(stmt, 1, coordinate.longitude)
            sqlite3_bind_double(stmt, 2, coordinate.latitude)
        } row: { stmt in
            if let c = sqlite3_column_text(stmt, 0) {
                codes.append(String(cString: c))
            }
        }
        return codes
    }

    /// Returns ZCTA codes whose bounding box intersects the given box.
    func queryVisibleCodes(in box: BoundingBox, limit: Int) -> [String] {
        let sql = """
        SELECT m.code FROM zcta_rtree r
        JOIN zcta_rtree_map m ON m.id = r.id
        WHERE r.min_lon <= ?1 AND r.max_lon >= ?2
          AND r.min_lat <= ?3 AND r.max_lat >= ?4
        LIMIT ?5;
        """
        var codes: [String] = []
        query(sql) { stmt in
            sqlite3_bind_double(stmt, 1, box.maxLon)
            sqlite3_bind_double(stmt, 2, box.minLon)
            sqlite3_bind_double(stmt, 3, box.maxLat)
            sqlite3_bind_double(stmt, 4, box.minLat)
            sqlite3_bind_int(stmt, 5, Int32(limit))
        } row: { stmt in
            if let c = sqlite3_column_text(stmt, 0) {
                codes.append(String(cString: c))
            }
        }
        return codes
    }

    // MARK: - Polygon loading

    /// Loads and decodes a polygon for `code` at the requested `resolution`,
    /// assembling exterior rings and their holes into `PolygonPart`s.
    func loadPolygon(code: String, resolution: Int) -> ZCTAPolygon? {
        let sql = """
        SELECT polygon_index, ring_index, is_hole, coordinates_blob
        FROM rings
        WHERE code = ?1 AND resolution = ?2
        ORDER BY polygon_index ASC, is_hole ASC, ring_index ASC;
        """

        // polygon_index -> (exteriorRings, holeRings)
        var exteriorByPolygon: [Int: [PolygonRing]] = [:]
        var holesByPolygon: [Int: [PolygonRing]] = [:]

        query(sql) { stmt in
            sqlite3_bind_text(stmt, 1, code, -1, Self.transient)
            sqlite3_bind_int(stmt, 2, Int32(resolution))
        } row: { stmt in
            let polygonIndex = Int(sqlite3_column_int(stmt, 0))
            let isHole = sqlite3_column_int(stmt, 2) != 0
            guard let blobPtr = sqlite3_column_blob(stmt, 3) else { return }
            let blobBytes = Int(sqlite3_column_bytes(stmt, 3))
            let data = Data(bytes: blobPtr, count: blobBytes)
            let coords = ZCTAPolygonCodec.decode(data)
            guard coords.count >= 3 else { return }
            let ring = PolygonRing(coordinates: coords, isHole: isHole)
            if isHole {
                holesByPolygon[polygonIndex, default: []].append(ring)
            } else {
                exteriorByPolygon[polygonIndex, default: []].append(ring)
            }
        }

        guard !exteriorByPolygon.isEmpty else { return nil }

        var parts: [PolygonPart] = []
        for polygonIndex in exteriorByPolygon.keys.sorted() {
            guard let exteriors = exteriorByPolygon[polygonIndex] else { continue }
            let holes = holesByPolygon[polygonIndex] ?? []
            // A polygon should have exactly one exterior, but be defensive.
            for exterior in exteriors {
                parts.append(PolygonPart(exterior: exterior, holes: holes))
            }
        }

        guard !parts.isEmpty else { return nil }
        let centroid = self.centroid(for: code) ?? parts[0].exterior.boundingBox.centerCoordinate
        return ZCTAPolygon(code: code, resolution: resolution, parts: parts, centroid: centroid)
    }

    /// Returns the stored centroid for a ZCTA code.
    func centroid(for code: String) -> Coordinate? {
        let sql = "SELECT centroid_lat, centroid_lon FROM zcta WHERE code = ?1 LIMIT 1;"
        var result: Coordinate?
        query(sql) { stmt in
            sqlite3_bind_text(stmt, 1, code, -1, Self.transient)
        } row: { stmt in
            let lat = sqlite3_column_double(stmt, 0)
            let lon = sqlite3_column_double(stmt, 1)
            result = Coordinate(latitude: lat, longitude: lon)
        }
        return result
    }

    /// Confirms the expected tables exist (used by validation/status checks).
    func hasRequiredTables() -> Bool {
        let required = ["metadata", "zcta", "zcta_rtree", "zcta_rtree_map", "rings"]
        var found = Set<String>()
        forEachRow("SELECT name FROM sqlite_master WHERE type IN ('table','view');") { stmt in
            if let c = sqlite3_column_text(stmt, 0) {
                found.insert(String(cString: c))
            }
        }
        return required.allSatisfy { found.contains($0) }
    }

    // MARK: - Low-level helpers

    private func forEachRow(_ sql: String, row: (OpaquePointer) -> Void) {
        query(sql, bind: { _ in }, row: row)
    }

    private func query(
        _ sql: String,
        bind: (OpaquePointer) -> Void,
        row: (OpaquePointer) -> Void
    ) {
        guard let db else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt!)
        while sqlite3_step(stmt) == SQLITE_ROW {
            row(stmt!)
        }
    }
}

private extension BoundingBox {
    var centerCoordinate: Coordinate {
        Coordinate(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
    }
}
