import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shown right before requesting Always Location. Explains *why* background
/// location is needed, the battery impact, that the user can stop anytime, and
/// that privacy stays local. Adapts copy to the current authorization state.
struct PermissionEducationView: View {

    let authorizationState: LocationAuthorizationState
    let onContinue: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    reasonRow(
                        systemImage: "location.fill.viewfinder",
                        title: "Detect ZIP/ZCTA entries in the background",
                        detail: "\(AppConstants.appName) needs Always Location so it can record the ZIP Code Areas you enter even when the app isn't open."
                    )
                    reasonRow(
                        systemImage: "battery.75",
                        title: "Battery aware",
                        detail: "Background location may affect battery life. You can pick a lower-power tracking mode in Settings."
                    )
                    reasonRow(
                        systemImage: "hand.raised.fill",
                        title: "Stop anytime",
                        detail: "Tracking is fully under your control. Turn it off whenever you like in Settings."
                    )
                    reasonRow(
                        systemImage: "lock.shield",
                        title: "Stays on your device",
                        detail: "Your location history never leaves this iPhone. No account, no cloud, no analytics."
                    )

                    statusSection
                }
                .padding(24)
            }
            .navigationTitle("Background Location")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Allow Always Location")
                .font(.title.weight(.bold))
        }
    }

    private func reasonRow(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusSection: some View {
        switch authorizationState {
        case .denied, .restricted:
            ErrorBanner(message: "Location is currently denied. Open Settings to allow Always Location for \(AppConstants.appName).")
            openSettingsButton
        case .whenInUse, .whenInUseReducedAccuracy:
            GlassPanel {
                Text("You've granted While Using access. Continue to upgrade to Always so tracking works in the background.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .always, .alwaysReducedAccuracy:
            GlassPanel {
                Label("Always Location is already enabled.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        case .notDetermined:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 10) {
            switch authorizationState {
            case .denied, .restricted, .always, .alwaysReducedAccuracy:
                PrimaryButton("Done", systemImage: "checkmark") { onDismiss() }
            default:
                PrimaryButton("Continue to Permission", systemImage: "location.fill") { onContinue() }
                Button("Not Now") { onDismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var openSettingsButton: some View {
        #if canImport(UIKit)
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Label("Open Settings", systemImage: "gearshape")
        }
        .font(.subheadline.weight(.semibold))
        #endif
    }
}

#Preview {
    PermissionEducationView(authorizationState: .notDetermined, onContinue: {}, onDismiss: {})
}
