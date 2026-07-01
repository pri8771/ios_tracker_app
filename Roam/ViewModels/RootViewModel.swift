import Foundation
import SwiftUI
import SwiftData
import Combine

/// Drives top-level navigation: onboarding → main tabs, plus the permission
/// education gate before requesting Always authorization.
@MainActor
final class RootViewModel: ObservableObject {

    enum Route: Equatable {
        case onboarding
        case main
    }

    @Published var route: Route = .onboarding
    @Published var showPermissionEducation = false

    let container: DependencyContainer
    let settings: AppSettings

    private var cancellables = Set<AnyCancellable>()

    init(container: DependencyContainer) {
        self.container = container
        self.settings = container.loadOrCreateSettings()
        self.route = settings.hasCompletedOnboarding ? .main : .onboarding
        if settings.hasCompletedOnboarding {
            container.locationService.refreshCurrentLocationIfAuthorized(mode: settings.trackingMode)
        }

        // Keep runtime state in sync when authorization changes.
        NotificationCenter.default.publisher(for: AppConstants.Notifications.authorizationDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleAuthorizationChange()
            }
            .store(in: &cancellables)
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        try? container.mainContext.save()
        route = .main
        container.locationService.refreshCurrentLocationIfAuthorized(mode: settings.trackingMode)
    }

    /// Called when the user toggles tracking on. Walks the permission flow:
    /// When-In-Use first, then (after education) Always.
    func enableTracking() {
        let auth = container.locationService.authorizationState

        // Can't enable when denied/restricted — the UI surfaces an "open Settings"
        // affordance and the toggle stays off (don't claim an intent we can't honor).
        guard auth != .denied, auth != .restricted else { return }

        // Record the user's intent to track up-front so the Settings toggle, the
        // limited (foreground-only) mode after a When-In-Use-only grant, and the
        // background-relaunch resume all stay consistent — not only after Always.
        settings.trackingEnabled = true
        try? container.mainContext.save()

        switch auth {
        case .notDetermined:
            container.locationService.onWhenInUseGranted = { [weak self] in
                self?.presentAlwaysEducationIfNeeded()
            }
            // Arm the foreground first-win so the user sees their current area
            // colored in immediately after granting When-In-Use.
            container.locationService.prepareForegroundFirstWin(mode: settings.trackingMode)
            container.locationService.requestWhenInUseAuthorization()
        case .whenInUse, .whenInUseReducedAccuracy:
            container.syncTracking(with: settings)
            presentAlwaysEducationIfNeeded()
        case .always, .alwaysReducedAccuracy:
            container.syncTracking(with: settings)
        case .denied, .restricted:
            break  // unreachable (guarded above)
        }
    }

    func disableTracking() {
        settings.trackingEnabled = false
        try? container.mainContext.save()
        container.syncTracking(with: settings)
    }

    func presentAlwaysEducationIfNeeded() {
        if settings.hasRequestedAlwaysPermission,
           container.locationService.authorizationState.allowsBackgroundTracking {
            settings.trackingEnabled = true
            try? container.mainContext.save()
            container.syncTracking(with: settings)
            return
        }
        showPermissionEducation = true
    }

    /// Invoked from `PermissionEducationView` when the user proceeds.
    func requestAlwaysAuthorization() {
        settings.hasSeenAlwaysPermissionEducation = true
        settings.hasRequestedAlwaysPermission = true
        settings.trackingEnabled = true
        try? container.mainContext.save()
        container.locationService.requestAlwaysAuthorization()
        showPermissionEducation = false
        // Foreground updates begin immediately; background upgrades on grant.
        container.syncTracking(with: settings)
    }

    private func handleAuthorizationChange() {
        container.updateRuntimeState(trackingEnabled: settings.trackingEnabled)
    }
}
