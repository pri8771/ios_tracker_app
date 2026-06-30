import SwiftUI

/// Top-level routing view. Reads the shared `DependencyContainer` from the
/// environment and hands it to `RootViewContent`, which can build the
/// `RootViewModel` in its initializer (env objects are not available in init).
struct RootView: View {
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        RootViewContent(container: container)
    }
}

private struct RootViewContent: View {
    @StateObject private var vm: RootViewModel
    let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: RootViewModel(container: container))
    }

    var body: some View {
        Group {
            switch vm.route {
            case .onboarding:
                OnboardingView { enableTracking in
                    vm.completeOnboarding()
                    if enableTracking { vm.enableTracking() }
                }
            case .main:
                AppTabView(container: container, settings: vm.settings, rootViewModel: vm)
            }
        }
        .sheet(isPresented: $vm.showPermissionEducation) {
            PermissionEducationView(
                authorizationState: container.locationService.authorizationState,
                onContinue: vm.requestAlwaysAuthorization,
                onDismiss: { vm.showPermissionEducation = false }
            )
        }
    }
}
