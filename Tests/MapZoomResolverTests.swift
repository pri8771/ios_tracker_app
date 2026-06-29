import XCTest
import MapKit
@testable import Roam

final class MapZoomResolverTests: XCTestCase {

    func testDelta30() {
        let plan = MapZoomResolver.plan(latitudeDelta: 30)
        XCTAssertEqual(plan.resolution, 0)
        XCTAssertFalse(plan.includeUnvisited)
        XCTAssertEqual(plan.maxOverlays, 150)
    }

    func testDelta10() {
        let plan = MapZoomResolver.plan(latitudeDelta: 10)
        XCTAssertEqual(plan.resolution, 0)
        XCTAssertFalse(plan.includeUnvisited)
        XCTAssertEqual(plan.maxOverlays, 150)
    }

    func testDelta3() {
        let plan = MapZoomResolver.plan(latitudeDelta: 3)
        XCTAssertEqual(plan.resolution, 0)
        XCTAssertTrue(plan.includeUnvisited)
        XCTAssertEqual(plan.maxOverlays, 250)
    }

    func testDelta1() {
        let plan = MapZoomResolver.plan(latitudeDelta: 1)
        XCTAssertEqual(plan.resolution, 1)
        XCTAssertTrue(plan.includeUnvisited)
        XCTAssertEqual(plan.maxOverlays, 500)
    }

    func testDeltaPoint3() {
        let plan = MapZoomResolver.plan(latitudeDelta: 0.3)
        XCTAssertEqual(plan.resolution, 2)
        XCTAssertTrue(plan.includeUnvisited)
        XCTAssertEqual(plan.maxOverlays, 750)
    }

    func testDeltaPoint05() {
        let plan = MapZoomResolver.plan(latitudeDelta: 0.05)
        XCTAssertEqual(plan.resolution, 3)
        XCTAssertTrue(plan.includeUnvisited)
        XCTAssertEqual(plan.maxOverlays, 1000)
    }

    func testAlwaysIncludeVisitedAndCurrent() {
        let deltas = [30.0, 10.0, 3.0, 1.0, 0.3, 0.05]
        for d in deltas {
            XCTAssertTrue(MapZoomResolver.plan(latitudeDelta: d).alwaysIncludeVisitedAndCurrent)
        }
    }
}
