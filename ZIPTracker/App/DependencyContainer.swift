import Foundation
import SwiftData
import Combine

/// Composition root. Owns the long-lived services and the SwiftData container,
/// and wires the location pipeline together. Created once at app launch and held
/// for the entire app lifetime (so `CLLocationManager` survives background
/// relaunches).
@MainActor
final class DependencyContainer: ObservableObject {

    let modelContainer: ModelContainer
    let geometryService: ZCTAGeometryService
    let trackingState: TrackingState
    let processor: LocationEventProcessor
    let locationService: BackgroundLocationService
    let haptics: HapticsService

    #if DEBUG
    let simulatedPlayer: SimulatedLocationPlayer
    #endif

    private var cancellables = Set<AnyCancellable>()

    var mainContext: ModelContext { modelContainer.mainContext }

    init(inMemory: Bool = false) {
        // 1. SwiftData container.
        let schema = Schema([
            TrackedZCTA.self,
            ZCTAVisit.self,
            TrackingEventLog.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }

        // 2. ZCTA geometry / data bundle.
        let geometry = ZCTAGeometryService()
        self.geometryService = geometry

        // 3. Transient runtime state.
        let state = TrackingState()
        state.bundleStatus = geometry.status
        self.trackingState = state

        // 4. Haptics.
        self.haptics = HapticsService()

        // 5. Processor (background SwiftData context) + state bridge.
        let container = modelContainer
        self.processor = LocationEventProcessor(
            container: container,
            index: geometry.index,
            bundleMissing: geometry.status.isMissing,
            applyState: { update in
                Task { @MainActor in
                    DependencyContainer.apply(update, to: state)
                }
            }
        )

        // 6. Location service.
        self.locationService = BackgroundLocationService(processor: processor, trackingState: state)

        #if DEBUG
        self.simulatedPlayer = SimulatedLocationPlayer(processor: processor)
        #endif

        // 7. Bootstrap settings + wiring.
        bootstrapSettings()
        observeDiscoveries()
        locationService.refreshAuthorizationState()
    }

    private static func apply(_ update: TrackingStateUpdate, to state: TrackingState) {
        if update.clearVisit {
            state.clearCurrentVisit()
        } else {
            state.currentZCTACode = update.currentCode
            state.currentVisitStartedAt = update.visitStartedAt
            state.lastConfidence = update.confidence
        }
        if let sampleAt = update.sampleAt { state.lastSampleAt = sampleAt }
    }

    // MARK: - Settings

    /// Fetches the singleton `AppSettings` row, creating it on first launch, and
    /// snapshots ZCTA bundle metadata into it for display.
    @discardableResult
    func loadOrCreateSettings() -> AppSettings {
        let context = mainContext
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()), let first = existing.first {
            return first
        }
        let settings = AppSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }

    private func bootstrapSettings() {
        let settings = loadOrCreateSettings()
        if let meta = geometryService.status.metadata {
            settings.zctaBundleVersion = meta.version
            settings.zctaBundleDate = meta.buildDate
            settings.zctaBundleCount = meta.featureCount
            settings.zctaBundleIsProduction = meta.isProduction
        }
        haptics.isEnabled = settings.enableHaptics
        try? mainContext.save()
        Task { await processor.updateConfig(config(from: settings)) }
    }

    func config(from settings: AppSettings) -> ProcessorConfig {
        ProcessorConfig(
            rejectWorseThanMeters: settings.rejectLocationsWorseThanMeters,
            transitionCooldownSeconds: settings.transitionCooldownSeconds,
            requireTwoConsecutiveMatches: settings.requireTwoConsecutiveMatchesNearBoundary,
            storeDiagnosticEventLog: settings.storeDiagnosticEventLog
        )
    }

    // MARK: - Discovery haptics

    private func observeDiscoveries() {
        NotificationCenter.default.publisher(for: AppConstants.Notifications.zctaDiscovered)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.haptics.success()
            }
            .store(in: &cancellables)
    }

    // MARK: - Tracking control

    /// Applies settings to the running engine and starts/stops tracking.
    func syncTracking(with settings: AppSettings) {
        Task { await processor.updateConfig(config(from: settings)) }
        haptics.isEnabled = settings.enableHaptics
        locationService.updateBackgroundIndicator(settings.showBackgroundLocationIndicator)

        guard settings.trackingEnabled else {
            locationService.stopTracking()
            trackingState.runtimeState = .off
            return
        }

        guard geometryService.status.allowsTracking else {
            trackingState.runtimeState = .error
            trackingState.lastErrorMessage = "ZCTA data unavailable. Tracking is disabled until a valid Census ZCTA bundle is installed."
            return
        }

        locationService.startTracking(mode: settings.trackingMode)
        updateRuntimeState(trackingEnabled: true)
    }

    func updateRuntimeState(trackingEnabled: Bool) {
        let auth = locationService.authorizationState
        trackingState.authorizationState = auth
        trackingState.runtimeState = LocationAuthorizationService.runtimeState(
            trackingEnabled: trackingEnabled,
            authorization: auth,
            hasError: false
        )
    }

    func makeExportService(metadata: ZCTABundleMetadata? = nil) -> ExportService {
        ExportService(
            context: mainContext,
            bundleMetadata: metadata ?? geometryService.status.metadata ?? .unknown
        )
    }
}
