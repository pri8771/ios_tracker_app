import Foundation
import SwiftData

/// A single continuous visit segment to a ZIP Code Area (Census ZCTA).
///
/// A visit opens when the detected ZCTA becomes active and closes when the user
/// transitions to a different ZCTA (or tracking stops). `exitedAt == nil` means
/// the visit is still open / current.
@Model
final class ZCTAVisit {
    @Attribute(.unique) var id: UUID
    var zctaCode: String

    var enteredAt: Date
    var exitedAt: Date?

    /// Stored mirror of `exitedAt == nil`, maintained in lockstep with `exitedAt`.
    /// Fetch predicates query this Bool instead of comparing the optional `Date`
    /// to `nil` — SwiftData traps (`EXC_BREAKPOINT`) on optional-to-nil predicate
    /// comparisons, so an open-visit fetch must go through a non-optional flag.
    var isOpenFlag: Bool = true

    var entryLatitude: Double
    var entryLongitude: Double

    var lastSeenAt: Date
    var lastLatitude: Double
    var lastLongitude: Double

    // Stored raw values for `DetectionSource` / `DetectionConfidence`.
    var detectionSourceRaw: String
    var confidenceRaw: String

    var acceptedSampleCount: Int
    var isSimulated: Bool

    @Relationship var trackedZCTA: TrackedZCTA?

    init(
        id: UUID = UUID(),
        zctaCode: String,
        enteredAt: Date,
        entryLatitude: Double,
        entryLongitude: Double,
        detectionSource: DetectionSource,
        confidence: DetectionConfidence,
        isSimulated: Bool = false,
        trackedZCTA: TrackedZCTA? = nil
    ) {
        self.id = id
        self.zctaCode = zctaCode
        self.enteredAt = enteredAt
        self.exitedAt = nil
        self.isOpenFlag = true
        self.entryLatitude = entryLatitude
        self.entryLongitude = entryLongitude
        self.lastSeenAt = enteredAt
        self.lastLatitude = entryLatitude
        self.lastLongitude = entryLongitude
        self.detectionSourceRaw = detectionSource.rawValue
        self.confidenceRaw = confidence.rawValue
        self.acceptedSampleCount = 1
        self.isSimulated = isSimulated
        self.trackedZCTA = trackedZCTA
    }

    var detectionSource: DetectionSource {
        DetectionSource(rawValue: detectionSourceRaw) ?? .standardLocation
    }

    var confidence: DetectionConfidence {
        DetectionConfidence(rawValue: confidenceRaw) ?? .low
    }

    var isOpen: Bool { exitedAt == nil }

    /// Closes this visit at `date`, keeping `exitedAt` and `isOpenFlag` consistent.
    func close(at date: Date) {
        let end = max(date, lastSeenAt)
        exitedAt = end
        isOpenFlag = false
    }

    /// Duration in seconds. For an open visit, measured up to `lastSeenAt`.
    var duration: TimeInterval {
        let end = exitedAt ?? lastSeenAt
        return max(0, end.timeIntervalSince(enteredAt))
    }
}
