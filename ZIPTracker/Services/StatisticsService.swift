import Foundation

/// Lightweight, value-type input describing a tracked ZCTA for statistics.
struct TrackedZCTASummary: Sendable, Equatable {
    var code: String
    var firstEnteredAt: Date
    var lastEnteredAt: Date
    var visitCount: Int
    var totalDurationSeconds: Double
    var isArchived: Bool

    init(code: String, firstEnteredAt: Date, lastEnteredAt: Date, visitCount: Int, totalDurationSeconds: Double, isArchived: Bool = false) {
        self.code = code
        self.firstEnteredAt = firstEnteredAt
        self.lastEnteredAt = lastEnteredAt
        self.visitCount = visitCount
        self.totalDurationSeconds = totalDurationSeconds
        self.isArchived = isArchived
    }
}

/// Lightweight, value-type input describing one visit for statistics.
struct VisitSummary: Sendable, Equatable {
    var code: String
    var enteredAt: Date
    var durationSeconds: Double

    init(code: String, enteredAt: Date, durationSeconds: Double) {
        self.code = code
        self.enteredAt = enteredAt
        self.durationSeconds = durationSeconds
    }
}

/// Computed statistics for the Stats screen and dashboard summary cards.
struct TrackerStatistics: Sendable, Equatable {
    var totalZCTAs: Int
    var totalVisits: Int
    var newThisWeek: Int
    var newThisMonth: Int
    var newThisYear: Int
    var mostVisitedCode: String?
    var mostVisitedCount: Int
    var longestTotalTimeCode: String?
    var longestTotalTimeSeconds: Double
    var longestSingleVisitCode: String?
    var longestSingleVisitSeconds: Double
    var trackingDayCount: Int
    var milestones: [Int]

    static let empty = TrackerStatistics(
        totalZCTAs: 0, totalVisits: 0, newThisWeek: 0, newThisMonth: 0, newThisYear: 0,
        mostVisitedCode: nil, mostVisitedCount: 0,
        longestTotalTimeCode: nil, longestTotalTimeSeconds: 0,
        longestSingleVisitCode: nil, longestSingleVisitSeconds: 0,
        trackingDayCount: 0, milestones: []
    )
}

/// Pure statistics computation. Date math uses an injectable calendar/now so it
/// is fully deterministic and testable.
struct StatisticsService {

    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Milestone thresholds (ZCTA counts).
    static let milestoneThresholds = [1, 10, 25, 100]

    func computeStatistics(
        trackedZCTAs: [TrackedZCTASummary],
        visits: [VisitSummary],
        now: Date = .now
    ) -> TrackerStatistics {
        let active = trackedZCTAs.filter { !$0.isArchived }

        let totalZCTAs = active.count
        let totalVisits = visits.count

        let weekStart = startOfWeek(now)
        let monthStart = startOfMonth(now)
        let yearStart = startOfYear(now)

        let newThisWeek = active.filter { $0.firstEnteredAt >= weekStart }.count
        let newThisMonth = active.filter { $0.firstEnteredAt >= monthStart }.count
        let newThisYear = active.filter { $0.firstEnteredAt >= yearStart }.count

        // Most visited.
        let mostVisited = active.max { lhs, rhs in
            if lhs.visitCount != rhs.visitCount { return lhs.visitCount < rhs.visitCount }
            return lhs.code > rhs.code // stable: lexicographically smaller wins ties
        }

        // Longest total time.
        let longestTotal = active.max { lhs, rhs in
            if lhs.totalDurationSeconds != rhs.totalDurationSeconds {
                return lhs.totalDurationSeconds < rhs.totalDurationSeconds
            }
            return lhs.code > rhs.code
        }

        // Longest single visit.
        let longestSingle = visits.max { lhs, rhs in
            if lhs.durationSeconds != rhs.durationSeconds {
                return lhs.durationSeconds < rhs.durationSeconds
            }
            return lhs.code > rhs.code
        }

        // Distinct tracking days (by visit entry day).
        let days = Set(visits.map { calendar.startOfDay(for: $0.enteredAt) })

        let milestones = Self.milestoneThresholds.filter { totalZCTAs >= $0 }

        return TrackerStatistics(
            totalZCTAs: totalZCTAs,
            totalVisits: totalVisits,
            newThisWeek: newThisWeek,
            newThisMonth: newThisMonth,
            newThisYear: newThisYear,
            mostVisitedCode: mostVisited?.code,
            mostVisitedCount: mostVisited?.visitCount ?? 0,
            longestTotalTimeCode: longestTotal?.code,
            longestTotalTimeSeconds: longestTotal?.totalDurationSeconds ?? 0,
            longestSingleVisitCode: longestSingle?.code,
            longestSingleVisitSeconds: longestSingle?.durationSeconds ?? 0,
            trackingDayCount: days.count,
            milestones: milestones
        )
    }

    // MARK: - Date helpers

    func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    func startOfMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    func startOfYear(_ date: Date) -> Date {
        calendar.dateInterval(of: .year, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
