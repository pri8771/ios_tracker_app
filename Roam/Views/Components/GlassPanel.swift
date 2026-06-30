import SwiftUI

/// A reusable card container.
///
/// Kept for source compatibility with the many screens that adopted it early on;
/// it now renders with the shared Roam design-system surface (solid elevated
/// card + hairline + soft shadow) so every screen stays visually consistent.
struct GlassPanel<Content: View>: View {

    var cornerRadius: CGFloat = Theme.Radius.card
    var padding: CGFloat = Theme.Spacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        RoamCard(padding: padding, cornerRadius: cornerRadius) {
            content()
        }
    }
}

#Preview {
    ZStack {
        Color.roamBackground.ignoresSafeArea()
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card").font(.roamHeadline)
                Text("Design-system surface").font(.subheadline)
                    .foregroundStyle(Color.roamTextSecondary)
            }
        }
        .padding()
    }
}
