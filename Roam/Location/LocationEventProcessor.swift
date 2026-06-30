import Foundation
import SwiftData
import CoreLocation

/// Sendable snapshot of the settings the processor needs. Updated whenever the
/// user changes tracking settings.
struct ProcessorConfig: Sendable {
    var rejectWorseThanMeters: CLLocationDistance
    var transitionCooldownSeconds: TimeInterval
    var requireTwoConsecutiveMatches: Bool
    var storeDiagnosticEventLog: Bool
    /// Auto-color accuracy gate (meters); fixes coarser than this never color.
    var autoColorMaxAccuracyMeters: CLLocationDistance
    var autoColorBoundaryMarginMeters: CLLocationDistance

    static let `default` = ProcessorConfig(
        rejectWorseThanMeters: AppConstants.Detection.defaultRejectWorseThanMeters,
        transitionCooldownSeconds: AppConstants.Detection.defaultTransitionCooldownSeconds,
        requireTwoConsecutiveMatches: true,
        storeDiagnosticEventLog: true,
        autoColorMaxAccuracyMeters: AppConstants.Detection.autoColorMaxAccuracyMeters,
        autoColorBoundaryMarginMeters: AppConstants.Detection.autoColorBoundaryMarginMeters
    )
}

/// A Sendable update pushed to the main-actor `TrackingState`.
struct TrackingStateUpdate: Sendable {
    var currentCode: String?
    var visitStartedAt: Date?
    var confidence: DetectionConfidence?
    var sampleAt: Date?
    var clearVisit: Bool
}

/// Serializes all location-sample processing on its own actor executor, owning a
/// background SwiftData context. This is where raw samples become persisted
/// visits — entirely on-device, with no network or reverse geocoding.
actor LocationEventProcessor {

    private let modelContext: ModelContext
    private let index: ZCTAIndex?
    private let bundleMissing: Bool

    private var filter: LocationFilter
    private var autoColorGate: AutoColorGate
    private let transitionService: VisitTransitionService
    private var config: ProcessorConfig

    private var previousAccepted: LocationSample?
    private var consecutiveUnknowns = 0

    /// Main-actor callback used to push transient state to the UI.
    private let applyState: @Sendable (TrackingStateUpdate) -> Void

    init(
        container: ModelContainer,
        index: ZCTAIndex?,
        bundleMissing: Bool,
        config: ProcessorConfig = .default,
        applyState: @escaping @Sendable (TrackingStateUpdate) -> Void
    ) {
        self.modelContext = ModelContext(container)
        self.index = index
        self.bundleMissing = bundleMissing
        self.config = config
        self.filter = LocationFilter(rejectWorseThanMeters: config.rejectWorseThanMeters)
        self.autoColorGate = AutoColorGate(
            maxAccuracyMeters: config.autoColorMaxAccuracyMeters,
            boundaryMarginMeters: config.autoColorBoundaryMarginMeters
        )
        self.transitionService = VisitTransitionService(
            context: modelContext,
            cooldownSeconds: config.transitionCooldownSeconds,
            requireTwoConsecutiveMatches: config.requireTwoConsecutiveMatches
        )
        self.applyState = applyState
    }

    func updateConfig(_ newConfig: ProcessorConfig) {
        self.config = newConfig
        self.filter = LocationFilter(rejectWorseThanMeters: newConfig.rejectWorseThanMeters)
        self.autoColorGate = AutoColorGate(
            maxAccuracyMeters: newConfig.autoColorMaxAccuracyMeters,
            boundaryMarginMeters: newConfig.autoColorBoundaryMarginMeters
        )
        transitionService.cooldownSeconds = newConfig.transitionCooldownSeconds
        transitionService.requireTwoConsecutiveMatches = newConfig.requireTwoConsecutiveMatches
    }

    /// Closes any open visit (called when tracking stops).
    func endActiveVisit(at date: Date = .now) {
        transitionService.closeActiveVisit(at: date)
        save()
        applyState(TrackingStateUpdate(currentCode: nil, visitStartedAt: nil, confidence: nil, sampleAt: nil, clearVisit: true))
    }

    /// Main pipeline entry. Filters, resolves to a ZCTA, applies transition rules.
    func process(
        coordinate: Coordinate,
        horizontalAccuracy: CLLocationDistance,
        timestamp: Date,
        source: DetectionSource,
        isSimulated: Bool,
        now: Date = .now
    ) {
        if bundleMissing {
            log(.zctaBundleMissing, "ZCTA bundle missing; sample ignored.")
            return
        }

        let result = filter.evaluate(
            coordinate: coordinate,
            horizontalAccuracy: horizontalAccuracy,
            timestamp: timestamp,
            now: now,
            source: source,
            isSimulated: isSimulated,
            previous: previousAccepted
        )

        switch result {
        case .rejected(let reason):
            if case .poorAccuracy = reason {
                log(.locationRejectedLowAccuracy, "Rejected sample: \(reason)")
            }
            return
        case .accepted(let sample):
            previousAccepted = sample
            log(.locationAccepted, "Accepted \(sample.source.displayName) sample (±\(Int(sample.horizontalAccuracyMeters))m).",
                lat: sample.coordinate.latitude, lon: sample.coordinate.longitude)
            resolve(sample: sample, now: now)
        }
    }

    // MARK: - Resolution

    private func resolve(sample: LocationSample, now: Date) {
        guard let index else {
            log(.zctaBundleMissing, "No ZCTA index available.")
            return
        }

        guard let match = index.match(coordinate: sample.coordinate) else {
            consecutiveUnknowns += 1
            log(.zctaUnknown, "Coordinate outside all known ZCTAs (\(consecutiveUnknowns)).",
                lat: sample.coordinate.latitude, lon: sample.coordinate.longitude)
            // Allow a few unknowns before closing the active visit.
            if consecutiveUnknowns > AppConstants.Detection.maxConsecutiveUnknownsBeforeClose {
                transitionService.closeActiveVisit(at: now)
                save()
                applyState(TrackingStateUpdate(currentCode: nil, visitStartedAt: nil,
                                               confidence: nil, sampleAt: now, clearVisit: true))
            }
            return
        }

        consecutiveUnknowns = 0
        log(.zctaDetected, "Detected ZCTA \(match.code).", code: match.code,
            lat: sample.coordinate.latitude, lon: sample.coordinate.longitude)

        // Auto-color gate: only high-confidence, boundary-clear fixes may create
        // or transition a colored patch. Lower-confidence fixes are deliberately
        // not colored — a wrong patch erodes trust more than a missing one.
        let decision = autoColorGate.evaluate(
            horizontalAccuracy: sample.horizontalAccuracyMeters,
            distanceToBoundaryMeters: match.boundaryDistanceMeters,
            isSimulated: sample.isSimulated
        )
        guard decision.allowsColoring else {
            switch decision {
            case .skipLowAccuracy(let meters):
                log(.locationRejectedLowAccuracy,
                    "Detected \(match.code) but did not color: accuracy ±\(Int(meters))m exceeds auto-color gate.",
                    code: match.code)
            case .skipNearBoundary(let edge):
                log(.locationRejectedLowAccuracy,
                    "Detected \(match.code) but did not color: \(Int(edge))m from boundary (ambiguous).",
                    code: match.code)
            case .color:
                break
            }
            return
        }

        let transition = transitionService.process(match: match, sample: sample, now: now)

        switch transition {
        case .startedFirstVisit(let code), .revisited(let code), .updatedCurrentVisit(let code):
            pushCurrent(code: code, sample: sample, now: now)
        case .transitioned(let from, let to):
            log(.zctaTransition, "Transitioned from \(from) to \(to).", code: to)
            pushCurrent(code: to, sample: sample, now: now)
        case .ignored:
            break
        }

        save()
    }

    private func pushCurrent(code: String, sample: LocationSample, now: Date) {
        // Find the open visit's start time for accurate UI display.
        let startedAt = fetchOpenVisitStart() ?? now
        applyState(TrackingStateUpdate(
            currentCode: code,
            visitStartedAt: startedAt,
            confidence: sample.confidence,
            sampleAt: now,
            clearVisit: false
        ))
        NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
    }

    /// Start time of the current open visit, if any. Predicate-free fetch of the
    /// latest visit (see `VisitTransitionService.fetchOpenVisit` for rationale).
    private func fetchOpenVisitStart() -> Date? {
        var descriptor = FetchDescriptor<ZCTAVisit>(
            sortBy: [SortDescriptor(\.enteredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let latest = (try? modelContext.fetch(descriptor))?.first else { return nil }
        return latest.isOpenFlag ? latest.enteredAt : nil
    }

    // MARK: - Persistence + diagnostics

    private func save() {
        do {
            if modelContext.hasChanges {
                try modelContext.save()
            }
        } catch {
            // Roll back so a failed save (e.g. a unique-constraint collision from
            // a concurrent writer) doesn't leave the context in a poisoned state.
            modelContext.rollback()
            log(.error, "Save failed (rolled back): \(error.localizedDescription)", persistEvenIfDisabled: true)
        }
    }

    func log(
        _ type: TrackingEventType,
        _ message: String,
        code: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil,
        persistEvenIfDisabled: Bool = false
    ) {
        guard config.storeDiagnosticEventLog || persistEvenIfDisabled else { return }
        let event = TrackingEventLog(type: type, message: message, zctaCode: code, latitude: lat, longitude: lon)
        modelContext.insert(event)
        pruneEventLog()
        try? modelContext.save()
    }

    private func pruneEventLog() {
        let countDescriptor = FetchDescriptor<TrackingEventLog>()
        guard let total = try? modelContext.fetchCount(countDescriptor),
              total > AppConstants.Persistence.maxEventLogCount else { return }
        let overflow = total - AppConstants.Persistence.maxEventLogCount
        var oldest = FetchDescriptor<TrackingEventLog>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        oldest.fetchLimit = overflow
        if let rows = try? modelContext.fetch(oldest) {
            for row in rows { modelContext.delete(row) }
        }
    }
}
