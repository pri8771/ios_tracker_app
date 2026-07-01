import SwiftUI

/// The Dashboard tab: tracking status, the current ZIP Code Area, headline
/// counts, a quick share entry, recent transitions, and a data-status warning
/// when running on sample/missing data.
struct DashboardView: View {
    @StateObject private var vm: DashboardViewModel
    @ObservedObject private var trackingState: TrackingState
    private let container: DependencyContainer
    @State private var showShare = false

    init(container: DependencyContainer, settings: AppSettings) {
        self.container = container
        self.trackingState = container.trackingState
        _vm = StateObject(wrappedValue: DashboardViewModel(container: container, settings: settings))
    }

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.sm),
                           GridItem(.flexible(), spacing: Theme.Spacing.sm)]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                dataStatusBannerIfNeeded

                TrackingStatusCard(trackingState: trackingState)

                if let code = trackingState.currentZCTACode {
                    CurrentZCTACard(
                        code: code,
                        visitStartedAt: trackingState.currentVisitStartedAt,
                        confidence: trackingState.lastConfidence
                    )
                }

                summaryGrid

                if vm.statistics.totalZCTAs > 0 { shareCard }

                recentSection
            }
            .padding(Theme.Spacing.md)
        }
        .navigationTitle("Roam")
        .background(RoamScreenBackground())
        .onAppear {
            vm.reload()
            container.locationService.refreshCurrentLocationIfAuthorized(mode: vm.settings.trackingMode)
        }
        .sheet(isPresented: $showShare) {
            CoverageShareView(coverage: vm.coverage)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            StatTile(value: "\(vm.statistics.totalZCTAs)", label: "ZIP Areas",
                     systemImage: "mappin.and.ellipse", tint: .roamCoral)
            StatTile(value: "\(vm.coverage.statesTouched)", label: "States",
                     systemImage: "map.fill", tint: .roamIndigo)
            StatTile(value: "\(vm.statistics.newThisWeek)", label: "New This Week",
                     systemImage: "sparkles", tint: .roamAmber)
            StatTile(value: formattedDuration(vm.longestVisitSeconds), label: "Longest Visit",
                     systemImage: "hourglass", tint: .roamTeal)
        }
    }

    private var shareCard: some View {
        Button { showShare = true } label: {
            RoamCard {
                HStack(spacing: Theme.Spacing.md) {
                    IconBadge(systemImage: "square.and.arrow.up", tint: .roamCoral, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share your map")
                            .font(.roamHeadline)
                            .foregroundStyle(Color.roamTextPrimary)
                        Text("A private snapshot — state totals only.")
                            .font(.caption)
                            .foregroundStyle(Color.roamTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.roamTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var recentSection: some View {
        RoamCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader("Recent", systemImage: "clock.arrow.circlepath", tint: .roamIndigo)
                if vm.recentTransitions.isEmpty {
                    Text("No visits yet. Recently entered ZIP Code Areas will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(Color.roamTextSecondary)
                        .padding(.vertical, Theme.Spacing.xs)
                } else {
                    ForEach(vm.recentTransitions) { t in
                        HStack(spacing: Theme.Spacing.sm) {
                            IconBadge(systemImage: t.isCurrent ? "location.fill" : "mappin",
                                      tint: t.isCurrent ? .roamTeal : .roamIndigo, size: 32)
                            Text(t.code)
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.roamTextPrimary)
                            if let state = USStateResolver.state(forZIP: t.code) {
                                Text(state.code)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.roamTextSecondary)
                            }
                            Spacer()
                            Text(relativeTime(t.enteredAt))
                                .font(.caption)
                                .foregroundStyle(Color.roamTextSecondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(t.code), \(relativeTime(t.enteredAt))\(t.isCurrent ? ", current" : "")")
                        if t.id != vm.recentTransitions.last?.id {
                            Divider().overlay(Color.roamSeparator.opacity(0.08))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dataStatusBannerIfNeeded: some View {
        let status = vm.bundleStatus
        if status.isSample || status.isMissing {
            NavigationLink {
                DataStatusView(container: container)
            } label: {
                ErrorBanner(message: status.isMissing
                    ? "ZCTA data is missing. Tracking can't run. Tap for details."
                    : "Limited beta coverage — some areas aren't detected yet. Tap for details.")
            }
            .buttonStyle(.plain)
        }
    }
}
