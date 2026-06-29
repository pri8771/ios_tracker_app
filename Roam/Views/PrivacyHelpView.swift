import SwiftUI

/// Scrollable privacy & help screen: local-first promise, no cloud/account,
/// background-location explanation, battery note, how to stop tracking, and the
/// full Census ZCTA vs ZIP disclaimer.
struct PrivacyHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section(
                    systemImage: "lock.shield",
                    title: "Local-first by design",
                    body: "\(AppConstants.appName) stores everything on this iPhone. \(AppConstants.primaryPromise) There is no account to create and no sign-in."
                )
                section(
                    systemImage: "icloud.slash",
                    title: "No cloud, no analytics",
                    body: "Your ZIP/ZCTA history is never uploaded to a server. The app performs no app-controlled network calls for ZIP Code Area detection, and collects no analytics."
                )
                section(
                    systemImage: "location.fill.viewfinder",
                    title: "Why background location",
                    body: "To detect the Census ZCTA boundaries you enter even when the app isn't open, \(AppConstants.appName) uses Always Location. Detection runs entirely on-device."
                )
                section(
                    systemImage: "battery.75",
                    title: "Battery",
                    body: "Background location can affect battery life. Choose a lower-power tracking mode (Battery Saver) in Settings to reduce impact."
                )
                section(
                    systemImage: "hand.raised.fill",
                    title: "How to stop tracking",
                    body: "Open Settings inside the app and turn off Enable Tracking at any time. You can also revoke location access in the iOS Settings app."
                )
                section(
                    systemImage: "map",
                    title: "Census ZCTA boundaries",
                    body: AppConstants.Copy.zctaLongDisclaimer
                )
            }
            .padding()
        }
        .navigationTitle("Privacy & Help")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func section(systemImage: String, title: String, body: String) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(body)")
    }
}

#Preview {
    NavigationStack { PrivacyHelpView() }
}
