import SwiftUI

/// The Progress tab: the collection-completion heart of Roam. Shows how much of
/// the map you've colored in (state-level coverage), your headline counts,
/// milestones, and a one-tap entry to the privacy-safe share card.
struct StatisticsView: View {
    @StateObject private var vm: DashboardViewModel
    @ObservedObject private var store: StoreManager
    @State private var showShare = false
    @State private var showPaywall = false

    init(container: DependencyContainer, settings: AppSettings) {
        _vm = StateObject(wrappedValue: DashboardViewModel(container: container, settings: settings))
        self.store = container.store
    }

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.sm),
                           GridItem(.flexible(), spacing: Theme.Spacing.sm)]
    private let milestoneThresholds = StatisticsService.milestoneThresholds

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                heroCard
                totalsGrid
                if !vm.coverage.states.isEmpty { coverageByState }
                milestonesSection
                highlightsSection
            }
            .padding(Theme.Spacing.md)
        }
        .navigationTitle("Progress")
        .background(RoamScreenBackground())
        .onAppear { vm.reload() }
        .sheet(isPresented: $showShare) {
            CoverageShareView(coverage: vm.coverage)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: store)
        }
    }

    private var stateLimit: Int { store.isPlus ? Int.max : 5 }

    private var stats: TrackerStatistics { vm.statistics }
    private var coverage: CoverageSummary { vm.coverage }

    // MARK: - Hero

    private var heroCard: some View {
        RoamCard(padding: Theme.Spacing.lg) {
            VStack(spacing: Theme.Spacing.lg) {
                HStack(spacing: Theme.Spacing.lg) {
                    ProgressRing(
                        progress: coverage.nationalStatesFraction,
                        lineWidth: 12,
                        centerLabel: "\(coverage.statesTouched)",
                        centerCaption: coverage.statesTouched == 1 ? "state" : "states"
                    )
                    .frame(width: 116, height: 116)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(coverage.totalAreas)")
                            .font(.roamMetric(44))
                            .foregroundStyle(Color.roamTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("ZIP Code Areas colored in")
                            .font(.subheadline)
                            .foregroundStyle(Color.roamTextSecondary)
                        if let top = coverage.topState {
                            Chip(text: "Most explored: \(top.state.name)", systemImage: "star.fill", tint: .roamAmber)
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                }

                PrimaryButton("Share my map", systemImage: "square.and.arrow.up", style: .celebrate) {
                    showShare = true
                }
            }
        }
    }

    // MARK: - Totals

    private var totalsGrid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            StatTile(value: "\(stats.totalZCTAs)", label: "ZIP Areas",
                     systemImage: "mappin.and.ellipse", tint: .roamCoral)
            StatTile(value: "\(coverage.statesTouched)", label: "States",
                     systemImage: "map.fill", tint: .roamIndigo)
            StatTile(value: "\(stats.totalVisits)", label: "Total Visits",
                     systemImage: "clock.arrow.circlepath", tint: .roamTeal)
            StatTile(value: "\(stats.trackingDayCount)", label: "Days Active",
                     systemImage: "calendar", tint: .roamViolet)
        }
    }

    // MARK: - Coverage by state

    private var coverageByState: some View {
        RoamCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader("Coverage by state", systemImage: "chart.bar.fill", tint: .roamCoral)
                ForEach(Array(coverage.states.prefix(stateLimit))) { sc in
                    stateRow(sc)
                }
                if !store.isPlus, coverage.states.count > 5 {
                    Button { showPaywall = true } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "lock.fill")
                            Text("Unlock all \(coverage.states.count) states with Roam Plus")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .foregroundStyle(Color.roamIndigo)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                Text("Coverage percentages are estimates against approximate Census ZCTA totals.")
                    .font(.caption2)
                    .foregroundStyle(Color.roamTextTertiary)
            }
        }
    }

    private func stateRow(_ sc: StateCoverage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(sc.state.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.roamTextPrimary)
                Spacer()
                if let fraction = sc.fraction {
                    Text("est. \(Int((fraction * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.roamTextSecondary)
                }
                Text("\(sc.areaCount)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.roamCoral)
            }
            if let fraction = sc.fraction {
                RoamProgressBar(progress: fraction)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sc.state.name): \(sc.areaCount) areas")
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        RoamCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader("Milestones", systemImage: "rosette", tint: .roamAmber)
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    ForEach(milestoneThresholds, id: \.self) { threshold in
                        MilestoneBadge(threshold: threshold, achieved: stats.milestones.contains(threshold))
                    }
                }
            }
        }
    }

    // MARK: - Highlights

    private var highlightsSection: some View {
        RoamCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader("Highlights", systemImage: "sparkles", tint: .roamIndigo)
                highlightRow(systemImage: "star.fill", tint: .roamAmber, title: "Most Visited",
                             primary: stats.mostVisitedCode ?? "—",
                             secondary: stats.mostVisitedCode == nil ? "" : "\(stats.mostVisitedCount) visits")
                Divider().overlay(Color.roamSeparator.opacity(0.08))
                highlightRow(systemImage: "hourglass.bottomhalf.filled", tint: .roamTeal, title: "Most Time Spent",
                             primary: stats.longestTotalTimeCode ?? "—",
                             secondary: stats.longestTotalTimeCode == nil ? "" : formattedDuration(stats.longestTotalTimeSeconds))
                Divider().overlay(Color.roamSeparator.opacity(0.08))
                highlightRow(systemImage: "arrow.up.right", tint: .roamCoral, title: "Longest Single Visit",
                             primary: stats.longestSingleVisitCode ?? "—",
                             secondary: stats.longestSingleVisitCode == nil ? "" : formattedDuration(stats.longestSingleVisitSeconds))
            }
        }
    }

    private func highlightRow(systemImage: String, tint: Color, title: String, primary: String, secondary: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            IconBadge(systemImage: systemImage, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(Color.roamTextSecondary)
                Text(primary).font(.body.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Color.roamTextPrimary)
            }
            Spacer()
            Text(secondary).font(.caption).foregroundStyle(Color.roamTextSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(primary) \(secondary)")
    }
}

private struct MilestoneBadge: View {
    let threshold: Int
    let achieved: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: achieved ? "rosette" : "lock.fill")
                .font(.title3)
                .foregroundStyle(achieved ? Color.roamAmber : Color.roamTextTertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(threshold) areas").font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.roamTextPrimary)
                Text(achieved ? "Unlocked" : "Locked")
                    .font(.caption2)
                    .foregroundStyle(achieved ? Color.roamSuccess : Color.roamTextTertiary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                .fill(achieved ? Color.roamAmber.opacity(0.12) : Color.roamSurfaceMuted)
        )
        .opacity(achieved ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Milestone \(threshold) ZIP Code Areas, \(achieved ? "unlocked" : "locked")")
    }
}
