import Foundation

/// Codable DTOs for full local export. These are *not* SwiftData models; they
/// are snapshots assembled by `ExportService` and serialized to JSON/CSV files
/// stored on-device (and optionally shared by the user via the share sheet).

struct ZCTABundleMetadataDTO: Codable, Sendable {
    var version: String
    var sourceName: String
    var buildDate: String
    var featureCount: Int
    var isProduction: Bool
}

struct TrackedZCTAExportDTO: Codable, Sendable {
    var zctaCode: String
    var displayName: String
    var note: String
    var firstEnteredAt: Date
    var lastEnteredAt: Date
    var lastSeenAt: Date
    var visitCount: Int
    var totalDurationSeconds: Double
    var firstEntryLatitude: Double
    var firstEntryLongitude: Double
    var centroidLatitude: Double
    var centroidLongitude: Double
    var isFavorite: Bool
    var isArchived: Bool
}

struct ZCTAVisitExportDTO: Codable, Sendable {
    var visitId: UUID
    var zctaCode: String
    var enteredAt: Date
    var exitedAt: Date?
    var durationSeconds: Double
    var entryLatitude: Double
    var entryLongitude: Double
    var lastLatitude: Double
    var lastLongitude: Double
    var detectionSource: String
    var confidence: String
    var acceptedSampleCount: Int
    var isSimulated: Bool
}

struct TrackingEventLogExportDTO: Codable, Sendable {
    var timestamp: Date
    var type: String
    var message: String
    var zctaCode: String?
    var latitude: Double?
    var longitude: Double?
}

/// Top-level full-export envelope.
struct FullExportRecord: Codable, Sendable {
    var appName: String
    var exportVersion: Int
    var generatedAt: Date
    var zctaBundleMetadata: ZCTABundleMetadataDTO
    var trackedZCTAs: [TrackedZCTAExportDTO]
    var visits: [ZCTAVisitExportDTO]
    var eventLogs: [TrackingEventLogExportDTO]?
}
