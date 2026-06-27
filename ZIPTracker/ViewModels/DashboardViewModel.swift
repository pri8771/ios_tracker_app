import Foundation
import SwiftUI
import SwiftData
import Combine

/// Backs the Dashboard: tracking status, current ZCTA, summary cards, and the
/// most recent transitions.
@MainActor
final class DashboardViewModel: ObservableObject {

    struct RecentTransition: Identifiable {
        let id: UUID
        let code: String
        let enteredAt: Date
        let isCurrent: Bool
    }

    @Published var statistics: TrackerStatistics = .empty
    @Published var recentTransitions: [RecentTransition] = []
    @Published var longestVisitSeconds: Double = 0

    let container: DependencyContainer
    let settings: AppSettings
    private let statsService = StatisticsService()
    private var cancellables = Set<AnyCancellable>()

    init(container: DependencyContainer, settings: AppSettings) {
        self.container = container
        self.settings = settings

        NotificationCenter.default.publisher(for: AppConstants.Notifications.dataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    var trackingState: TrackingState { container.trackingState }
    var bundleStatus: ZCTABundleStatus { container.geometryService.status }

    func reload() {
        let tracked = (try? container.mainContext.fetch(FetchDescriptor<TrackedZCTA>())) ?? []
        let visits = (try? container.mainContext.fetch(
            FetchDescriptor<ZCTAVisit>(sortBy: [SortDescriptor(\.enteredAt, order: .reverse)])
        )) ?? []

        let trackedSummaries = tracked.map {
            TrackedZCTASummary(code: $0.zctaCode, firstEnteredAt: $0.firstEnteredAt,
                               lastEnteredAt: $0.lastEnteredAt, visitCount: $0.visitCount,
                               totalDurationSeconds: $0.totalDurationSeconds, isArchived: $0.isArchived)
        }
        let visitSummaries = visits.map {
            VisitSummary(code: $0.zctaCode, enteredAt: $0.enteredAt, durationSeconds: $0.duration)
        }
        statistics = statsService.computeStatistics(trackedZCTAs: trackedSummaries, visits: visitSummaries)
        longestVisitSeconds = statistics.longestSingleVisitSeconds

        let current = container.trackingState.currentZCTACode
        recentTransitions = visits.prefix(5).map {
            RecentTransition(id: $0.id, code: $0.zctaCode, enteredAt: $0.enteredAt,
                             isCurrent: $0.isOpen && $0.zctaCode == current)
        }
    }
}
