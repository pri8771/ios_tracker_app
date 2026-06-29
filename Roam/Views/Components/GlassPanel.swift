import SwiftUI

/// A reusable container that gives content a frosted-glass card appearance using
/// `.ultraThinMaterial`, continuous rounded corners, and a subtle hairline border.
struct GlassPanel<Content: View>: View {

    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("Glass Panel").font(.headline)
                Text("Frosted material container").font(.subheadline)
            }
        }
        .padding()
    }
}
