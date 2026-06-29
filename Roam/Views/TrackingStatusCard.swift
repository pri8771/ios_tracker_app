import SwiftUI

/// A glass card showing the high-level tracking runtime state with a colored
/// status dot and a short subtitle. Driven by the shared `TrackingState`.
struct TrackingStatusCard: View {
    @ObservedObject var trackingState: TrackingState

    var body: some View {
        GlassPanel {
            HStack(spacing: 14) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(trackingState.runtimeState.displayName)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "location.circle")
                    .font(.title2)
                    .foregroundStyle(dotColor)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tracking status: \(trackingState.runtimeState.displayName). \(subtitle)")
    }

    private var dotColor: Color {
        switch trackingState.runtimeState {
        case .off: return .gray
        case .needsAlwaysAuthorization: return .orange
        case .active: return .green
        case .activeReducedAccuracy: return .yellow
        case .error: return .red
        }
    }

    private var subtitle: String {
        switch trackingState.runtimeState {
        case .off:
            return "Tracking is off. Enable it in Settings to collect ZIP Code Areas."
        case .needsAlwaysAuthorization:
            return "Grant Always Location to track in the background."
        case .active:
            return "Collecting ZIP Code Areas as you move."
        case .activeReducedAccuracy:
            return "Tracking with reduced (coarse) accuracy."
        case .error:
            return trackingState.lastErrorMessage ?? "Tracking encountered a problem."
        }
    }
}
