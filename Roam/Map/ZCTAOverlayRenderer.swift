import Foundation
import MapKit
#if canImport(UIKit)
import UIKit
#endif

/// Maps a `ZCTAOverlayStyle` to renderer colors/strokes, and produces
/// configured `MKPolygonRenderer`s. Kept separate so styling is centralized and
/// testable in isolation from the coordinator.
enum ZCTAOverlayRenderer {

    #if canImport(UIKit)
    struct Style {
        var fillColor: UIColor
        var strokeColor: UIColor
        var lineWidth: CGFloat
    }

    static func style(for style: ZCTAOverlayStyle) -> Style {
        switch style {
        case .unvisited:
            return Style(
                fillColor: UIColor.systemGray.withAlphaComponent(0.04),
                strokeColor: UIColor.systemGray.withAlphaComponent(0.35),
                lineWidth: 0.7
            )
        case .visited:
            // Roam coral — the signature "colored-in" patch.
            return Style(
                fillColor: UIColor(hex: 0xFB6F47).withAlphaComponent(0.22),
                strokeColor: UIColor(hex: 0xFB6F47).withAlphaComponent(0.9),
                lineWidth: 1.5
            )
        case .current:
            // Roam teal — the live current area.
            return Style(
                fillColor: UIColor(hex: 0x0FB39B).withAlphaComponent(0.30),
                strokeColor: UIColor(hex: 0x0FB39B),
                lineWidth: 2.6
            )
        case .selected:
            // Roam indigo — the user's current selection.
            return Style(
                fillColor: UIColor(hex: 0x4F46E5).withAlphaComponent(0.18),
                strokeColor: UIColor(hex: 0x4F46E5),
                lineWidth: 2.2
            )
        }
    }

    static func makeRenderer(for polygon: MKPolygon, style: ZCTAOverlayStyle) -> MKPolygonRenderer {
        let renderer = MKPolygonRenderer(polygon: polygon)
        let s = Self.style(for: style)
        renderer.fillColor = s.fillColor
        renderer.strokeColor = s.strokeColor
        renderer.lineWidth = s.lineWidth
        return renderer
    }
    #endif
}
