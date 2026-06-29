import Foundation
import MapKit

/// Visual style applied to a ZCTA boundary overlay, in increasing prominence.
enum ZCTAOverlayStyle: Int, Sendable {
    case unvisited   // very low opacity outline
    case visited     // stronger stroke, soft fill
    case current     // strongest stroke, brighter fill
    case selected    // strong outline, visible fill
}

/// An overlay item describing a ZCTA boundary to render on the map.
struct ZCTAOverlayItem: Identifiable, Sendable {
    let id: String          // ZCTA code (unique per visible set)
    let code: String
    let polygon: ZCTAPolygon
    let style: ZCTAOverlayStyle

    init(code: String, polygon: ZCTAPolygon, style: ZCTAOverlayStyle) {
        self.id = code
        self.code = code
        self.polygon = polygon
        self.style = style
    }
}

/// A discovered-ZCTA pin (one per tracked ZCTA).
struct ZCTAMapPin: Identifiable, Sendable {
    let id: String
    let zctaCode: String
    let coordinate: Coordinate
    let firstEnteredAt: Date
    let lastEnteredAt: Date
    let visitCount: Int
    let isFavorite: Bool
    let isCurrent: Bool
}

/// A per-visit pin (optional finer-grained markers).
struct ZCTAVisitPin: Identifiable, Sendable {
    let id: String
    let zctaCode: String
    let coordinate: Coordinate
    let enteredAt: Date
    let isSimulated: Bool
}

// MARK: - MapKit annotation classes

/// Annotation backing a discovered-ZCTA marker.
final class ZCTADiscoveredAnnotation: NSObject, MKAnnotation {
    let zctaCode: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let isCurrent: Bool
    let isFavorite: Bool
    let visitCount: Int

    init(pin: ZCTAMapPin) {
        self.zctaCode = pin.zctaCode
        self.coordinate = pin.coordinate.clCoordinate
        self.title = pin.zctaCode
        self.subtitle = "\(pin.visitCount) visit\(pin.visitCount == 1 ? "" : "s")"
        self.isCurrent = pin.isCurrent
        self.isFavorite = pin.isFavorite
        self.visitCount = pin.visitCount
    }

    /// Emoji glyph reflecting the pin's dominant "vibe".
    var glyphEmoji: String {
        if isCurrent { return "📍" }
        if isFavorite { return "⭐️" }
        return "📮"
    }
}

/// Annotation backing a single-visit marker.
final class ZCTAVisitAnnotation: NSObject, MKAnnotation {
    let zctaCode: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let isSimulated: Bool

    init(pin: ZCTAVisitPin) {
        self.zctaCode = pin.zctaCode
        self.coordinate = pin.coordinate.clCoordinate
        self.title = pin.zctaCode
        self.isSimulated = pin.isSimulated
    }
}
