import SwiftUI

/// A prominent, full-width button with an optional SF Symbol.
///
/// - `.primary`   — the indigo brand gradient (main call to action)
/// - `.celebrate` — the warm sunset gradient (delight moments: first patch, share)
/// - `.secondary` — tinted indigo fill (lower-emphasis action)
/// - `.tinted`    — a caller-tinted soft fill (e.g. destructive in red)
struct PrimaryButton: View {

    enum Style {
        case primary
        case celebrate
        case secondary
        case tinted(Color)
    }

    let title: String
    var systemImage: String?
    var style: Style = .primary
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.isEnabled) private var envEnabled
    @State private var pressed = false

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
        Button {
            action()
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.roamHeadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .roamCardShadow()
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(Theme.Motion.quick, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }

    private var foreground: Color {
        switch style {
        case .primary, .celebrate: return .white
        case .secondary: return .roamIndigo
        case .tinted(let color): return color
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            LinearGradient.roamIndigoGradient
        case .celebrate:
            LinearGradient.roamSunset
        case .secondary:
            Color.roamIndigo.opacity(0.12)
        case .tinted(let color):
            color.opacity(0.14)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Continue", systemImage: "arrow.right") {}
        PrimaryButton("Share my map", systemImage: "square.and.arrow.up", style: .celebrate) {}
        PrimaryButton("Not Now", style: .secondary) {}
        PrimaryButton("Delete", style: .tinted(.roamDanger)) {}
        PrimaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .background(Color.roamBackground)
}
