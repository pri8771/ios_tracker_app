import SwiftUI

/// A single visit row: ZCTA code, entry time, duration, and a source/simulated tag.
struct ZCTAVisitRow: View {
    let visit: ZCTAVisit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: visit.isOpen ? "location.fill" : "mappin")
                .foregroundStyle(visit.isOpen ? Color.accentColor : .secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(visit.zctaCode)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    if visit.isSimulated {
                        tag("Simulated", color: .purple)
                    }
                }
                Text(timeOnly(visit.enteredAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedDuration(visit.duration))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                if visit.isOpen {
                    Text("Open")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(visit.zctaCode), entered \(timeOnly(visit.enteredAt)), duration \(formattedDuration(visit.duration))\(visit.isSimulated ? ", simulated" : "")")
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}
