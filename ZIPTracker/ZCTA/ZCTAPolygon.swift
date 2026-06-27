import Foundation
import CoreLocation
import MapKit

/// A fully-decoded ZCTA geometry at a particular simplification resolution.
///
/// Rings are grouped into `PolygonPart`s (one exterior + its holes) so that
/// point-in-polygon and `MKPolygon` overlay construction are straightforward.
struct ZCTAPolygon: Sendable {
    let code: String
    let resolution: Int
    let parts: [PolygonPart]
    let boundingBox: BoundingBox
    let centroid: Coordinate

    init(code: String, resolution: Int, parts: [PolygonPart], centroid: Coordinate) {
        self.code = code
        self.resolution = resolution
        self.parts = parts
        self.centroid = centroid
        self.boundingBox = ZCTAPolygon.computeBoundingBox(parts: parts, fallback: centroid)
    }

    static func computeBoundingBox(parts: [PolygonPart], fallback: Coordinate) -> BoundingBox {
        guard let firstBox = parts.first?.exterior.boundingBox else {
            return BoundingBox(minLat: fallback.latitude, minLon: fallback.longitude,
                               maxLat: fallback.latitude, maxLon: fallback.longitude)
        }
        var box = firstBox
        for part in parts {
            let b = part.exterior.boundingBox
            box.minLat = min(box.minLat, b.minLat)
            box.minLon = min(box.minLon, b.minLon)
            box.maxLat = max(box.maxLat, b.maxLat)
            box.maxLon = max(box.maxLon, b.maxLon)
        }
        return box
    }

    /// Whether the given coordinate is inside this ZCTA geometry.
    func contains(_ coordinate: Coordinate) -> Bool {
        guard boundingBox.contains(coordinate) else { return false }
        return PointInPolygon.isPoint(coordinate, inMultiPolygon: parts)
    }

    /// Builds MapKit overlay polygons (with interior holes) for rendering.
    func makeMapPolygons() -> [MKPolygon] {
        parts.map { part in
            let exterior = part.exterior.coordinates
            let interiorPolys = part.holes.map { hole -> MKPolygon in
                var coords = hole.coordinates
                return MKPolygon(coordinates: &coords, count: coords.count)
            }
            var coords = exterior
            return MKPolygon(coordinates: &coords, count: coords.count, interiorPolygons: interiorPolys)
        }
    }
}
