import SwiftUI

/// The main 5-tab interface shown after onboarding. Each tab is its own
/// `NavigationStack`. Holds the `RootViewModel` reference so it can thread the
/// tracking enable/disable permission flow down to Settings.
struct AppTabView: View {

    let container: DependencyContainer
    let settings: AppSettings
    @ObservedObject var rootViewModel: RootViewModel

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(container: container, settings: settings)
            }
            .tabItem { Label("Dashboard", systemImage: "location.circle") }

            NavigationStack {
                TrackerMapView(container: container, settings: settings)
            }
            .tabItem { Label("Map", systemImage: "map") }

            NavigationStack {
                HistoryView(container: container)
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                StatisticsView(container: container, settings: settings)
            }
            .tabItem { Label("Stats", systemImage: "chart.bar") }

            NavigationStack {
                SettingsView(
                    container: container,
                    settings: settings,
                    requestEnableTracking: rootViewModel.enableTracking,
                    requestDisableTracking: rootViewModel.disableTracking
                )
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
