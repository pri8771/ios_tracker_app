import SwiftUI

/// The History tab: timeline / by-ZCTA modes, search, sort, archive toggle, and
/// swipe actions on tracked ZCTAs.
struct HistoryView: View {
    @StateObject private var vm: HistoryViewModel
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        _vm = StateObject(wrappedValue: HistoryViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $vm.mode) {
                ForEach(HistoryViewModel.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            content
        }
        .navigationTitle("History")
        .searchable(text: $vm.searchText, prompt: "Search ZIP/ZCTA")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $vm.sort) {
                        ForEach(HistoryViewModel.SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    Toggle("Include Archived", isOn: $vm.includeArchived)
                } label: {
                    Label("Sort & Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onAppear { vm.reload() }
        .onChange(of: vm.searchText) { _, _ in vm.reload() }
        .onChange(of: vm.sort) { _, _ in vm.reload() }
        .onChange(of: vm.mode) { _, _ in vm.reload() }
        .onChange(of: vm.includeArchived) { _, _ in vm.reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.mode {
        case .timeline:
            if vm.daySections.isEmpty {
                emptyState
            } else {
                VisitTimelineView(sections: vm.daySections, onDeleteVisit: vm.deleteVisit)
            }
        case .byZCTA:
            if vm.trackedList.isEmpty {
                emptyState
            } else {
                trackedList
            }
        }
    }

    private var trackedList: some View {
        List {
            ForEach(vm.trackedList) { z in
                NavigationLink {
                    ZCTADetailView(tracked: z, container: container)
                } label: {
                    TrackedZCTARow(tracked: z)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        vm.toggleFavorite(z)
                    } label: {
                        Label("Favorite", systemImage: z.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        vm.delete(z)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        vm.toggleArchive(z)
                    } label: {
                        Label(z.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                    }
                    .tint(.indigo)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "clock.arrow.circlepath",
            title: "No history yet",
            message: vm.searchText.isEmpty
                ? "Visited ZIP Code Areas will show up here once tracking records them."
                : "No ZIP Code Areas match \"\(vm.searchText)\"."
        )
    }
}

private struct TrackedZCTARow: View {
    let tracked: TrackedZCTA

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tracked.isFavorite ? "star.fill" : "mappin.circle")
                .foregroundStyle(tracked.isFavorite ? .yellow : Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tracked.resolvedTitle)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    if tracked.isArchived {
                        Text("Archived")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(tracked.visitCount) visit\(tracked.visitCount == 1 ? "" : "s") · \(formattedDuration(tracked.totalDurationSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(relativeTime(tracked.lastEnteredAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
