import SwiftUI

/// The "you're here" hero card — the delight moment when Roam colors in the area
/// you're currently in. Uses the warm brand gradient with a live visit duration,
/// confidence pill, and the honest "Census ZCTA" label.
struct CurrentZCTACard: View {

    let code: String
    let visitStartedAt: Date?
    let confidence: DetectionConfidence?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Label("YOU'RE HERE", systemImage: "location.fill")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    if let confidence {
                        confidencePill(confidence)
                    }
                }

                Text(code)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .accessibilityLabel("Current ZIP Code Area \(code)")

                HStack(spacing: Theme.Spacing.sm) {
                    if let visitStartedAt {
                        Label("since \(timeOnly(visitStartedAt))", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(formattedDuration(context.date.timeIntervalSince(visitStartedAt)))
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("Census ZCTA")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                    .fill(LinearGradient.roamSunset)
            )
            .roamCardShadow()
        }
        .accessibilityElement(children: .contain)
    }

    private func confidencePill(_ confidence: DetectionConfidence) -> some View {
        Text(confidence.displayName)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.25)))
            .foregroundStyle(.white)
            .accessibilityLabel("Detection confidence \(confidence.displayName)")
    }
}

#Preview {
    CurrentZCTACard(code: "94103", visitStartedAt: Date().addingTimeInterval(-3600), confidence: .high)
        .padding()
        .background(Color.roamBackground)
}
