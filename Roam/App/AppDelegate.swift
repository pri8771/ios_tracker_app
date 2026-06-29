import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Handles app-launch concerns that SwiftUI's `App` lifecycle does not cover —
/// most importantly resuming background location tracking when iOS relaunches
/// the app due to a location event.
final class AppDelegate: NSObject {

    /// Set by `RoamApp` once the dependency container exists.
    static weak var sharedContainer: DependencyContainer?

    /// Records whether we were relaunched specifically for a location event.
    private(set) var relaunchedForLocation = false
}

#if canImport(UIKit)
extension AppDelegate: UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if launchOptions?[.location] != nil {
            relaunchedForLocation = true
            // The container is wired very early by `RoamApp`; defer the
            // resume to the main actor and retry once if it isn't ready yet.
            Task { @MainActor in
                if !AppDelegate.resumeTrackingIfNeeded() {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    _ = AppDelegate.resumeTrackingIfNeeded()
                }
            }
        }
        return true
    }

    /// If we were woken for a location event and the user still has tracking
    /// enabled with Always authorization, resume the location pipeline.
    @MainActor
    @discardableResult
    static func resumeTrackingIfNeeded() -> Bool {
        guard let container = sharedContainer else { return false }
        let settings = container.loadOrCreateSettings()
        let auth = container.locationService.authorizationState
        guard settings.trackingEnabled, auth.allowsBackgroundTracking else { return true }
        Task { await container.processor.log(.appRelaunchedForLocation, "Relaunched for location; resuming tracking.") }
        container.syncTracking(with: settings)
        return true
    }
}
#endif
