import Foundation
import MapKit

/// The overlay plan for a given map region: which resolution to draw, whether
/// to include unvisited boundaries, and how many overlays to cap at.
struct ZCTAOverlayPlan: Equatable, Sendable {
    var resolution: Int
    var includeUnvisited: Bool
    var maxOverlays: Int

    /// Visited & current overlays are ALWAYS included, even when unvisited is
    /// capped/disabled.
    let alwaysIncludeVisitedAndCurrent = true
}

/// Pure, deterministic mapping from a map region's zoom to an overlay plan.
///
/// Larger `latitudeDelta` == more zoomed out == coarser geometry and fewer
/// overlays. As the user zooms in, resolution increases and unvisited
/// boundaries are revealed.
enum MapZoomResolver {

    /// Resolves the overlay plan from a region.
    static func plan(for region: MKCoordinateRegion) -> ZCTAOverlayPlan {
        plan(latitudeDelta: region.span.latitudeDelta)
    }

    /// Resolves the overlay plan directly from a latitude delta (for testing).
    static func plan(latitudeDelta delta: Double) -> ZCTAOverlayPlan {
        if delta > 20 {
            // Whole-world / continent: visited boundaries only.
            return ZCTAOverlayPlan(resolution: 0, includeUnvisited: false, maxOverlays: 150)
        } else if delta > 8 {
            // Region: still no unvisited fill to keep it readable.
            return ZCTAOverlayPlan(resolution: 0, includeUnvisited: false, maxOverlays: 150)
        } else if delta > 2 {
            // State / metro: start showing unvisited boundaries.
            return ZCTAOverlayPlan(resolution: 0, includeUnvisited: true, maxOverlays: 250)
        } else if delta > 0.5 {
            // City: medium resolution.
            return ZCTAOverlayPlan(resolution: 1, includeUnvisited: true, maxOverlays: 500)
        } else if delta > 0.1 {
            // Neighborhood: finer resolution.
            return ZCTAOverlayPlan(resolution: 2, includeUnvisited: true, maxOverlays: 750)
        } else {
            // Street level: full resolution.
            return ZCTAOverlayPlan(resolution: 3, includeUnvisited: true, maxOverlays: 1000)
        }
    }
}
