import XCTest
@testable import Roam

final class StatisticsServiceTests: XCTestCase {

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return calendar.date(from: comps)!
    }

    func testTotalsAndNewThisMonth() {
        let cal = utcCalendar()
        let service = StatisticsService(calendar: cal)
        let now = date(2026, 6, 15, calendar: cal)

        let tracked = [
            // entered this month (June 2026)
            TrackedZCTASummary(code: "94102", firstEnteredAt: date(2026, 6, 1, calendar: cal),
                               lastEnteredAt: date(2026, 6, 10, calendar: cal),
                               visitCount: 5, totalDurationSeconds: 1000),
            // entered last month (May 2026)
            TrackedZCTASummary(code: "94103", firstEnteredAt: date(2026, 5, 20, calendar: cal),
                               lastEnteredAt: date(2026, 6, 2, calendar: cal),
                               visitCount: 2, totalDurationSeconds: 500),
            // entered this month
            TrackedZCTASummary(code: "94110", firstEnteredAt: date(2026, 6, 14, calendar: cal),
                               lastEnteredAt: date(2026, 6, 14, calendar: cal),
                               visitCount: 1, totalDurationSeconds: 100)
        ]

        let visits = [
            VisitSummary(code: "94102", enteredAt: date(2026, 6, 1, calendar: cal), durationSeconds: 600),
            VisitSummary(code: "94102", enteredAt: date(2026, 6, 5, calendar: cal), durationSeconds: 400),
            VisitSummary(code: "94103", enteredAt: date(2026, 5, 20, calendar: cal), durationSeconds: 5000),
            VisitSummary(code: "94110", enteredAt: date(2026, 6, 14, calendar: cal), durationSeconds: 100)
        ]

        let stats = service.computeStatistics(trackedZCTAs: tracked, visits: visits, now: now)

        XCTAssertEqual(stats.totalZCTAs, 3)
        XCTAssertEqual(stats.totalVisits, 4)
        // Only 94102 and 94110 first entered within June 2026.
        XCTAssertEqual(stats.newThisMonth, 2)
    }

    func testMostVisitedPicksMax() {
        let cal = utcCalendar()
        let service = StatisticsService(calendar: cal)
        let now = date(2026, 6, 15, calendar: cal)

        let tracked = [
            TrackedZCTASummary(code: "94102", firstEnteredAt: date(2026, 1, 1, calendar: cal),
                               lastEnteredAt: date(2026, 1, 1, calendar: cal),
                               visitCount: 3, totalDurationSeconds: 100),
            TrackedZCTASummary(code: "94103", firstEnteredAt: date(2026, 1, 1, calendar: cal),
                               lastEnteredAt: date(2026, 1, 1, calendar: cal),
                               visitCount: 9, totalDurationSeconds: 100),
            TrackedZCTASummary(code: "94110", firstEnteredAt: date(2026, 1, 1, calendar: cal),
                               lastEnteredAt: date(2026, 1, 1, calendar: cal),
                               visitCount: 1, totalDurationSeconds: 100)
        ]

        let stats = service.computeStatistics(trackedZCTAs: tracked, visits: [], now: now)
        XCTAssertEqual(stats.mostVisitedCode, "94103")
        XCTAssertEqual(stats.mostVisitedCount, 9)
    }

    func testLongestSingleVisitPicksMaxDuration() {
        let cal = utcCalendar()
        let service = StatisticsService(calendar: cal)
        let now = date(2026, 6, 15, calendar: cal)

        let visits = [
            VisitSummary(code: "94102", enteredAt: date(2026, 6, 1, calendar: cal), durationSeconds: 300),
            VisitSummary(code: "94103", enteredAt: date(2026, 6, 2, calendar: cal), durationSeconds: 7200),
            VisitSummary(code: "94110", enteredAt: date(2026, 6, 3, calendar: cal), durationSeconds: 1200)
        ]

        let stats = service.computeStatistics(trackedZCTAs: [], visits: visits, now: now)
        XCTAssertEqual(stats.longestSingleVisitCode, "94103")
        XCTAssertEqual(stats.longestSingleVisitSeconds, 7200)
    }

    func testTrackingDayCountCountsDistinctEntryDays() {
        let cal = utcCalendar()
        let service = StatisticsService(calendar: cal)
        let now = date(2026, 6, 15, calendar: cal)

        // Two visits on June 1, one on June 2, one on June 3 -> 3 distinct days.
        var june1Morning = DateComponents()
        june1Morning.year = 2026; june1Morning.month = 6; june1Morning.day = 1; june1Morning.hour = 8
        var june1Evening = DateComponents()
        june1Evening.year = 2026; june1Evening.month = 6; june1Evening.day = 1; june1Evening.hour = 20

        let visits = [
            VisitSummary(code: "94102", enteredAt: cal.date(from: june1Morning)!, durationSeconds: 100),
            VisitSummary(code: "94103", enteredAt: cal.date(from: june1Evening)!, durationSeconds: 100),
            VisitSummary(code: "94110", enteredAt: date(2026, 6, 2, calendar: cal), durationSeconds: 100),
            VisitSummary(code: "94114", enteredAt: date(2026, 6, 3, calendar: cal), durationSeconds: 100)
        ]

        let stats = service.computeStatistics(trackedZCTAs: [], visits: visits, now: now)
        XCTAssertEqual(stats.trackingDayCount, 3)
    }
}
