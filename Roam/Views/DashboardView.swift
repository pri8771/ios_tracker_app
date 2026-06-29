import SwiftUI

/// The Dashboard tab: tracking status, current ZCTA, summary stat cards, recent
/// transitions, and a data-status warning when running on sample/missing data.
struct DashboardView: View {
    @StateObject private var vm: DashboardViewModel
    @ObservedObject private var trackingState: TrackingState
    private let container: DependencyContainer

    init(container: DependencyContainer, settings: AppSettings) {
        self.container = container
        self.trackingState = container.trackingState
        _vm = StateObject(wrappedValue: DashboardViewModel(container: container, settings: settings))
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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

                recentSection
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { vm.reload() }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            SummaryCard(systemImage: "mappin.and.ellipse",
                        title: "ZIP Code Areas",
                        value: "\(vm.statistics.totalZCTAs)")
            SummaryCard(systemImage: "clock.arrow.circlepath",
                        title: "Visits Recorded",
                        value: "\(vm.statistics.totalVisits)")
            SummaryCard(systemImage: "sparkles",
                        title: "New This Week",
                        value: "\(vm.statistics.newThisWeek)")
            SummaryCard(systemImage: "hourglass",
                        title: "Longest Visit",
                        value: formattedDuration(vm.longestVisitSeconds))
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent")
                    .font(.headline)
                if vm.recentTransitions.isEmpty {
                    Text("No visits yet. Recently entered ZIP Code Areas will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.recentTransitions) { t in
                        HStack {
                            Image(systemName: t.isCurrent ? "location.fill" : "mappin")
                                .foregroundStyle(t.isCurrent ? Color.accentColor : .secondary)
                                .frame(width: 22)
                                .accessibilityHidden(true)
                            Text(t.code)
                                .font(.body.weight(.medium))
                                .monospacedDigit()
                            Spacer()
                            Text(relativeTime(t.enteredAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(t.code), \(relativeTime(t.enteredAt))\(t.isCurrent ? ", current" : "")")
                        if t.id != vm.recentTransitions.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    : "Using sample ZCTA data (development only). Tap for details.")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SummaryCard: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(value)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
