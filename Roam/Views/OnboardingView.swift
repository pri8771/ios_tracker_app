import SwiftUI

/// First-run onboarding. Leads with value and the privacy posture, *then* lets
/// the user turn on tracking with an explicit, informed CTA — so nobody hits the
/// system Always prompt cold. Does not itself request Always (that happens behind
/// the permission education sheet after a When-In-Use first win).
struct OnboardingView: View {

    /// `enableTracking == true` → kick off the permission flow; otherwise just
    /// finish onboarding into the app.
    let onFinish: (_ enableTracking: Bool) -> Void

    @State private var page = 0

    private let pages: [OnboardingPage.Model] = [
        .init(icon: "map.fill",
              title: "Your travels,\ncolored in.",
              message: "Roam quietly colors in every ZIP Code Area you pass through — automatically, the moment you arrive."),
        .init(icon: "lock.shield.fill",
              title: "Private\nby design.",
              message: "Everything stays on this iPhone. No account, no cloud, no analytics. Roam never uploads where you go."),
        .init(icon: "square.and.arrow.up.fill",
              title: "Share the\nadventure.",
              message: "Watch your map fill in, then share a private snapshot — state totals only, never your exact spots."),
        .init(icon: "info.circle.fill",
              title: "Close to\nZIP Codes.",
              message: "Areas are U.S. Census ZIP Code Tabulation Areas (ZCTAs) — generalized boundaries that approximate ZIP Codes, not exact USPS routes.")
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient.roamBrand.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, model in
                        OnboardingPage(model: model).tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                controls
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .preferredColorScheme(.dark) // keeps the glass/white treatment legible on the gradient
    }

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if isLast {
                Button {
                    onFinish(true)
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "location.fill")
                        Text("Turn on Roam").font(.roamHeadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(Color.roamViolet)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)

                Button("Maybe later") { onFinish(false) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 2)
            } else {
                Button {
                    withAnimation(Theme.Motion.quick) { page += 1 }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("Next").font(.roamHeadline)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(Color.roamViolet)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)

                Button("Skip") { withAnimation { page = pages.count - 1 } }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 2)
                    .accessibilityLabel("Skip to the end of onboarding")
            }
        }
    }
}

private struct OnboardingPage: View {
    struct Model {
        let icon: String
        let title: String
        let message: String
    }
    let model: Model

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer(minLength: 20)
            ZStack {
                Circle().fill(.white.opacity(0.18)).frame(width: 132, height: 132)
                Image(systemName: model.icon)
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.md) {
                Text(model.title)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text(model.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, Theme.Spacing.lg)
            }
            Spacer(minLength: 60)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(onFinish: { _ in })
}
