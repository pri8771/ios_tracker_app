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
    private var foregroundLocationRequestPending = false

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

    /// Refreshes the user's foreground location only if permission already
    /// exists. This is safe to call when the app opens: it never shows a system
    /// prompt, but keeps the "where am I now?" state warm for returning users.
    func refreshCurrentLocationIfAuthorized(mode: TrackingMode) {
        guard authorizationState.isAuthorized else { return }
        requestOneShotLocation(mode: mode, requestTemporaryFullAccuracy: false)
    }

    /// Requests a foreground "where am I?" fix. If permission has not been
    /// decided, this asks for When-In-Use only; it does not imply background
    /// tracking or jump straight to the Always education flow.
    func requestCurrentLocation(mode: TrackingMode) {
        currentMode = mode
        applyMode(mode)

        switch authorizationState {
        case .notDetermined:
            foregroundLocationRequestPending = true
            requestWhenInUseAuthorization()
        case .whenInUse, .whenInUseReducedAccuracy, .always, .alwaysReducedAccuracy:
            // Detecting a ZIP Code Area needs a precise coordinate; a reduced
            // (coarse) fix can't be matched to a polygon. Ask for one-time full
            // accuracy here so "where am I?" actually resolves an area.
            requestOneShotLocation(mode: mode, requestTemporaryFullAccuracy: true)
        case .denied, .restricted:
            trackingState?.lastErrorMessage = "Location permission is denied. Open Settings to allow Roam to show your current location."
        }
    }

    /// Arms foreground coloring *before* the When-In-Use prompt so that, the
    /// moment access is granted, a single foreground fix colors in the user's
    /// current area — the visible "first win" that justifies later asking for
    /// Always. Also keeps the app in a useful limited mode if Always is declined.
    func prepareForegroundFirstWin(mode: TrackingMode) {
        trackingEnabledIntent = true
        currentMode = mode
        applyMode(mode)
        // If access is already granted (e.g. re-enabling), start updating now.
        if authorizationState.isAuthorized {
            manager.startUpdatingLocation()
        }
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

    private func requestOneShotLocation(mode: TrackingMode, requestTemporaryFullAccuracy: Bool) {
        currentMode = mode
        applyMode(mode)
        if requestTemporaryFullAccuracy { requestTemporaryFullAccuracyIfNeeded() }
        manager.requestLocation()
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
            if foregroundLocationRequestPending {
                foregroundLocationRequestPending = false
                requestOneShotLocation(mode: currentMode, requestTemporaryFullAccuracy: false)
            }
            if trackingEnabledIntent {
                onWhenInUseGranted?()
                onWhenInUseGranted = nil
            }
            // Cannot run background tracking yet; keep foreground updates if intended.
            if trackingEnabledIntent {
                manager.startUpdatingLocation()
                if state == .whenInUseReducedAccuracy { requestTemporaryFullAccuracyIfNeeded() }
            }
        case .always, .alwaysReducedAccuracy:
            if foregroundLocationRequestPending {
                foregroundLocationRequestPending = false
                requestOneShotLocation(mode: currentMode, requestTemporaryFullAccuracy: false)
            }
            if trackingEnabledIntent { startTracking(mode: currentMode) }
        case .denied, .restricted, .notDetermined:
            foregroundLocationRequestPending = false
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
        trackingState?.lastCoordinate = coordinate
        trackingState?.lastLocationAccuracyMeters = accuracy
        trackingState?.lastLocationAt = timestamp
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
