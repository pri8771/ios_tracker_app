import Foundation
import CoreLocation

// MARK: - Tracking mode

/// Battery/accuracy trade-off presets for background tracking.
enum TrackingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case batterySaver
    case balanced
    case highAccuracy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .batterySaver: return "Battery Saver"
        case .balanced: return "Balanced"
        case .highAccuracy: return "High Accuracy"
        }
    }

    var subtitle: String {
        switch self {
        case .batterySaver: return "Lowest battery use, coarser ZIP detection."
        case .balanced: return "Recommended. Good detection with modest battery use."
        case .highAccuracy: return "Most precise ZIP detection, highest battery use."
        }
    }

    /// Default `CLLocationManager.distanceFilter` (meters) for this mode.
    var distanceFilterMeters: CLLocationDistance {
        switch self {
        case .batterySaver: return 500
        case .balanced: return 200
        case .highAccuracy: return 75
        }
    }

    /// Default `CLLocationManager.desiredAccuracy` for this mode.
    var desiredAccuracy: CLLocationAccuracy {
        switch self {
        case .batterySaver: return kCLLocationAccuracyKilometer
        case .balanced: return kCLLocationAccuracyHundredMeters
        case .highAccuracy: return kCLLocationAccuracyNearestTenMeters
        }
    }

    /// Default `pausesLocationUpdatesAutomatically` for this mode.
    var pausesAutomatically: Bool {
        switch self {
        case .batterySaver: return true
        case .balanced, .highAccuracy: return false
        }
    }
}

// MARK: - Authorization

/// App-level abstraction over `CLAuthorizationStatus` + accuracy authorization.
enum LocationAuthorizationState: String, Codable, Sendable {
    case notDetermined
    case denied
    case restricted
    case whenInUse
    case always
    /// Authorized but the user granted only reduced (coarse) accuracy.
    case alwaysReducedAccuracy
    case whenInUseReducedAccuracy

    var isAuthorized: Bool {
        switch self {
        case .whenInUse, .always, .alwaysReducedAccuracy, .whenInUseReducedAccuracy:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        }
    }

    /// Whether background tracking is possible (requires Always).
    var allowsBackgroundTracking: Bool {
        self == .always || self == .alwaysReducedAccuracy
    }

    var isReducedAccuracy: Bool {
        self == .alwaysReducedAccuracy || self == .whenInUseReducedAccuracy
    }
}

// MARK: - Runtime state

/// High-level runtime state of the tracking engine, surfaced in the UI.
enum TrackingRuntimeState: String, Codable, Sendable {
    case off
    case needsAlwaysAuthorization
    case active
    case activeReducedAccuracy
    case error

    var displayName: String {
        switch self {
        case .off: return "Tracking Off"
        case .needsAlwaysAuthorization: return "Needs Always Access"
        case .active: return "Tracking Active"
        case .activeReducedAccuracy: return "Active (Reduced Accuracy)"
        case .error: return "Tracking Error"
        }
    }
}

// MARK: - Detection metadata

/// Where a detected sample originated.
enum DetectionSource: String, Codable, Sendable {
    case standardLocation
    case significantChange
    case visitMonitoring
    case simulated
    case manual

    var displayName: String {
        switch self {
        case .standardLocation: return "Standard"
        case .significantChange: return "Significant Change"
        case .visitMonitoring: return "Visit"
        case .simulated: return "Simulated"
        case .manual: return "Manual"
        }
    }
}

/// Confidence of a ZCTA match, derived from horizontal accuracy.
enum DetectionConfidence: String, Codable, Sendable {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    /// Maps a horizontal accuracy (meters) to a confidence bucket.
    static func from(horizontalAccuracy meters: CLLocationDistance) -> DetectionConfidence {
        if meters <= AppConstants.Detection.highConfidenceAccuracyMeters { return .high }
        if meters <= AppConstants.Detection.mediumConfidenceAccuracyMeters { return .medium }
        return .low
    }
}

/// Diagnostic event categories persisted in `TrackingEventLog`.
enum TrackingEventType: String, Codable, CaseIterable, Sendable {
    case trackingStarted
    case trackingStopped
    case authorizationChanged
    case locationAccepted
    case locationRejectedLowAccuracy
    case zctaDetected
    case zctaTransition
    case zctaUnknown
    case zctaBundleMissing
    case appRelaunchedForLocation
    case error
}

/// Map base style options.
enum MapDisplayStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case hybrid
    case satellite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .hybrid: return "Hybrid"
        case .satellite: return "Satellite"
        }
    }
}

// MARK: - Value structs

/// A lightweight, `Sendable` coordinate used across actor boundaries.
struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ clCoordinate: CLLocationCoordinate2D) {
        self.latitude = clCoordinate.latitude
        self.longitude = clCoordinate.longitude
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Whether this coordinate is a valid, non-null-island location.
    var isValid: Bool {
        guard latitude.isFinite, longitude.isFinite else { return false }
        guard latitude >= -90, latitude <= 90, longitude >= -180, longitude <= 180 else { return false }
        return true
    }
}

/// A filtered, app-internal location sample fed into the detection pipeline.
struct LocationSample: Codable, Equatable, Sendable {
    var coordinate: Coordinate
    var horizontalAccuracyMeters: CLLocationDistance
    var timestamp: Date
    var source: DetectionSource
    var isSimulated: Bool

    init(
        coordinate: Coordinate,
        horizontalAccuracyMeters: CLLocationDistance,
        timestamp: Date,
        source: DetectionSource,
        isSimulated: Bool = false
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.timestamp = timestamp
        self.source = source
        self.isSimulated = isSimulated
    }

    var confidence: DetectionConfidence {
        DetectionConfidence.from(horizontalAccuracy: horizontalAccuracyMeters)
    }
}

/// Result of resolving a coordinate to a Census ZCTA polygon.
struct ZCTAMatch: Codable, Hashable, Sendable {
    /// ZCTA / ZIP Code Area code. Leading zeros preserved (it is a String).
    var code: String
    var centroid: Coordinate
    var matchedCoordinate: Coordinate
    /// Distance (m) from the matched coordinate to the nearest polygon edge, used
    /// by the auto-color boundary gate. `nil` when not computed.
    var boundaryDistanceMeters: Double?

    init(code: String, centroid: Coordinate, matchedCoordinate: Coordinate, boundaryDistanceMeters: Double? = nil) {
        self.code = code
        self.centroid = centroid
        self.matchedCoordinate = matchedCoordinate
        self.boundaryDistanceMeters = boundaryDistanceMeters
    }
}

/// Outcome of feeding a matched sample to `VisitTransitionService`.
enum VisitTransitionResult: Equatable, Sendable {
    /// First-ever visit started a brand-new tracked ZCTA.
    case startedFirstVisit(code: String)
    /// Sample matched the current active ZCTA; the open visit was updated.
    case updatedCurrentVisit(code: String)
    /// Confirmed transition from one ZCTA to another.
    case transitioned(from: String, to: String)
    /// A revisit to a previously-discovered ZCTA (new visit, existing ZCTA).
    case revisited(code: String)
    /// Candidate transition was rejected by anti-jitter rules.
    case ignored(reason: String)

    /// Whether this result represents a newly discovered ZCTA (for haptics/pins).
    var isNewDiscovery: Bool {
        if case .startedFirstVisit = self { return true }
        if case .transitioned = self { return false }
        return false
    }
}
