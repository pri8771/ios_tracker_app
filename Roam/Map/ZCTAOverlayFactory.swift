import Foundation
import MapKit

/// Builds the set of boundary overlays + their MapKit polygons for a visible
/// region, off the main thread, with debouncing handled by the caller.
///
/// Each `MKPolygon` is tagged (via the returned `BuiltOverlay`) with its style so
/// the coordinator can look it up in `rendererFor` without re-deriving it.
final class ZCTAOverlayFactory: @unchecked Sendable {

    struct BuiltOverlay {
        let code: String
        let style: ZCTAOverlayStyle
        let polygon: MKPolygon
    }

    private let index: ZCTAIndex

    init(index: ZCTAIndex) {
        self.index = index
    }

    /// Builds overlays for the region. Safe to call off the main thread.
    func buildOverlays(
        region: MKCoordinateRegion,
        visitedCodes: Set<String>,
        currentCode: String?,
        selectedCode: String?,
        showUnvisited: Bool
    ) -> [BuiltOverlay] {
        let items = index.visiblePolygons(
            in: region,
            includeVisitedCodes: visitedCodes,
            currentCode: currentCode,
            selectedCode: selectedCode,
            showUnvisited: showUnvisited
        )
        var built: [BuiltOverlay] = []
        for item in items {
            for polygon in item.polygon.makeMapPolygons() {
                polygon.title = item.code
                built.append(BuiltOverlay(code: item.code, style: item.style, polygon: polygon))
            }
        }
        return built
    }
}
