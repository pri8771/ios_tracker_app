import Foundation
import SwiftData

/// Generates and clears DEBUG sample data so the app's screens have content to
/// show in the Simulator. Generated rows are flagged `isSimulated`.
@MainActor
struct SampleDataService {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Codes + centroids approximating the bundled sample ZCTAs (San Francisco).
    private static let seeds: [(code: String, lat: Double, lon: Double)] = [
        ("94102", 37.7793, -122.4193),
        ("94103", 37.7725, -122.4109),
        ("94107", 37.7620, -122.3940)
    ]

    /// Creates a handful of discovered ZCTAs, each with a few timestamped visits.
    func generateSampleVisits(now: Date = .now) {
        for (offset, seed) in Self.seeds.enumerated() {
            let firstEntered = now.addingTimeInterval(-Double(offset + 1) * 86_400)

            let tracked = TrackedZCTAStore.upsert(code: seed.code, in: context) {
                TrackedZCTA(
                    zctaCode: seed.code,
                    createdAt: firstEntered,
                    firstEnteredAt: firstEntered,
                    firstEntryLatitude: seed.lat,
                    firstEntryLongitude: seed.lon,
                    firstEntryHorizontalAccuracyMeters: 25,
                    centroidLatitude: seed.lat,
                    centroidLongitude: seed.lon
                )
            }.model

            // Two visits per ZCTA: one closed, one more recent closed.
            for visitIndex in 0..<2 {
                let entered = firstEntered.addingTimeInterval(Double(visitIndex) * 3_600)
                let exited = entered.addingTimeInterval(1_800 + Double(visitIndex) * 600)
                let visit = ZCTAVisit(
                    zctaCode: seed.code,
                    enteredAt: entered,
                    entryLatitude: seed.lat,
                    entryLongitude: seed.lon,
                    detectionSource: .simulated,
                    confidence: .high,
                    isSimulated: true,
                    trackedZCTA: tracked
                )
                visit.lastSeenAt = exited
                visit.exitedAt = exited
                visit.isOpenFlag = false
                context.insert(visit)

                tracked.visitCount += 1
                tracked.totalDurationSeconds += visit.duration
                tracked.lastEnteredAt = max(tracked.lastEnteredAt, entered)
                tracked.lastSeenAt = max(tracked.lastSeenAt, exited)
                tracked.updatedAt = now
            }
        }
        try? context.save()
        NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
    }

    /// Codes spread across several states, for showcasing the Progress + Share
    /// screens in DEBUG screenshots. Coordinates are nominal (these may have no
    /// bundled polygon — the coverage rollup resolves state from the code).
    private static let showcaseSeeds: [(code: String, count: Int)] = [
        ("94102", 6), ("94103", 4), ("94107", 3), ("94110", 5), ("90001", 4),
        ("90210", 2), ("92101", 3), ("95814", 2), ("94301", 3),     // CA
        ("89101", 4), ("89701", 2), ("89501", 1),                    // NV
        ("97201", 3), ("97401", 2),                                  // OR
        ("10001", 5), ("10011", 2), ("11201", 3),                    // NY
        ("75201", 2), ("78701", 3),                                  // TX
        ("98101", 2), ("85001", 1), ("80202", 2)                     // WA, AZ, CO
    ]

    /// Seeds a multi-state showcase dataset (DEBUG previews/screenshots only).
    func generateShowcaseVisits(now: Date = .now) {
        for (offset, seed) in Self.showcaseSeeds.enumerated() {
            let firstEntered = now.addingTimeInterval(-Double(offset + 1) * 36_000)
            let tracked = TrackedZCTAStore.upsert(code: seed.code, in: context) {
                TrackedZCTA(
                    zctaCode: seed.code,
                    createdAt: firstEntered,
                    firstEnteredAt: firstEntered,
                    firstEntryLatitude: 37.77, firstEntryLongitude: -122.41,
                    firstEntryHorizontalAccuracyMeters: 25,
                    centroidLatitude: 37.77, centroidLongitude: -122.41
                )
            }.model
            for i in 0..<seed.count {
                let entered = firstEntered.addingTimeInterval(Double(i) * 1_800)
                let exited = entered.addingTimeInterval(1_200)
                let visit = ZCTAVisit(
                    zctaCode: seed.code, enteredAt: entered,
                    entryLatitude: 37.77, entryLongitude: -122.41,
                    detectionSource: .simulated, confidence: .high,
                    isSimulated: true, trackedZCTA: tracked
                )
                visit.lastSeenAt = exited
                visit.exitedAt = exited
                visit.isOpenFlag = false
                context.insert(visit)
                tracked.visitCount += 1
                tracked.totalDurationSeconds += visit.duration
                tracked.lastEnteredAt = max(tracked.lastEnteredAt, entered)
                tracked.lastSeenAt = max(tracked.lastSeenAt, exited)
            }
        }
        try? context.save()
        NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
    }

    /// Removes all simulated visits and any tracked ZCTA left with no visits.
    func clearSimulatedData() {
        let simulatedVisits = (try? context.fetch(
            FetchDescriptor<ZCTAVisit>(predicate: #Predicate { $0.isSimulated })
        )) ?? []
        for visit in simulatedVisits { context.delete(visit) }

        let allTracked = (try? context.fetch(FetchDescriptor<TrackedZCTA>())) ?? []
        for tracked in allTracked where (tracked.visits.allSatisfy { $0.isSimulated }) {
            context.delete(tracked)
        }
        try? context.save()
        NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
    }
}
