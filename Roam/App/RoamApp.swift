import SwiftUI
import SwiftData

/// SwiftUI app entry point. Uses the SwiftUI App lifecycle with a UIKit
/// `AppDelegate` adaptor for location relaunch handling.
@main
struct RoamApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.trackingState)
                .modelContainer(container.modelContainer)
                .onAppear {
                    AppDelegate.sharedContainer = container
                }
        }
    }
}
