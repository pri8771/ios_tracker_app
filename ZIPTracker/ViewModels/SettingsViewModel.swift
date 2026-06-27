import Foundation
import SwiftUI
import SwiftData

/// Backs the Settings screen: tracking enable/mode, map toggles, exports, and
/// destructive data actions (plus DEBUG simulation tools).
@MainActor
final class SettingsViewModel: ObservableObject {

    let container: DependencyContainer
    let settings: AppSettings

    @Published var exportedFileURL: URL?
    @Published var errorMessage: String?
    @Published var deleteConfirmationText = ""

    init(container: DependencyContainer, settings: AppSettings) {
        self.container = container
        self.settings = settings
    }

    var authorizationState: LocationAuthorizationState { container.locationService.authorizationState }
    var runtimeState: TrackingRuntimeState { container.trackingState.runtimeState }
    var bundleStatus: ZCTABundleStatus { container.geometryService.status }

    // MARK: - Tracking

    func setTrackingMode(_ mode: TrackingMode) {
        settings.trackingMode = mode
        persist()
        container.syncTracking(with: settings)
    }

    func applyTrackingSettings() {
        persist()
        container.syncTracking(with: settings)
    }

    // MARK: - Map toggles

    func persistMapToggles() {
        persist()
        NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
    }

    // MARK: - Export

    func exportJSON(includeEventLogs: Bool) {
        run { try self.container.makeExportService().exportJSON(includeEventLogs: includeEventLogs) }
    }

    func exportVisitsCSV() {
        run { try self.container.makeExportService().exportVisitsCSV() }
    }

    func exportSummaryCSV() {
        run { try self.container.makeExportService().exportSummaryCSV() }
    }

    private func run(_ work: () throws -> URL) {
        do { exportedFileURL = try work() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Destructive

    var canConfirmDelete: Bool { deleteConfirmationText == "DELETE" }

    func deleteAllData() {
        guard canConfirmDelete else { return }
        let ctx = container.mainContext
        try? ctx.delete(model: ZCTAVisit.self)
        try? ctx.delete(model: TrackedZCTA.self)
        try? ctx.delete(model: TrackingEventLog.self)
        try? ctx.save()
        container.trackingState.clearCurrentVisit()
        deleteConfirmationText = ""
        NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
    }

    // MARK: - DEBUG tools

    #if DEBUG
    func generateSampleVisits() {
        SampleDataService(context: container.mainContext).generateSampleVisits()
    }

    func clearSampleData() {
        SampleDataService(context: container.mainContext).clearSimulatedData()
    }

    func simulateRoute() {
        let player = container.simulatedPlayer
        Task {
            await player.playFullRoute()
            NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
        }
    }

    func stepNextLocation() {
        let player = container.simulatedPlayer
        Task {
            await player.stepNext()
            NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
        }
    }

    func resetSimulatedVisits() {
        container.simulatedPlayer.reset()
        SampleDataService(context: container.mainContext).clearSimulatedData()
    }
    #endif

    private func persist() {
        try? container.mainContext.save()
    }
}
