import Foundation
import Combine

/// Observable snapshot of the live tracking engine, consumed by the UI.
///
/// Updated on the main actor by `BackgroundLocationService` /
/// `LocationEventProcessor`. Holds no persistence; purely transient runtime state.
@MainActor
final class TrackingState: ObservableObject {
    @Published var runtimeState: TrackingRuntimeState = .off
    @Published var authorizationState: LocationAuthorizationState = .notDetermined

    @Published var currentZCTACode: String?
    @Published var currentVisitStartedAt: Date?
    @Published var lastConfidence: DetectionConfidence?
    @Published var lastSampleAt: Date?

    @Published var bundleStatus: ZCTABundleStatus = .missing
    @Published var lastErrorMessage: String?

    /// Convenience: are we currently relying on the small sample dataset?
    var isUsingSampleData: Bool { bundleStatus.isSample }
    var isBundleMissing: Bool { bundleStatus.isMissing }

    func clearCurrentVisit() {
        currentZCTACode = nil
        currentVisitStartedAt = nil
        lastConfidence = nil
    }
}
