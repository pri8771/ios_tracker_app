import Foundation
import CoreLocation

/// Pure, testable quality gate for incoming location samples.
///
/// Rejects coordinates that are invalid, too inaccurate, stale, on null island,
/// or that imply a physically impossible jump from the previous accepted sample.
/// Simulation and visit-monitoring samples relax some rules (documented inline).
struct LocationFilter {

    /// Hard reject threshold for horizontal accuracy (meters).
    var rejectWorseThanMeters: CLLocationDistance

    init(rejectWorseThanMeters: CLLocationDistance = AppConstants.Detection.defaultRejectWorseThanMeters) {
        self.rejectWorseThanMeters = rejectWorseThanMeters
    }

    enum Rejection: Equatable {
        case invalidCoordinate
        case negativeAccuracy
        case poorAccuracy(CLLocationDistance)
        case nullIsland
        case stale(TimeInterval)
        case impossibleJump(CLLocationSpeed)
    }

    enum Result: Equatable {
        case accepted(LocationSample)
        case rejected(Rejection)
    }

    /// Evaluates a raw sample against the previous accepted sample (if any).
    ///
    /// - Parameters:
    ///   - coordinate: candidate coordinate.
    ///   - horizontalAccuracy: reported accuracy in meters.
    ///   - timestamp: sample time.
    ///   - now: reference "current" time (injectable for tests).
    ///   - source: detection source.
    ///   - isSimulated: relaxes null-island, staleness and jump checks.
    ///   - previous: previous accepted sample for jump detection.
    func evaluate(
        coordinate: Coordinate,
        horizontalAccuracy: CLLocationDistance,
        timestamp: Date,
        now: Date,
        source: DetectionSource,
        isSimulated: Bool,
        previous: LocationSample?
    ) -> Result {
        // 1. Coordinate validity.
        guard coordinate.isValid else { return .rejected(.invalidCoordinate) }

        // 2. Negative accuracy is invalid in CoreLocation.
        guard horizontalAccuracy >= 0 else { return .rejected(.negativeAccuracy) }

        // 3. Accuracy gate.
        if horizontalAccuracy > rejectWorseThanMeters {
            return .rejected(.poorAccuracy(horizontalAccuracy))
        }

        // 4. Null island (0,0), except in simulation.
        if !isSimulated, coordinate.latitude == 0, coordinate.longitude == 0 {
            return .rejected(.nullIsland)
        }

        // 5. Staleness, except simulation and visit monitoring.
        if !isSimulated, source != .visitMonitoring {
            let age = now.timeIntervalSince(timestamp)
            if age > AppConstants.Detection.maxSampleAgeSeconds {
                return .rejected(.stale(age))
            }
        }

        // 6. Impossible jump (implied speed), except simulation.
        if !isSimulated, let previous {
            let interval = timestamp.timeIntervalSince(previous.timestamp)
            if interval > 0 {
                let meters = distanceMeters(previous.coordinate, coordinate)
                let speed = meters / interval
                if speed > AppConstants.Detection.maxImpliedSpeedMetersPerSecond {
                    return .rejected(.impossibleJump(speed))
                }
            }
        }

        let sample = LocationSample(
            coordinate: coordinate,
            horizontalAccuracyMeters: horizontalAccuracy,
            timestamp: timestamp,
            source: source,
            isSimulated: isSimulated
        )
        return .accepted(sample)
    }

    /// Haversine great-circle distance in meters.
    func distanceMeters(_ a: Coordinate, _ b: Coordinate) -> CLLocationDistance {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(h), sqrt(1 - h))
        return earthRadius * c
    }
}
