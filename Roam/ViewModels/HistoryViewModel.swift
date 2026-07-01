import Foundation
import SwiftUI
import SwiftData
import Combine

/// Backs the History screen with two modes (timeline / by-ZCTA), search, sort,
/// and the swipe actions (favorite / archive / delete).
@MainActor
final class HistoryViewModel: ObservableObject {

    enum Mode: String, CaseIterable, Identifiable {
        case timeline = "Timeline"
        case byZCTA = "By ZIP/ZCTA"
        var id: String { rawValue }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case recent = "Most Recent"
        case mostVisited = "Most Visited"
        case alphabetical = "Code (A–Z)"
        case longestTime = "Longest Time"
        var id: String { rawValue }
    }

    struct DaySection: Identifiable {
        let id: String
        let date: Date
        let visits: [ZCTAVisit]
    }

    @Published var mode: Mode = .timeline
    @Published var searchText = ""
    @Published var sort: SortOption = .recent
    @Published var includeArchived = false

    @Published var daySections: [DaySection] = []
    @Published var trackedlist: [TrackedZCTA] = []
    var trackedList: [TrackedZCTA] { trackedlist }

    let container: DependencyContainer
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()
    // Formatters are expensive to build; reuse one across reloads (search/sort are hot).
    private static let dayKeyFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    init(container: DependencyContainer) {
        self.container = container
        NotificationCenter.default.publisher(for: AppConstants.Notifications.dataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    func reload() {
        reloadTimeline()
        reloadTrackedList()
    }

    private func matchesSearch(_ code: String) -> Bool {
        searchText.isEmpty || code.localizedCaseInsensitiveContains(searchText)
    }

    private func reloadTimeline() {
        let visits = (try? container.mainContext.fetch(
            FetchDescriptor<ZCTAVisit>(sortBy: [SortDescriptor(\.enteredAt, order: .reverse)])
        )) ?? []
        let filtered = visits.filter { matchesSearch($0.zctaCode) }
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.enteredAt) }
        daySections = grouped.keys.sorted(by: >).map { day in
            DaySection(
                id: Self.dayKeyFormatter.string(from: day),
                date: day,
                visits: (grouped[day] ?? []).sorted { $0.enteredAt > $1.enteredAt }
            )
        }
    }

    private func reloadTrackedList() {
        // Predicate-free fetch + in-memory filter (see ModelStore.upsert for why).
        var tracked = (try? container.mainContext.fetch(FetchDescriptor<TrackedZCTA>())) ?? []
        if !includeArchived { tracked = tracked.filter { !$0.isArchived } }
        tracked = tracked.filter { matchesSearch($0.zctaCode) }

        switch sort {
        case .recent:
            tracked.sort { $0.lastEnteredAt > $1.lastEnteredAt }
        case .mostVisited:
            tracked.sort { $0.visitCount > $1.visitCount }
        case .alphabetical:
            tracked.sort { $0.zctaCode < $1.zctaCode }
        case .longestTime:
            tracked.sort { $0.totalDurationSeconds > $1.totalDurationSeconds }
        }
        trackedlist = tracked
    }

    // MARK: - Swipe actions

    func toggleFavorite(_ z: TrackedZCTA) {
        z.isFavorite.toggle()
        z.updatedAt = .now
        save()
    }

    func toggleArchive(_ z: TrackedZCTA) {
        z.isArchived.toggle()
        z.updatedAt = .now
        save()
    }

    func delete(_ z: TrackedZCTA) {
        container.mainContext.delete(z)
        save()
    }

    func deleteVisit(_ v: ZCTAVisit) {
        if let tracked = v.trackedZCTA {
            tracked.visitCount = max(0, tracked.visitCount - 1)
            tracked.totalDurationSeconds = max(0, tracked.totalDurationSeconds - v.duration)
        }
        container.mainContext.delete(v)
        save()
    }

    private func save() {
        try? container.mainContext.save()
        reload()
        NotificationCenter.default.post(name: AppConstants.Notifications.dataDidChange, object: nil)
    }
}
