import SwiftUI

/// First-run onboarding: a 4-page paged carousel explaining the product promise,
/// privacy posture, background tracking, and the Census ZCTA approximation.
/// Does NOT request Always Location here; that happens later behind the
/// permission education sheet.
struct OnboardingView: View {

    let onComplete: () -> Void

    @State private var page = 0
    private let lastPage = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                OnboardingPage(
                    systemImage: "mappin.and.ellipse",
                    title: "Collect the ZIP Code Areas you visit",
                    message: AppConstants.primaryPromise
                )
                .tag(0)

                OnboardingPage(
                    systemImage: "lock.shield",
                    title: "Private by design",
                    message: "All of your data stays on this iPhone. There is no account, no cloud sync, and no analytics. \(AppConstants.appName) never uploads where you go."
                )
                .tag(1)

                OnboardingPage(
                    systemImage: "location.fill.viewfinder",
                    title: "Background tracking",
                    message: "To record the ZIP/ZCTA areas you enter even when the app is closed, \(AppConstants.appName) uses Always Location. You can turn tracking off anytime in Settings. Background location may affect battery life."
                )
                .tag(2)

                OnboardingPage(
                    systemImage: "map",
                    title: "Census ZCTA boundaries",
                    message: AppConstants.Copy.zctaLongDisclaimer
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                if page == lastPage {
                    PrimaryButton("Continue", systemImage: "checkmark") {
                        onComplete()
                    }
                } else {
                    PrimaryButton("Next", systemImage: "arrow.right") {
                        withAnimation { page += 1 }
                    }
                    Button("Skip") { onComplete() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Skip onboarding")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: systemImage)
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
