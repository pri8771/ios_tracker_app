import SwiftUI

/// A glass card highlighting the ZIP/ZCTA the user is currently in, with a live
/// visit duration, confidence pill, and the "Census ZCTA" label.
struct CurrentZCTACard: View {

    let code: String
    let visitStartedAt: Date?
    let confidence: DetectionConfidence?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GlassPanel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Current ZIP/ZCTA", systemImage: "mappin.and.ellipse")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let confidence {
                            confidencePill(confidence)
                        }
                    }

                    Text(code)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("Current ZIP Code Area \(code)")

                    HStack(spacing: 12) {
                        if let visitStartedAt {
                            Label("since \(timeOnly(visitStartedAt))", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formattedDuration(context.date.timeIntervalSince(visitStartedAt)))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                        Spacer()
                        Text("Census ZCTA")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func confidencePill(_ confidence: DetectionConfidence) -> some View {
        Text(confidence.displayName)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(pillColor(confidence).opacity(0.2)))
            .foregroundStyle(pillColor(confidence))
            .accessibilityLabel("Detection confidence \(confidence.displayName)")
    }

    private func pillColor(_ confidence: DetectionConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}
