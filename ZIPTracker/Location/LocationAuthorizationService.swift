import Foundation
import CoreLocation

/// Pure mapping helpers between CoreLocation authorization values and the app's
/// `LocationAuthorizationState`. Kept separate from `BackgroundLocationService`
/// so the mapping logic is unit-test friendly and side-effect free.
enum LocationAuthorizationService {

    static func state(
        from status: CLAuthorizationStatus,
        accuracy: CLAccuracyAuthorization
    ) -> LocationAuthorizationState {
        let reduced = accuracy == .reducedAccuracy
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorizedWhenInUse:
            return reduced ? .whenInUseReducedAccuracy : .whenInUse
        case .authorizedAlways:
            return reduced ? .alwaysReducedAccuracy : .always
        @unknown default:
            return .notDetermined
        }
    }

    /// Derives the runtime state shown to the user from authorization + intent.
    static func runtimeState(
        trackingEnabled: Bool,
        authorization: LocationAuthorizationState,
        hasError: Bool
    ) -> TrackingRuntimeState {
        if hasError { return .error }
        guard trackingEnabled else { return .off }
        if !authorization.allowsBackgroundTracking { return .needsAlwaysAuthorization }
        return authorization.isReducedAccuracy ? .activeReducedAccuracy : .active
    }
}
