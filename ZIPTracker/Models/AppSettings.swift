import Foundation
import SwiftData
import CoreLocation

/// Singleton-style settings record persisted in SwiftData.
///
/// Exactly one row is expected; `DependencyContainer`/`RootViewModel` fetch the
/// existing row or create a default one on first launch.
@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID

    // Onboarding & permission flow
    var hasCompletedOnboarding: Bool
    var trackingEnabled: Bool
    var hasSeenAlwaysPermissionEducation: Bool
    var hasRequestedAlwaysPermission: Bool

    // Tracking tuning
    var trackingModeRaw: String
    var distanceFilterMeters: Double
    var desiredAccuracyMeters: Double
    var pauseAutomatically: Bool
    var showBackgroundLocationIndicator: Bool

    // Anti-jitter / transition tuning
    var transitionCooldownSeconds: Double
    var requireTwoConsecutiveMatchesNearBoundary: Bool
    var rejectLocationsWorseThanMeters: Double

    // Map display toggles
    var showVisitedBoundaries: Bool
    var showAllVisibleBoundaries: Bool
    var showVisitPins: Bool
    var showDiscoveredPins: Bool
    var mapStyleRaw: String
    var lastMapCenterLatitude: Double
    var lastMapCenterLongitude: Double
    var lastMapLatitudeDelta: Double
    var lastMapLongitudeDelta: Double

    // Diagnostics & feedback
    var storeDiagnosticEventLog: Bool
    var enableHaptics: Bool

    // ZCTA bundle metadata snapshot (for quick UI display)
    var zctaBundleVersion: String
    var zctaBundleDate: String
    var zctaBundleCount: Int
    var zctaBundleIsProduction: Bool

    init(id: UUID = UUID()) {
        self.id = id
        self.hasCompletedOnboarding = false
        self.trackingEnabled = false
        self.hasSeenAlwaysPermissionEducation = false
        self.hasRequestedAlwaysPermission = false

        let defaultMode = TrackingMode.balanced
        self.trackingModeRaw = defaultMode.rawValue
        self.distanceFilterMeters = 200
        self.desiredAccuracyMeters = 100
        self.pauseAutomatically = false
        self.showBackgroundLocationIndicator = true

        self.transitionCooldownSeconds = 90
        self.requireTwoConsecutiveMatchesNearBoundary = true
        self.rejectLocationsWorseThanMeters = 500

        self.showVisitedBoundaries = true
        self.showAllVisibleBoundaries = true
        self.showVisitPins = true
        self.showDiscoveredPins = true
        self.mapStyleRaw = MapDisplayStyle.standard.rawValue
        self.lastMapCenterLatitude = 37.7749
        self.lastMapCenterLongitude = -122.4194
        self.lastMapLatitudeDelta = 0.2
        self.lastMapLongitudeDelta = 0.2

        self.storeDiagnosticEventLog = true
        self.enableHaptics = true

        self.zctaBundleVersion = "unknown"
        self.zctaBundleDate = "unknown"
        self.zctaBundleCount = 0
        self.zctaBundleIsProduction = false
    }

    var trackingMode: TrackingMode {
        get { TrackingMode(rawValue: trackingModeRaw) ?? .balanced }
        set {
            trackingModeRaw = newValue.rawValue
            distanceFilterMeters = newValue.distanceFilterMeters
            desiredAccuracyMeters = newValue.desiredAccuracy.clampedAccuracyMeters
            pauseAutomatically = newValue.pausesAutomatically
        }
    }

    var mapStyle: MapDisplayStyle {
        get { MapDisplayStyle(rawValue: mapStyleRaw) ?? .standard }
        set { mapStyleRaw = newValue.rawValue }
    }
}

private extension CLLocationAccuracy {
    /// Some `desiredAccuracy` presets are sentinel negatives (e.g. kCLLocationAccuracyKilometer
    /// is a positive value, but guard against any non-positive sentinel just in case).
    var clampedAccuracyMeters: Double {
        self > 0 ? self : 1000
    }
}
