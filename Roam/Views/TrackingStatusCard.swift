import SwiftUI

/// A card showing the high-level tracking runtime state with a colored status
/// dot and a short subtitle. Driven by the shared `TrackingState`.
struct TrackingStatusCard: View {
    @ObservedObject var trackingState: TrackingState

    var body: some View {
        RoamCard {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle().fill(dotColor.opacity(0.18)).frame(width: 40, height: 40)
                    Circle().fill(dotColor).frame(width: 12, height: 12)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(trackingState.runtimeState.displayName)
                        .font(.roamHeadline)
                        .foregroundStyle(Color.roamTextPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.roamTextSecondary)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tracking status: \(trackingState.runtimeState.displayName). \(subtitle)")
    }

    private var dotColor: Color {
        switch trackingState.runtimeState {
        case .off: return .roamTextTertiary
        case .needsAlwaysAuthorization: return .roamWarning
        case .active: return .roamSuccess
        case .activeReducedAccuracy: return .roamAmber
        case .error: return .roamDanger
        }
    }

    private var subtitle: String {
        switch trackingState.runtimeState {
        case .off:
            return "Tracking is off. Enable it to collect ZIP Code Areas."
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
