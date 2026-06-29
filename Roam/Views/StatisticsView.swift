import SwiftUI

/// The Stats tab. Reuses `DashboardViewModel` to compute `TrackerStatistics`,
/// then renders totals, time-window counts, highlights, and milestone badges.
struct StatisticsView: View {
    @StateObject private var vm: DashboardViewModel

    init(container: DependencyContainer, settings: AppSettings) {
        _vm = StateObject(wrappedValue: DashboardViewModel(container: container, settings: settings))
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private let milestoneThresholds = StatisticsService.milestoneThresholds

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                totalsGrid
                windowsSection
                highlightsSection
                milestonesSection
            }
            .padding()
        }
        .navigationTitle("Stats")
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { vm.reload() }
    }

    private var stats: TrackerStatistics { vm.statistics }

    private var totalsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(systemImage: "mappin.and.ellipse", title: "ZIP Code Areas", value: "\(stats.totalZCTAs)")
            StatTile(systemImage: "clock.arrow.circlepath", title: "Total Visits", value: "\(stats.totalVisits)")
            StatTile(systemImage: "calendar", title: "Days Active", value: "\(stats.trackingDayCount)")
            StatTile(systemImage: "hourglass", title: "Longest Single Visit", value: formattedDuration(stats.longestSingleVisitSeconds))
        }
    }

    private var windowsSection: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("New ZIP Code Areas").font(.headline)
                windowRow("This Week", stats.newThisWeek)
                Divider()
                windowRow("This Month", stats.newThisMonth)
                Divider()
                windowRow("This Year", stats.newThisYear)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func windowRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text("\(value)").font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var highlightsSection: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Highlights").font(.headline)
                highlightRow(systemImage: "star.fill", title: "Most Visited",
                             primary: stats.mostVisitedCode ?? "—",
                             secondary: stats.mostVisitedCode == nil ? "" : "\(stats.mostVisitedCount) visits")
                Divider()
                highlightRow(systemImage: "hourglass.bottomhalf.filled", title: "Most Time Spent",
                             primary: stats.longestTotalTimeCode ?? "—",
                             secondary: stats.longestTotalTimeCode == nil ? "" : formattedDuration(stats.longestTotalTimeSeconds))
                Divider()
                highlightRow(systemImage: "arrow.up.right", title: "Longest Single Visit",
                             primary: stats.longestSingleVisitCode ?? "—",
                             secondary: stats.longestSingleVisitCode == nil ? "" : formattedDuration(stats.longestSingleVisitSeconds))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func highlightRow(systemImage: String, title: String, primary: String, secondary: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(primary).font(.body.weight(.semibold)).monospacedDigit()
            }
            Spacer()
            Text(secondary).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(primary) \(secondary)")
    }

    private var milestonesSection: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Milestones").font(.headline)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(milestoneThresholds, id: \.self) { threshold in
                        let achieved = stats.milestones.contains(threshold)
                        MilestoneBadge(threshold: threshold, achieved: achieved)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatTile: View {
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
                Text(value).font(.title2.weight(.bold)).monospacedDigit()
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct MilestoneBadge: View {
    let threshold: Int
    let achieved: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: achieved ? "rosette" : "lock")
                .font(.title3)
                .foregroundStyle(achieved ? .yellow : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(threshold) ZCTAs").font(.subheadline.weight(.semibold))
                Text(achieved ? "Achieved" : "Locked")
                    .font(.caption2)
                    .foregroundStyle(achieved ? .green : .secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(achieved ? Color.yellow.opacity(0.12) : Color.secondary.opacity(0.08))
        )
        .opacity(achieved ? 1 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Milestone \(threshold) ZIP Code Areas, \(achieved ? "achieved" : "locked")")
    }
}
