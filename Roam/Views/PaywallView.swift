import SwiftUI

/// A tasteful, honest Roam Plus paywall. One-time unlock, no subscription, no
/// ads, no data. The free app is fully functional — Plus is a thank-you + extras.
struct PaywallView: View {
    @ObservedObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    private let perks: [(icon: String, title: String, detail: String)] = [
        ("chart.bar.doc.horizontal.fill", "Full state breakdown", "See every state you've explored with estimated coverage, not just your top few."),
        ("paintpalette.fill", "More to come", "Plus unlocks future power features like heatmaps — yours forever, no subscription."),
        ("heart.fill", "Support a private app", "Roam has no ads and never sells your data. Plus keeps it that way.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(perks, id: \.title) { perk in
                            perkRow(perk)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    if store.isPlus {
                        Label("You have Roam Plus. Thank you!", systemImage: "checkmark.seal.fill")
                            .font(.roamHeadline)
                            .foregroundStyle(Color.roamSuccess)
                            .padding(.top, Theme.Spacing.md)
                    } else if store.plusProduct != nil {
                        VStack(spacing: Theme.Spacing.sm) {
                            PrimaryButton(
                                store.purchaseInFlight ? "Purchasing…" : "Unlock Roam Plus · \(store.plusDisplayPrice)",
                                systemImage: "lock.open.fill",
                                style: .celebrate,
                                isEnabled: !store.purchaseInFlight
                            ) {
                                Task { await store.purchasePlus() }
                            }
                            Button("Restore Purchase") { Task { await store.restore() } }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.roamIndigo)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.md)
                    } else {
                        // Product hasn't loaded (offline, or the App Store product
                        // isn't live yet). Don't show a fake-priced, un-purchasable
                        // button — offer a retry and restore instead.
                        VStack(spacing: Theme.Spacing.sm) {
                            Text("Roam Plus isn't available right now. Please check back soon.")
                                .font(.subheadline)
                                .foregroundStyle(Color.roamTextSecondary)
                                .multilineTextAlignment(.center)
                            PrimaryButton("Try Again", systemImage: "arrow.clockwise", style: .secondary) {
                                Task { await store.refresh() }
                            }
                            Button("Restore Purchase") { Task { await store.restore() } }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.roamIndigo)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.md)
                    }

                    Text("One-time purchase. No subscription. No ads. No data ever leaves your device.")
                        .font(.caption2)
                        .foregroundStyle(Color.roamTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
                .padding(.vertical, Theme.Spacing.lg)
            }
            .background(RoamScreenBackground())
            .navigationTitle("Roam Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Purchase", isPresented: .constant(store.lastError != nil)) {
                Button("OK") { store.lastError = nil }
            } message: {
                Text(store.lastError ?? "")
            }
            .task { await store.refresh() }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle().fill(LinearGradient.roamSunset).frame(width: 88, height: 88)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .roamFloatShadow()
            Text("Roam Plus")
                .font(.roamTitle)
                .foregroundStyle(Color.roamTextPrimary)
            Text("A one-time unlock for power features — and a thank-you that keeps Roam private and ad-free.")
                .font(.subheadline)
                .foregroundStyle(Color.roamTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.top, Theme.Spacing.md)
    }

    private func perkRow(_ perk: (icon: String, title: String, detail: String)) -> some View {
        RoamCard {
            HStack(spacing: Theme.Spacing.md) {
                IconBadge(systemImage: perk.icon, tint: .roamCoral, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(perk.title).font(.roamHeadline).foregroundStyle(Color.roamTextPrimary)
                    Text(perk.detail).font(.caption).foregroundStyle(Color.roamTextSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    PaywallView(store: StoreManager())
}
