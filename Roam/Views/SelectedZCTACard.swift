import SwiftUI

/// Bottom card shown when a ZCTA boundary/pin is tapped on the map. Surfaces the
/// code, visit count, last seen, a link to the detail screen, and the short
/// ZCTA disclaimer.
struct SelectedZCTACard: View {

    let tracked: TrackedZCTA?
    let code: String
    let container: DependencyContainer
    let onDismiss: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(code)
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                        Text("Census ZCTA")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Dismiss")
                }

                if let tracked {
                    HStack(spacing: 16) {
                        stat(systemImage: "clock.arrow.circlepath",
                             label: "\(tracked.visitCount) visit\(tracked.visitCount == 1 ? "" : "s")")
                        stat(systemImage: "eye",
                             label: "Last \(relativeTime(tracked.lastSeenAt))")
                    }

                    NavigationLink {
                        ZCTADetailView(tracked: tracked, container: container)
                    } label: {
                        Label("View Details", systemImage: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                    Text("You haven't visited this ZIP Code Area yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(AppConstants.Copy.zctaShortDisclaimer)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stat(systemImage: String, label: String) -> some View {
        Label(label, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
