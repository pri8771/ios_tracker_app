import SwiftUI

/// A red-tinted rounded banner showing a warning/error message with an
/// exclamation triangle. Optionally dismissible.
struct ErrorBanner: View {

    let message: String
    var systemImage: String = "exclamationmark.triangle.fill"
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.roamWarning)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.roamTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.roamTextSecondary)
                }
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Color.roamWarning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Color.roamWarning.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Warning: \(message)"))
    }
}

#Preview {
    ErrorBanner(message: "ZCTA data is unavailable. Tracking is disabled.") {}
        .padding()
}
