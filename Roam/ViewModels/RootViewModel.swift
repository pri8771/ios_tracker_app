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
    }

    /// Called when the user toggles tracking on. Walks the permission flow:
    /// When-In-Use first, then (after education) Always.
    func enableTracking() {
        let auth = container.locationService.authorizationState
        switch auth {
        case .notDetermined:
            container.locationService.onWhenInUseGranted = { [weak self] in
                self?.presentAlwaysEducationIfNeeded()
            }
            container.locationService.requestWhenInUseAuthorization()
        case .whenInUse, .whenInUseReducedAccuracy:
            presentAlwaysEducationIfNeeded()
        case .always, .alwaysReducedAccuracy:
            settings.trackingEnabled = true
            try? container.mainContext.save()
            container.syncTracking(with: settings)
        case .denied, .restricted:
            // UI surfaces a "open Settings" affordance; nothing to request.
            break
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
