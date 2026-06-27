import Foundation
import SwiftData

/// Owns the rules for turning a stream of ZCTA matches into discrete visit
/// segments, with anti-jitter protection near boundaries.
///
/// State machine (per accepted, matched sample):
/// - No open visit, code never seen → `startedFirstVisit` (creates TrackedZCTA + visit).
/// - No open visit, code seen before → `revisited` (new visit, existing TrackedZCTA).
/// - Open visit, same code → `updatedCurrentVisit`.
/// - Open visit, different code → anti-jitter; on confirmation `transitioned`,
///   else `ignored`.
final class VisitTransitionService {

    private let context: ModelContext

    /// Minimum dwell (seconds) in the current visit before a transition is allowed.
    var cooldownSeconds: TimeInterval
    /// Require two consecutive matches of the new code before transitioning.
    var requireTwoConsecutiveMatches: Bool

    // Anti-jitter pending candidate state (in-memory).
    private var pendingCode: String?
    private var pendingCount: Int = 0

    init(
        context: ModelContext,
        cooldownSeconds: TimeInterval = AppConstants.Detection.defaultTransitionCooldownSeconds,
        requireTwoConsecutiveMatches: Bool = true
    ) {
        self.context = context
        self.cooldownSeconds = cooldownSeconds
        self.requireTwoConsecutiveMatches = requireTwoConsecutiveMatches
    }

    // MARK: - Main entry

    @discardableResult
    func process(match: ZCTAMatch, sample: LocationSample, now: Date = .now) -> VisitTransitionResult {
        let activeVisit = fetchOpenVisit()

        guard let activeVisit else {
            // No open visit: start a new one (first visit or revisit).
            resetPending()
            let existing = fetchTrackedZCTA(code: match.code)
            let tracked = existing ?? createTrackedZCTA(match: match, sample: sample, now: now)
            openVisit(for: tracked, match: match, sample: sample, now: now)
            if existing == nil {
                return .startedFirstVisit(code: match.code)
            } else {
                return .revisited(code: match.code)
            }
        }

        if activeVisit.zctaCode == match.code {
            // Same ZCTA: extend the current visit.
            resetPending()
            updateOpenVisit(activeVisit, sample: sample, now: now)
            return .updatedCurrentVisit(code: match.code)
        }

        // Different ZCTA: apply anti-jitter.
        if pendingCode == match.code {
            pendingCount += 1
        } else {
            pendingCode = match.code
            pendingCount = 1
        }

        let consecutiveOK = pendingCount >= (requireTwoConsecutiveMatches ? 2 : 1)
        let dwell = now.timeIntervalSince(activeVisit.enteredAt)
        let cooldownOK = dwell >= cooldownSeconds

        guard consecutiveOK && cooldownOK else {
            let reason = !consecutiveOK
                ? "awaiting \(requireTwoConsecutiveMatches ? 2 : 1) consecutive matches (have \(pendingCount))"
                : "cooldown not elapsed (\(Int(dwell))s / \(Int(cooldownSeconds))s)"
            return .ignored(reason: reason)
        }

        // Confirmed transition: close old visit, open new one.
        resetPending()
        closeVisit(activeVisit, at: now)

        let existing = fetchTrackedZCTA(code: match.code)
        let tracked = existing ?? createTrackedZCTA(match: match, sample: sample, now: now)
        openVisit(for: tracked, match: match, sample: sample, now: now)

        return .transitioned(from: activeVisit.zctaCode, to: match.code)
    }

    /// Closes any open visit (e.g. when tracking stops or unknown persists).
    func closeActiveVisit(at date: Date = .now) {
        guard let active = fetchOpenVisit() else { return }
        closeVisit(active, at: date)
        resetPending()
    }

    // MARK: - Fetch helpers

    private func fetchOpenVisit() -> ZCTAVisit? {
        var descriptor = FetchDescriptor<ZCTAVisit>(
            predicate: #Predicate { $0.exitedAt == nil },
            sortBy: [SortDescriptor(\.enteredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchTrackedZCTA(code: String) -> TrackedZCTA? {
        var descriptor = FetchDescriptor<TrackedZCTA>(
            predicate: #Predicate { $0.zctaCode == code }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Mutations

    private func createTrackedZCTA(match: ZCTAMatch, sample: LocationSample, now: Date) -> TrackedZCTA {
        let tracked = TrackedZCTA(
            zctaCode: match.code,
            createdAt: now,
            firstEnteredAt: now,
            firstEntryLatitude: sample.coordinate.latitude,
            firstEntryLongitude: sample.coordinate.longitude,
            firstEntryHorizontalAccuracyMeters: sample.horizontalAccuracyMeters,
            centroidLatitude: match.centroid.latitude,
            centroidLongitude: match.centroid.longitude
        )
        context.insert(tracked)
        // A brand-new TrackedZCTA is a discovery → notify (haptics/pins).
        NotificationCenter.default.post(
            name: AppConstants.Notifications.zctaDiscovered,
            object: nil,
            userInfo: ["code": match.code]
        )
        return tracked
    }

    private func openVisit(for tracked: TrackedZCTA, match: ZCTAMatch, sample: LocationSample, now: Date) {
        let visit = ZCTAVisit(
            zctaCode: match.code,
            enteredAt: now,
            entryLatitude: sample.coordinate.latitude,
            entryLongitude: sample.coordinate.longitude,
            detectionSource: sample.source,
            confidence: sample.confidence,
            isSimulated: sample.isSimulated,
            trackedZCTA: tracked
        )
        context.insert(visit)

        tracked.updatedAt = now
        tracked.lastEnteredAt = now
        tracked.lastSeenAt = now
        tracked.lastLatitude = sample.coordinate.latitude
        tracked.lastLongitude = sample.coordinate.longitude
        tracked.visitCount += 1
    }

    private func updateOpenVisit(_ visit: ZCTAVisit, sample: LocationSample, now: Date) {
        visit.lastSeenAt = now
        visit.lastLatitude = sample.coordinate.latitude
        visit.lastLongitude = sample.coordinate.longitude
        visit.acceptedSampleCount += 1

        if let tracked = visit.trackedZCTA {
            tracked.updatedAt = now
            tracked.lastSeenAt = now
            tracked.lastLatitude = sample.coordinate.latitude
            tracked.lastLongitude = sample.coordinate.longitude
        }
    }

    private func closeVisit(_ visit: ZCTAVisit, at date: Date) {
        let exit = max(date, visit.lastSeenAt)
        visit.exitedAt = exit
        if let tracked = visit.trackedZCTA {
            tracked.totalDurationSeconds += visit.duration
            tracked.updatedAt = exit
        }
    }

    private func resetPending() {
        pendingCode = nil
        pendingCount = 0
    }
}
