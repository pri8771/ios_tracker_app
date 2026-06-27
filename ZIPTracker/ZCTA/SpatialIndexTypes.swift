import Foundation
import CoreLocation
import MapKit

/// An axis-aligned bounding box in lon/lat space.
struct BoundingBox: Hashable, Sendable {
    var minLat: Double
    var minLon: Double
    var maxLat: Double
    var maxLon: Double

    init(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) {
        self.minLat = minLat
        self.minLon = minLon
        self.maxLat = maxLat
        self.maxLon = maxLon
    }

    /// Whether a coordinate falls within (inclusive) this box.
    func contains(_ c: Coordinate) -> Bool {
        c.latitude >= minLat && c.latitude <= maxLat &&
        c.longitude >= minLon && c.longitude <= maxLon
    }

    func intersects(_ other: BoundingBox) -> Bool {
        !(other.minLon > maxLon || other.maxLon < minLon ||
          other.minLat > maxLat || other.maxLat < minLat)
    }

    init(region: MKCoordinateRegion) {
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        self.minLat = region.center.latitude - halfLat
        self.maxLat = region.center.latitude + halfLat
        self.minLon = region.center.longitude - halfLon
        self.maxLon = region.center.longitude + halfLon
    }
}

/// A single polygon ring (sequence of coordinates). The ring is treated as
/// closed (first point == last point) by `ZCTAPolygonCodec.ensureClosed`.
struct PolygonRing: Sendable {
    var coordinates: [CLLocationCoordinate2D]
    var isHole: Bool
    var boundingBox: BoundingBox

    init(coordinates: [CLLocationCoordinate2D], isHole: Bool) {
        self.coordinates = coordinates
        self.isHole = isHole
        self.boundingBox = PolygonRing.computeBoundingBox(coordinates)
    }

    static func computeBoundingBox(_ coords: [CLLocationCoordinate2D]) -> BoundingBox {
        guard let first = coords.first else {
            return BoundingBox(minLat: 0, minLon: 0, maxLat: 0, maxLon: 0)
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coords {
            minLat = Swift.min(minLat, c.latitude)
            maxLat = Swift.max(maxLat, c.latitude)
            minLon = Swift.min(minLon, c.longitude)
            maxLon = Swift.max(maxLon, c.longitude)
        }
        return BoundingBox(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }
}

/// One polygon = one exterior ring plus zero or more holes.
struct PolygonPart: Sendable {
    var exterior: PolygonRing
    var holes: [PolygonRing]
}
