import Foundation
import CoreLocation

/// Owns the app's single `CLLocationManager` for the entire app lifetime and
/// bridges CoreLocation callbacks into the `LocationEventProcessor`.
///
/// Background lifecycle: when tracking is active we enable background updates and
/// run standard updates + significant-change monitoring + visit monitoring, so
/// the app can be relaunched into the background to keep recording ZIP/ZCTAs.
@MainActor
final class BackgroundLocationService: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private let processor: LocationEventProcessor
    private weak var trackingState: TrackingState?

    /// Called whenever authorization changes (so the coordinator can react).
    var onAuthorizationChange: ((LocationAuthorizationState) -> Void)?
    /// Called after a When-In-Use grant if we still intend to request Always.
    var onWhenInUseGranted: (() -> Void)?

    private(set) var isTracking = false
    private(set) var currentMode: TrackingMode = .balanced
    private var trackingEnabledIntent = false

    init(processor: LocationEventProcessor, trackingState: TrackingState) {
        self.processor = processor
        self.trackingState = trackingState
        super.init()
        manager.delegate = self
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .other
    }

    // MARK: - Authorization state

    var authorizationState: LocationAuthorizationState {
        LocationAuthorizationService.state(
            from: manager.authorizationStatus,
            accuracy: manager.accuracyAuthorization
        )
    }

    func refreshAuthorizationState() {
        let state = authorizationState
        trackingState?.authorizationState = state
        onAuthorizationChange?(state)
    }

    /// Step 1 of the permission flow.
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Step 2 of the permission flow — only after the education screen.
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Tracking lifecycle

    func startTracking(mode: TrackingMode) {
        trackingEnabledIntent = true
        currentMode = mode
        applyMode(mode)

        let auth = authorizationState
        guard auth.isAuthorized else {
            // Caller is responsible for kicking off the permission flow.
            return
        }

        // Background updates require Always authorization.
        manager.allowsBackgroundLocationUpdates = auth.allowsBackgroundTracking
        manager.showsBackgroundLocationIndicator = true

        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
        manager.startMonitoringVisits()
        isTracking = true

        // If the user granted only reduced (coarse) accuracy, a coordinate may
        // not resolve to a ZCTA polygon. Ask for a one-time precise fix so
        // detection can work; iOS shows this at most once per purpose key.
        requestTemporaryFullAccuracyIfNeeded()
    }

    func stopTracking() {
        trackingEnabledIntent = false
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()
        manager.allowsBackgroundLocationUpdates = false
        isTracking = false
        Task { await processor.endActiveVisit() }
    }

    func updateBackgroundIndicator(_ show: Bool) {
        manager.showsBackgroundLocationIndicator = show
    }

    private func applyMode(_ mode: TrackingMode) {
        manager.distanceFilter = mode.distanceFilterMeters
        manager.desiredAccuracy = mode.desiredAccuracy
        manager.pausesLocationUpdatesAutomatically = mode.pausesAutomatically
    }

    /// Requests one-shot accuracy elevation for a single detection if reduced.
    func requestTemporaryFullAccuracyIfNeeded() {
        guard manager.accuracyAuthorization == .reducedAccuracy else { return }
        manager.requestTemporaryFullAccuracyAuthorization(
            withPurposeKey: "ZIPDetection"
        )
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let state = authorizationState
        trackingState?.authorizationState = state
        onAuthorizationChange?(state)
        NotificationCenter.default.post(name: AppConstants.Notifications.authorizationDidChange, object: nil)

        switch state {
        case .whenInUse, .whenInUseReducedAccuracy:
            onWhenInUseGranted?()
            // Cannot run background tracking yet; keep foreground updates if intended.
            if trackingEnabledIntent {
                manager.startUpdatingLocation()
                if state == .whenInUseReducedAccuracy { requestTemporaryFullAccuracyIfNeeded() }
            }
        case .always, .alwaysReducedAccuracy:
            if trackingEnabledIntent { startTracking(mode: currentMode) }
        case .denied, .restricted, .notDetermined:
            if isTracking { stopTracking() }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let isReduced = manager.accuracyAuthorization == .reducedAccuracy
        for location in locations {
            forward(location: location,
                    source: .standardLocation,
                    isReduced: isReduced)
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // Visits arrive as coarse samples; treat departures' coordinate too.
        let sample = CLLocation(
            coordinate: visit.coordinate,
            altitude: 0,
            horizontalAccuracy: visit.horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: visit.arrivalDate == .distantPast ? Date() : visit.arrivalDate
        )
        forward(location: sample, source: .visitMonitoring, isReduced: manager.accuracyAuthorization == .reducedAccuracy)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A transient "location unknown" is normal; only surface persistent errors.
        if let clError = error as? CLError, clError.code == .locationUnknown { return }
        trackingState?.lastErrorMessage = error.localizedDescription
        Task { await processor.log(.error, "Location error: \(error.localizedDescription)", persistEvenIfDisabled: true) }
    }

    // MARK: - Forwarding

    private func forward(location: CLLocation, source: DetectionSource, isReduced: Bool) {
        let coordinate = Coordinate(location.coordinate)
        let accuracy = location.horizontalAccuracy
        let timestamp = location.timestamp
        Task {
            await processor.process(
                coordinate: coordinate,
                horizontalAccuracy: accuracy,
                timestamp: timestamp,
                source: source,
                isSimulated: false
            )
        }
    }
}
