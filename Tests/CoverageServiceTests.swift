import XCTest
@testable import Roam

final class CoverageServiceTests: XCTestCase {

    private let service = CoverageService()

    func testEmptyCodesYieldEmptySummary() {
        let summary = service.summary(forCodes: [])
        XCTAssertEqual(summary, .empty)
        XCTAssertEqual(summary.totalAreas, 0)
        XCTAssertNil(summary.topState)
    }

    func testTotalsAndDedup() {
        let summary = service.summary(forCodes: ["94103", "94103", "94110", "10001"])
        XCTAssertEqual(summary.totalAreas, 3)         // duplicates collapsed
        XCTAssertEqual(summary.statesTouched, 2)       // CA + NY
    }

    func testStatesSortedByAreaCountDescending() {
        let codes = ["94103", "94110", "94107", "10001"]  // 3 CA, 1 NY
        let summary = service.summary(forCodes: codes)
        XCTAssertEqual(summary.topState?.state.code, "CA")
        XCTAssertEqual(summary.topState?.areaCount, 3)
        XCTAssertEqual(summary.states.last?.state.code, "NY")
    }

    func testFractionIsBoundedAndEstimated() {
        let summary = service.summary(forCodes: ["94103"])
        let ca = summary.states.first
        XCTAssertNotNil(ca?.fraction)
        XCTAssertGreaterThan(ca!.fraction!, 0)
        XCTAssertLessThanOrEqual(ca!.fraction!, 1)
    }

    func testNationalFractionCountsOnlyRealStates() {
        // Two states out of 50.
        let summary = service.summary(forCodes: ["94103", "10001"])
        XCTAssertEqual(summary.nationalStatesFraction, 2.0 / 50.0, accuracy: 0.0001)
    }
}
