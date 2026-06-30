import SwiftUI

/// The main 5-tab interface shown after onboarding. Each tab is its own
/// `NavigationStack`. Holds the `RootViewModel` reference so it can thread the
/// tracking enable/disable permission flow down to Settings.
struct AppTabView: View {

    let container: DependencyContainer
    let settings: AppSettings
    @ObservedObject var rootViewModel: RootViewModel

    @State private var selection = AppTabView.initialSelection

    /// DEBUG screenshot helper: `-UIPREVIEW_TAB <n>` opens a specific tab.
    private static var initialSelection: Int {
        #if DEBUG
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-UIPREVIEW_TAB"),
           idx + 1 < ProcessInfo.processInfo.arguments.count,
           let n = Int(ProcessInfo.processInfo.arguments[idx + 1]) {
            return n
        }
        #endif
        return 0
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                DashboardView(container: container, settings: settings)
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            NavigationStack {
                TrackerMapView(container: container, settings: settings)
            }
            .tabItem { Label("Map", systemImage: "map.fill") }
            .tag(1)

            NavigationStack {
                StatisticsView(container: container, settings: settings)
            }
            .tabItem { Label("Progress", systemImage: "chart.pie.fill") }
            .tag(2)

            NavigationStack {
                HistoryView(container: container)
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(3)

            NavigationStack {
                SettingsView(
                    container: container,
                    settings: settings,
                    requestEnableTracking: rootViewModel.enableTracking,
                    requestDisableTracking: rootViewModel.disableTracking
                )
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(4)
        }
        .tint(.roamIndigo)
    }
}
