import SwiftUI

/// Presents a preview of the privacy-safe coverage card and lets the user share
/// it through the system share sheet. This is Roam's only organic growth channel,
/// so it is always free — never gated behind Pro.
struct CoverageShareView: View {
    let coverage: CoverageSummary

    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if coverage.totalAreas == 0 {
                        emptyState
                    } else {
                        cardPreview
                        privacyNote
                        PrimaryButton("Share my map", systemImage: "square.and.arrow.up", style: .celebrate) {
                            presentShare()
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                    }
                }
                .padding(.vertical, Theme.Spacing.lg)
            }
            .background(RoamScreenBackground())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareImage {
                    ActivityView(items: [shareImage])
                }
            }
        }
    }

    private var cardPreview: some View {
        GeometryReader { geo in
            let scale = geo.size.width / ShareCardView.size.width
            ShareCardView(coverage: coverage, dateText: dateText)
                .frame(width: ShareCardView.size.width, height: ShareCardView.size.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: ShareCardView.size.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                .roamFloatShadow()
        }
        .frame(height: ShareCardView.size.height * (UIScreen.main.bounds.width - 2 * Theme.Spacing.lg) / ShareCardView.size.width)
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Color.roamTeal)
            Text("Your map stays private. This card only shows state-level totals — never your exact locations or the ZIP areas in any one city.")
                .font(.footnote)
                .foregroundStyle(Color.roamTextSecondary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "square.and.arrow.up",
            title: "Nothing to share yet",
            message: "Once Roam has colored in a few ZIP Code Areas, you can share a private snapshot of your travels here."
        )
        .padding(.top, Theme.Spacing.xxl)
    }

    @MainActor
    private func presentShare() {
        let renderer = ImageRenderer(content: ShareCardView(coverage: coverage, dateText: dateText))
        renderer.scale = 2
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

#Preview {
    CoverageShareView(coverage: CoverageSummary(totalAreas: 142, states: [
        StateCoverage(state: USState(code: "CA", name: "California"), areaCount: 88, estimatedTotal: 1763),
        StateCoverage(state: USState(code: "NV", name: "Nevada"), areaCount: 31, estimatedTotal: 220)
    ]))
}
