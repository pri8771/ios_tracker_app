import Foundation
import CoreLocation

/// Decides whether a matched location fix is trustworthy enough to *color in*
/// (create or transition into) a ZIP Code Area.
///
/// Roam biases hard toward **not** coloring on uncertain fixes — a wrong patch
/// erodes trust faster than a missing one. Two independent rules gate coloring:
///
/// 1. **Accuracy gate.** Horizontal accuracy must be ≤ `maxAccuracyMeters`
///    (100 m by default). Coarser fixes never auto-color.
/// 2. **Boundary clearance.** The fix's accuracy circle must sit comfortably
///    inside the matched polygon. If the nearest ZCTA boundary is closer than
///    `max(boundaryMarginMeters, horizontalAccuracy)`, the true position could be
///    in a neighboring area, so we decline rather than risk a mis-assignment.
struct AutoColorGate: Equatable {

    var maxAccuracyMeters: CLLocationDistance
    var boundaryMarginMeters: CLLocationDistance

    init(
        maxAccuracyMeters: CLLocationDistance = AppConstants.Detection.autoColorMaxAccuracyMeters,
        boundaryMarginMeters: CLLocationDistance = AppConstants.Detection.autoColorBoundaryMarginMeters
    ) {
        self.maxAccuracyMeters = maxAccuracyMeters
        self.boundaryMarginMeters = boundaryMarginMeters
    }

    enum Decision: Equatable {
        case color
        case skipLowAccuracy(CLLocationDistance)
        case skipNearBoundary(CLLocationDistance)

        var allowsColoring: Bool { self == .color }
    }

    /// - Parameters:
    ///   - horizontalAccuracy: reported accuracy of the fix, in meters.
    ///   - distanceToBoundaryMeters: distance from the fix to the nearest edge of
    ///     the matched polygon, in meters; `nil` if unknown (then only the
    ///     accuracy gate applies).
    ///   - isSimulated: simulated routes bypass the gate so DEBUG demos color.
    func evaluate(
        horizontalAccuracy: CLLocationDistance,
        distanceToBoundaryMeters: CLLocationDistance?,
        isSimulated: Bool = false
    ) -> Decision {
        if isSimulated { return .color }

        if horizontalAccuracy > maxAccuracyMeters {
            return .skipLowAccuracy(horizontalAccuracy)
        }
        if let edge = distanceToBoundaryMeters {
            let requiredClearance = Swift.max(boundaryMarginMeters, horizontalAccuracy)
            if edge < requiredClearance {
                return .skipNearBoundary(edge)
            }
        }
        return .color
    }
}
