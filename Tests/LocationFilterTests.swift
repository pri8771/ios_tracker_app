import XCTest
import CoreLocation
@testable import Roam

final class LocationFilterTests: XCTestCase {

    private let filter = LocationFilter(rejectWorseThanMeters: 500)
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testInvalidCoordinateRejected() {
        let result = filter.evaluate(
            coordinate: Coordinate(latitude: 999, longitude: 0),
            horizontalAccuracy: 10,
            timestamp: now,
            now: now,
            source: .standardLocation,
            isSimulated: false,
            previous: nil
        )
        XCTAssertEqual(result, .rejected(.invalidCoordinate))
    }

    func testNegativeAccuracyRejected() {
        let result = filter.evaluate(
            coordinate: Coordinate(latitude: 37.0, longitude: -122.0),
            horizontalAccuracy: -1,
            timestamp: now,
            now: now,
            source: .standardLocation,
            isSimulated: false,
            previous: nil
        )
        XCTAssertEqual(result, .rejected(.negativeAccuracy))
    }

    func testPoorAccuracyRejected() {
        let result = filter.evaluate(
            coordinate: Coordinate(latitude: 37.0, longitude: -122.0),
            horizontalAccuracy: 600,
            timestamp: now,
            now: now,
            source: .standardLocation,
            isSimulated: false,
            previous: nil
        )
        XCTAssertEqual(result, .rejected(.poorAccuracy(600)))
    }

    func testNullIslandRejectedWhenNotSimulated() {
        let result = filter.evaluate(
            coordinate: Coordinate(latitude: 0, longitude: 0),
            horizontalAccuracy: 10,
            timestamp: now,
            now: now,
            source: .standardLocation,
            isSimulated: false,
            previous: nil
        )
        XCTAssertEqual(result, .rejected(.nullIsland))
    }

    func testNullIslandAcceptedWhenSimulated() {
        let result = filter.evaluate(
            coordinate: Coordinate(latitude: 0, longitude: 0),
            horizontalAccuracy: 10,
            timestamp: now,
            now: now,
            source: .simulated,
            isSimulated: true,
            previous: nil
        )
        if case .accepted = result {
            // expected
        } else {
            XCTFail("Expected (0,0) to be accepted when simulated, got \(result)")
        }
    }

    func testStaleTimestampRejectedWhenNotSimulated() {
        // 11 minutes old (> 600s max).
        let stale = now.addingTimeInterval(-11 * 60)
        let result = filter.evaluate(
            coordinate: Coordinate(latitude: 37.0, longitude: -122.0),
            horizontalAccuracy: 10,
            timestamp: stale,
            now: now,
            source: .standardLocation,
            isSimulated: false,
            previous: nil
        )
        guard case .rejected(.stale) = result else {
            return XCTFail("Expected stale rejection, got \(result)")
        }
    }

    func testImpossibleJumpRejected() {
        // Previous sample 1 second earlier, ~1 degree of latitude away (~111 km),
        // implying ~111000 m/s >> 100 m/s max.
        let previous = LocationSample(
            coordinate: Coordinate(latitude: 37.0, longitude: -122.0),
            horizontalAccuracyMeters: 10,
            timestamp: now.addingTimeInterval(-1),
            source: .standardLocation
        )
        let result = filter.evaluate(
            coordinate: Coordinate(latitude: 38.0, longitude: -122.0),
            horizontalAccuracy: 10,
            timestamp: now,
            now: now,
            source: .standardLocation,
            isSimulated: false,
            previous: previous
        )
        guard case .rejected(.impossibleJump) = result else {
            return XCTFail("Expected impossibleJump rejection, got \(result)")
        }
    }

    func testGoodSampleAcceptedWithHighConfidence() {
        let result = filter.evaluate(
            coordinate: Coordinate(latitude: 37.7793, longitude: -122.4193),
            horizontalAccuracy: 20, // <= 100 -> high confidence
            timestamp: now,
            now: now,
            source: .standardLocation,
            isSimulated: false,
            previous: nil
        )
        guard case .accepted(let sample) = result else {
            return XCTFail("Expected accepted, got \(result)")
        }
        XCTAssertEqual(sample.confidence, .high)
        XCTAssertEqual(sample.horizontalAccuracyMeters, 20)
    }
}
