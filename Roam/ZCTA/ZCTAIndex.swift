import Foundation
import CoreLocation
import MapKit

/// High-level, cached query API over `ZCTADatabase`.
///
/// All ZCTA detection is local: candidate lookups go through the bundled R*Tree
/// index, and the final inside/outside decision is an in-memory point-in-polygon
/// test. There is no network access, no reverse geocoding, and no external API.
final class ZCTAIndex: @unchecked Sendable {

    let database: ZCTADatabase
    let metadata: ZCTABundleMetadata

    /// Decoded-polygon cache keyed by "code@resolution".
    private let polygonCache: NSCache<NSString, CachedPolygon> = {
        let cache = NSCache<NSString, CachedPolygon>()
        cache.countLimit = AppConstants.Persistence.polygonCacheLimit
        return cache
    }()

    init(database: ZCTADatabase) {
        self.database = database
        self.metadata = database.loadMetadata()
    }

    // MARK: - Detection

    /// Resolves a coordinate to its containing ZCTA, or `nil` if outside all
    /// known ZCTAs. Uses the highest resolution (3) for accurate boundaries.
    func match(coordinate: Coordinate) -> ZCTAMatch? {
        guard coordinate.isValid else { return nil }

        let candidates = database.queryCandidateCodes(coordinate: coordinate)
        guard !candidates.isEmpty else { return nil }

        for code in candidates {
            guard let polygon = polygon(code: code, resolution: 3) else { continue }
            if polygon.contains(coordinate) {
                return ZCTAMatch(
                    code: code,
                    centroid: polygon.centroid,
                    matchedCoordinate: coordinate
                )
            }
        }
        return nil
    }

    // MARK: - Visible overlays

    /// Builds overlay items for the visible region, honoring the zoom-derived
    /// plan. Visited and current codes are always included; unvisited codes are
    /// added (nearest-center first) up to the plan's cap.
    func visiblePolygons(
        in region: MKCoordinateRegion,
        includeVisitedCodes visitedCodes: Set<String>,
        currentCode: String?,
        selectedCode: String?,
        showUnvisited: Bool
    ) -> [ZCTAOverlayItem] {
        let plan = MapZoomResolver.plan(for: region)
        let box = BoundingBox(region: region)
        let center = Coordinate(region.center)

        // Generous candidate fetch; we trim to plan.maxOverlays afterward.
        let candidateLimit = max(plan.maxOverlays * 2, 64)
        let visibleCodes = database.queryVisibleCodes(in: box, limit: candidateLimit)

        var items: [ZCTAOverlayItem] = []
        var usedCodes = Set<String>()

        // 1. Always include current + selected + visited (highest priority).
        let priorityOrdered = orderedPriorityCodes(
            currentCode: currentCode,
            selectedCode: selectedCode,
            visitedCodes: visitedCodes,
            visibleCodes: Set(visibleCodes)
        )
        for code in priorityOrdered {
            guard !usedCodes.contains(code) else { continue }
            guard let polygon = polygon(code: code, resolution: plan.resolution) else { continue }
            let style = overlayStyle(
                for: code,
                currentCode: currentCode,
                selectedCode: selectedCode,
                visitedCodes: visitedCodes
            )
            items.append(ZCTAOverlayItem(code: code, polygon: polygon, style: style))
            usedCodes.insert(code)
        }

        // 2. Fill remaining budget with unvisited boundaries nearest center.
        if showUnvisited && plan.includeUnvisited {
            let remaining = max(0, plan.maxOverlays - items.count)
            if remaining > 0 {
                let unvisited = visibleCodes
                    .filter { !usedCodes.contains($0) && !visitedCodes.contains($0) }
                let sorted = sortByDistanceToCenter(unvisited, center: center)
                for code in sorted.prefix(remaining) {
                    guard let polygon = polygon(code: code, resolution: plan.resolution) else { continue }
                    items.append(ZCTAOverlayItem(code: code, polygon: polygon, style: .unvisited))
                    usedCodes.insert(code)
                }
            }
        }

        return items
    }

    // MARK: - Polygon cache

    /// Loads (and caches) a decoded polygon for a code at a resolution.
    func polygon(code: String, resolution: Int) -> ZCTAPolygon? {
        let key = "\(code)@\(resolution)" as NSString
        if let cached = polygonCache.object(forKey: key) {
            return cached.polygon
        }
        guard let polygon = database.loadPolygon(code: code, resolution: resolution) else {
            return nil
        }
        polygonCache.setObject(CachedPolygon(polygon: polygon), forKey: key)
        return polygon
    }

    func centroid(for code: String) -> Coordinate? {
        database.centroid(for: code)
    }

    // MARK: - Helpers

    private func orderedPriorityCodes(
        currentCode: String?,
        selectedCode: String?,
        visitedCodes: Set<String>,
        visibleCodes: Set<String>
    ) -> [String] {
        var ordered: [String] = []
        if let currentCode { ordered.append(currentCode) }
        if let selectedCode, selectedCode != currentCode { ordered.append(selectedCode) }
        // Visited codes that are within the visible region.
        let visibleVisited = visitedCodes
            .intersection(visibleCodes)
            .subtracting(ordered)
            .sorted()
        ordered.append(contentsOf: visibleVisited)
        return ordered
    }

    private func overlayStyle(
        for code: String,
        currentCode: String?,
        selectedCode: String?,
        visitedCodes: Set<String>
    ) -> ZCTAOverlayStyle {
        if code == currentCode { return .current }
        if code == selectedCode { return .selected }
        if visitedCodes.contains(code) { return .visited }
        return .unvisited
    }

    private func sortByDistanceToCenter(_ codes: [String], center: Coordinate) -> [String] {
        codes
            .compactMap { code -> (String, Double)? in
                guard let c = database.centroid(for: code) else { return nil }
                let dLat = c.latitude - center.latitude
                let dLon = c.longitude - center.longitude
                return (code, dLat * dLat + dLon * dLon)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }
}

/// Reference wrapper so `ZCTAPolygon` (a struct) can live in `NSCache`.
private final class CachedPolygon {
    let polygon: ZCTAPolygon
    init(polygon: ZCTAPolygon) { self.polygon = polygon }
}
