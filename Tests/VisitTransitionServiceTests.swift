import XCTest
import SwiftData
import CoreLocation
@testable import Roam

@MainActor
final class VisitTransitionServiceTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            TrackedZCTA.self,
            ZCTAVisit.self,
            TrackingEventLog.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    private func makeMatch(code: String, lat: Double = 37.7793, lon: Double = -122.4193) -> ZCTAMatch {
        ZCTAMatch(
            code: code,
            centroid: Coordinate(latitude: lat, longitude: lon),
            matchedCoordinate: Coordinate(latitude: lat, longitude: lon)
        )
    }

    private func makeSample(lat: Double = 37.7793, lon: Double = -122.4193, at timestamp: Date) -> LocationSample {
        LocationSample(
            coordinate: Coordinate(latitude: lat, longitude: lon),
            horizontalAccuracyMeters: 20,
            timestamp: timestamp,
            source: .standardLocation
        )
    }

    private func allTracked(_ context: ModelContext) throws -> [TrackedZCTA] {
        try context.fetch(FetchDescriptor<TrackedZCTA>())
    }

    private func allVisits(_ context: ModelContext) throws -> [ZCTAVisit] {
        try context.fetch(FetchDescriptor<ZCTAVisit>())
    }

    func testFirstProcessStartsFirstVisit() throws {
        let context = try makeContext()
        let service = VisitTransitionService(context: context, cooldownSeconds: 0, requireTwoConsecutiveMatches: false)
        let now = Date(timeIntervalSince1970: 1_000_000)

        let result = service.process(match: makeMatch(code: "94102"), sample: makeSample(at: now), now: now)
        XCTAssertEqual(result, .startedFirstVisit(code: "94102"))

        let tracked = try allTracked(context)
        XCTAssertEqual(tracked.count, 1)
        XCTAssertEqual(tracked.first?.zctaCode, "94102")

        let visits = try allVisits(context)
        XCTAssertEqual(visits.count, 1)
        XCTAssertNil(visits.first?.exitedAt)
    }

    func testSameCodeUpdatesCurrentVisit() throws {
        let context = try makeContext()
        let service = VisitTransitionService(context: context, cooldownSeconds: 0, requireTwoConsecutiveMatches: false)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let t1 = t0.addingTimeInterval(30)

        _ = service.process(match: makeMatch(code: "94102"), sample: makeSample(at: t0), now: t0)
        let result = service.process(match: makeMatch(code: "94102"), sample: makeSample(at: t1), now: t1)
        XCTAssertEqual(result, .updatedCurrentVisit(code: "94102"))

        let visits = try allVisits(context)
        XCTAssertEqual(visits.count, 1)
        XCTAssertEqual(visits.first?.acceptedSampleCount, 2)
    }

    func testTransitionClosesOldOpensNew() throws {
        let context = try makeContext()
        let service = VisitTransitionService(context: context, cooldownSeconds: 0, requireTwoConsecutiveMatches: false)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let t1 = t0.addingTimeInterval(60)

        _ = service.process(match: makeMatch(code: "94102"), sample: makeSample(at: t0), now: t0)
        let result = service.process(match: makeMatch(code: "94103"), sample: makeSample(at: t1), now: t1)
        XCTAssertEqual(result, .transitioned(from: "94102", to: "94103"))

        let visits = try allVisits(context)
        XCTAssertEqual(visits.count, 2)

        let closed = visits.filter { $0.exitedAt != nil }
        let open = visits.filter { $0.exitedAt == nil }
        XCTAssertEqual(closed.count, 1)
        XCTAssertEqual(closed.first?.zctaCode, "94102")
        XCTAssertEqual(open.count, 1)
        XCTAssertEqual(open.first?.zctaCode, "94103")
    }

    func testRequireTwoConsecutiveMatchesIgnoresThenTransitions() throws {
        let context = try makeContext()
        let service = VisitTransitionService(context: context, cooldownSeconds: 0, requireTwoConsecutiveMatches: true)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let t1 = t0.addingTimeInterval(30)
        let t2 = t0.addingTimeInterval(60)

        _ = service.process(match: makeMatch(code: "94102"), sample: makeSample(at: t0), now: t0)

        let first = service.process(match: makeMatch(code: "94103"), sample: makeSample(at: t1), now: t1)
        guard case .ignored = first else {
            return XCTFail("Expected first different-code to be ignored, got \(first)")
        }

        let second = service.process(match: makeMatch(code: "94103"), sample: makeSample(at: t2), now: t2)
        XCTAssertEqual(second, .transitioned(from: "94102", to: "94103"))
    }

    func testRevisitDoesNotDuplicateTrackedZCTA() throws {
        let context = try makeContext()
        let service = VisitTransitionService(context: context, cooldownSeconds: 0, requireTwoConsecutiveMatches: false)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let t1 = t0.addingTimeInterval(120)

        _ = service.process(match: makeMatch(code: "94102"), sample: makeSample(at: t0), now: t0)
        service.closeActiveVisit(at: t0.addingTimeInterval(60))

        let result = service.process(match: makeMatch(code: "94102"), sample: makeSample(at: t1), now: t1)
        XCTAssertEqual(result, .revisited(code: "94102"))

        let tracked = try allTracked(context)
        XCTAssertEqual(tracked.filter { $0.zctaCode == "94102" }.count, 1)

        let openVisits = try allVisits(context).filter { $0.exitedAt == nil }
        XCTAssertEqual(openVisits.count, 1)
    }

    func testLeadingZeroCodePreserved() throws {
        let context = try makeContext()
        let service = VisitTransitionService(context: context, cooldownSeconds: 0, requireTwoConsecutiveMatches: false)
        let now = Date(timeIntervalSince1970: 1_000_000)

        let result = service.process(match: makeMatch(code: "01776"), sample: makeSample(at: now), now: now)
        XCTAssertEqual(result, .startedFirstVisit(code: "01776"))

        let tracked = try allTracked(context)
        XCTAssertEqual(tracked.first?.zctaCode, "01776")
    }
}
