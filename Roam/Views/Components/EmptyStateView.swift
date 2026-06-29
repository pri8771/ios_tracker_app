import SwiftUI

/// Centered empty-state placeholder: SF Symbol, title, message, and an optional
/// call-to-action button.
struct EmptyStateView: View {

    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                PrimaryButton(actionTitle, style: .secondary, action: action)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "mappin.and.ellipse",
        title: "No ZIP Code Areas yet",
        message: "Turn on tracking to start collecting the ZIP Code Areas you visit.",
        actionTitle: "Learn More"
    ) {}
}
