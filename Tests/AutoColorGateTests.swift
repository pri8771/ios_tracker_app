import XCTest
@testable import Roam

final class AutoColorGateTests: XCTestCase {

    func testHighAccuracyClearOfBoundaryColors() {
        let gate = AutoColorGate()  // 100m accuracy, 25m margin
        let decision = gate.evaluate(horizontalAccuracy: 30, distanceToBoundaryMeters: 400)
        XCTAssertEqual(decision, .color)
        XCTAssertTrue(decision.allowsColoring)
    }

    func testAccuracyWorseThan100MetersIsSkipped() {
        let gate = AutoColorGate()
        let decision = gate.evaluate(horizontalAccuracy: 150, distanceToBoundaryMeters: 1000)
        XCTAssertEqual(decision, .skipLowAccuracy(150))
        XCTAssertFalse(decision.allowsColoring)
    }

    func testExactlyAtThresholdColors() {
        let gate = AutoColorGate()
        let decision = gate.evaluate(horizontalAccuracy: 100, distanceToBoundaryMeters: 500)
        XCTAssertEqual(decision, .color)
    }

    func testNearBoundaryWithinAccuracyRadiusIsSkipped() {
        let gate = AutoColorGate()
        // Accuracy 60m, but only 40m from the edge → could be in a neighbor.
        let decision = gate.evaluate(horizontalAccuracy: 60, distanceToBoundaryMeters: 40)
        XCTAssertEqual(decision, .skipNearBoundary(40))
    }

    func testNearBoundaryWithinFixedMarginIsSkipped() {
        let gate = AutoColorGate()
        // High accuracy (10m) but 20m from edge → still inside the 25m margin.
        let decision = gate.evaluate(horizontalAccuracy: 10, distanceToBoundaryMeters: 20)
        XCTAssertEqual(decision, .skipNearBoundary(20))
    }

    func testUnknownBoundaryDistanceUsesAccuracyGateOnly() {
        let gate = AutoColorGate()
        XCTAssertEqual(gate.evaluate(horizontalAccuracy: 50, distanceToBoundaryMeters: nil), .color)
        XCTAssertEqual(gate.evaluate(horizontalAccuracy: 200, distanceToBoundaryMeters: nil), .skipLowAccuracy(200))
    }

    func testSimulatedAlwaysColors() {
        let gate = AutoColorGate()
        let decision = gate.evaluate(horizontalAccuracy: 9999, distanceToBoundaryMeters: 1, isSimulated: true)
        XCTAssertEqual(decision, .color)
    }
}
