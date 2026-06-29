import SwiftUI

/// A prominent, full-width capsule button with an optional SF Symbol.
/// Supports a `.primary` (accent filled) and `.secondary` (tinted) style and a
/// disabled state.
struct PrimaryButton: View {

    enum Style {
        case primary
        case secondary
    }

    let title: String
    var systemImage: String?
    var style: Style = .primary
    var isEnabled: Bool = true
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .primary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }

    private var foreground: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .accentColor
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Color.accentColor
        case .secondary:
            Color.accentColor.opacity(0.15)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Continue", systemImage: "arrow.right") {}
        PrimaryButton("Not Now", style: .secondary) {}
        PrimaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
}
