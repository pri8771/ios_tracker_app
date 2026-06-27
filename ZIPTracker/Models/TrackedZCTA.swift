import Foundation
import SwiftData
import CoreLocation

/// A ZIP Code Area (Census ZCTA) the user has discovered at least once.
///
/// One `TrackedZCTA` exists per unique ZCTA code; revisits create new
/// `ZCTAVisit` rows but never duplicate the tracked ZCTA. Codes are stored as
/// `String` so leading zeros (e.g. "01776") are preserved.
@Model
final class TrackedZCTA {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var zctaCode: String

    var createdAt: Date
    var updatedAt: Date

    // First discovery
    var firstEnteredAt: Date
    var firstEntryLatitude: Double
    var firstEntryLongitude: Double
    var firstEntryHorizontalAccuracyMeters: Double

    // Most recent activity
    var lastEnteredAt: Date
    var lastSeenAt: Date
    var lastLatitude: Double
    var lastLongitude: Double

    // Geometry hint (polygon centroid, used for pins/labels)
    var centroidLatitude: Double
    var centroidLongitude: Double

    // User customization
    var displayName: String
    var note: String
    var isFavorite: Bool
    var isArchived: Bool

    // Aggregates (maintained incrementally; recomputable from visits)
    var visitCount: Int
    var totalDurationSeconds: Double

    @Relationship(deleteRule: .cascade, inverse: \ZCTAVisit.trackedZCTA)
    var visits: [ZCTAVisit]

    init(
        id: UUID = UUID(),
        zctaCode: String,
        createdAt: Date = .now,
        firstEnteredAt: Date,
        firstEntryLatitude: Double,
        firstEntryLongitude: Double,
        firstEntryHorizontalAccuracyMeters: Double,
        centroidLatitude: Double,
        centroidLongitude: Double,
        displayName: String = "",
        note: String = "",
        isFavorite: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.zctaCode = zctaCode
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.firstEnteredAt = firstEnteredAt
        self.firstEntryLatitude = firstEntryLatitude
        self.firstEntryLongitude = firstEntryLongitude
        self.firstEntryHorizontalAccuracyMeters = firstEntryHorizontalAccuracyMeters
        self.lastEnteredAt = firstEnteredAt
        self.lastSeenAt = firstEnteredAt
        self.lastLatitude = firstEntryLatitude
        self.lastLongitude = firstEntryLongitude
        self.centroidLatitude = centroidLatitude
        self.centroidLongitude = centroidLongitude
        self.displayName = displayName
        self.note = note
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.visitCount = 0
        self.totalDurationSeconds = 0
        self.visits = []
    }

    var centroidCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centroidLatitude, longitude: centroidLongitude)
    }

    /// Title shown in lists; falls back to the raw code.
    var resolvedTitle: String {
        displayName.isEmpty ? zctaCode : displayName
    }
}
