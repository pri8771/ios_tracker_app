import Foundation
import CoreLocation

/// Pure geometry: ray-casting point-in-polygon tests on lon/lat coordinates.
///
/// Conventions:
/// - A point exactly on an edge/vertex counts as **inside**.
/// - For a polygon with holes, a point is inside iff it is inside the exterior
///   ring AND not strictly inside any hole.
/// - For a MultiPolygon, a point is inside iff it is inside any single polygon.
enum PointInPolygon {

    /// Ray-casting test against a single closed ring.
    ///
    /// Returns `true` if `point` is inside the ring or lies on its boundary.
    static func isPoint(
        _ point: Coordinate,
        inRing ring: [CLLocationCoordinate2D]
    ) -> Bool {
        guard ring.count >= 3 else { return false }

        let x = point.longitude
        let y = point.latitude

        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let xi = ring[i].longitude, yi = ring[i].latitude
            let xj = ring[j].longitude, yj = ring[j].latitude

            // On-boundary check first (counts as inside).
            if isPointOnSegment(px: x, py: y, ax: xi, ay: yi, bx: xj, by: yj) {
                return true
            }

            let intersects = ((yi > y) != (yj > y)) &&
                (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            if intersects { inside.toggle() }
            j = i
        }
        return inside
    }

    /// Whether point (px,py) lies on the segment (ax,ay)-(bx,by), within epsilon.
    static func isPointOnSegment(
        px: Double, py: Double,
        ax: Double, ay: Double,
        bx: Double, by: Double,
        epsilon: Double = 1e-9
    ) -> Bool {
        // Cross product magnitude (collinearity).
        let cross = (px - ax) * (by - ay) - (py - ay) * (bx - ax)
        if abs(cross) > epsilon { return false }

        // Within bounding box of the segment (with epsilon slack).
        let withinX = min(ax, bx) - epsilon <= px && px <= max(ax, bx) + epsilon
        let withinY = min(ay, by) - epsilon <= py && py <= max(ay, by) + epsilon
        return withinX && withinY
    }

    /// Whether `point` is inside a single polygon (exterior minus holes).
    static func isPoint(_ point: Coordinate, inPolygon polygon: PolygonPart) -> Bool {
        guard polygon.exterior.boundingBox.contains(point) else { return false }
        guard isPoint(point, inRing: polygon.exterior.coordinates) else { return false }
        for hole in polygon.holes {
            // Boundary of a hole counts as inside the polygon (edge of land).
            if hole.boundingBox.contains(point),
               isStrictlyInsideHole(point, ring: hole.coordinates) {
                return false
            }
        }
        return true
    }

    /// Whether `point` is inside any polygon of a multipolygon.
    static func isPoint(_ point: Coordinate, inMultiPolygon polygons: [PolygonPart]) -> Bool {
        for polygon in polygons where isPoint(point, inPolygon: polygon) {
            return true
        }
        return false
    }

    /// Strict interior test for holes: a point on the hole boundary is treated
    /// as still inside the surrounding land (so it is NOT excluded).
    private static func isStrictlyInsideHole(
        _ point: Coordinate,
        ring: [CLLocationCoordinate2D]
    ) -> Bool {
        guard ring.count >= 3 else { return false }
        let x = point.longitude
        let y = point.latitude

        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let xi = ring[i].longitude, yi = ring[i].latitude
            let xj = ring[j].longitude, yj = ring[j].latitude
            // On the hole boundary -> not strictly inside.
            if isPointOnSegment(px: x, py: y, ax: xi, ay: yi, bx: xj, by: yj) {
                return false
            }
            let intersects = ((yi > y) != (yj > y)) &&
                (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            if intersects { inside.toggle() }
            j = i
        }
        return inside
    }
}
