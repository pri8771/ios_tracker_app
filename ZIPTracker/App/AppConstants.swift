import Foundation
import CoreLocation

/// Global, compile-time constants for ZIP Tracker.
///
/// ZIP Tracker is a local-first iOS app: every constant here governs on-device
/// behavior only. There are no server endpoints, no analytics keys, and no
/// network configuration because the app never performs app-controlled network
/// calls for ZIP/ZCTA detection.
enum AppConstants {

    /// User-facing app name.
    static let appName = "ZIP Tracker"

    /// Suggested bundle identifier (kept here for diagnostics/export only).
    static let bundleIdentifier = "com.localfirst.ziptracker"

    /// Primary product promise, surfaced in onboarding and help.
    static let primaryPromise = "Automatically collect the ZIP Code Areas you visit, privately on your iPhone."

    // MARK: - Bundled ZCTA data

    enum Bundle {
        /// File name (without extension) of the production Census ZCTA SQLite bundle.
        static let productionDatabaseName = "zcta_bundle"
        /// File name (without extension) of the tiny DEBUG/test sample bundle.
        static let sampleDatabaseName = "zcta_sample"
        static let sqliteExtension = "sqlite"
        /// Subdirectory inside the app bundle resources where the ZCTA data lives.
        static let resourceSubdirectory = "ZCTA"
    }

    // MARK: - Persistence

    enum Persistence {
        /// Maximum number of diagnostic event-log rows retained on device.
        static let maxEventLogCount = 500
        /// NSCache budget for decoded polygons held in memory.
        static let polygonCacheLimit = 200
    }

    // MARK: - Location filtering / detection defaults

    enum Detection {
        /// Confidence thresholds in meters of horizontal accuracy.
        static let highConfidenceAccuracyMeters: CLLocationDistance = 100
        static let mediumConfidenceAccuracyMeters: CLLocationDistance = 250
        static let lowConfidenceAccuracyMeters: CLLocationDistance = 500

        /// Default hard reject threshold for poor horizontal accuracy.
        static let defaultRejectWorseThanMeters: CLLocationDistance = 500

        /// Samples older than this are rejected (except visit-monitoring samples).
        static let maxSampleAgeSeconds: TimeInterval = 600

        /// Implied speed above this (m/s) is treated as an impossible GPS jump.
        static let maxImpliedSpeedMetersPerSecond: CLLocationSpeed = 100

        /// Default anti-jitter transition cooldown in seconds.
        static let defaultTransitionCooldownSeconds: TimeInterval = 90

        /// Consecutive unknown samples tolerated before an active visit may be closed.
        static let maxConsecutiveUnknownsBeforeClose = 3
    }

    // MARK: - Map / overlay tuning

    enum Map {
        /// Debounce window for recomputing visible overlays while panning/zooming.
        static let overlayDebounceSeconds: TimeInterval = 0.3
        static let discoveredPinClusterIdentifier = "zctaDiscoveredPins"
    }

    // MARK: - Export

    enum Export {
        static let exportVersion = 2
        static let directoryName = "Exports"
        static let rootDirectoryName = "ZIPTracker"
    }

    // MARK: - Notifications

    enum Notifications {
        /// Posted (on main) after persistence changes so view models can refresh.
        static let dataDidChange = Notification.Name("ZIPTracker.dataDidChange")
        /// Posted when location authorization changes.
        static let authorizationDidChange = Notification.Name("ZIPTracker.authorizationDidChange")
        /// Posted when a brand-new ZCTA is discovered (used for haptics).
        static let zctaDiscovered = Notification.Name("ZIPTracker.zctaDiscovered")
    }

    // MARK: - Help / legal copy (ZCTA disclaimers)

    enum Copy {
        static let zctaShortDisclaimer = "Boundaries shown are U.S. Census ZIP Code Tabulation Areas (ZCTAs)."
        static let zctaLongDisclaimer = """
        Map boundaries come from U.S. Census ZIP Code Tabulation Areas (ZCTAs). \
        ZCTAs are generalized Census areas that approximate ZIP Code geographies. \
        They are not official USPS delivery-route boundaries, and not every valid \
        USPS ZIP Code has a matching ZCTA polygon.
        """
        static let boundaryModeLabel = "Census ZCTA boundaries"
    }
}
