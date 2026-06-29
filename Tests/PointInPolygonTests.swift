import XCTest
import CoreLocation
@testable import Roam

final class PointInPolygonTests: XCTestCase {

    // A simple unit square ring (lon/lat) from (0,0) to (1,1), closed.
    private func unitSquare() -> [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 1),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 1, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0)
        ]
    }

    private func ring(_ pts: [(Double, Double)]) -> PolygonRing {
        // pts are (lat, lon)
        let coords = pts.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
        return PolygonRing(coordinates: coords, isHole: false)
    }

    private func holeRing(_ pts: [(Double, Double)]) -> PolygonRing {
        let coords = pts.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
        return PolygonRing(coordinates: coords, isHole: true)
    }

    func testPointInsideSquare() {
        let c = Coordinate(latitude: 0.5, longitude: 0.5)
        XCTAssertTrue(PointInPolygon.isPoint(c, inRing: unitSquare()))
    }

    func testPointOutsideSquare() {
        let c = Coordinate(latitude: 2.0, longitude: 2.0)
        XCTAssertFalse(PointInPolygon.isPoint(c, inRing: unitSquare()))
    }

    func testPointExactlyOnEdgeCountsAsInside() {
        // On the bottom edge (lat 0), midway along.
        let onEdge = Coordinate(latitude: 0.0, longitude: 0.5)
        XCTAssertTrue(PointInPolygon.isPoint(onEdge, inRing: unitSquare()))
    }

    func testPointExactlyOnVertexCountsAsInside() {
        let onVertex = Coordinate(latitude: 1.0, longitude: 1.0)
        XCTAssertTrue(PointInPolygon.isPoint(onVertex, inRing: unitSquare()))
    }

    func testPolygonWithHolePointInHoleIsOutside() {
        // Exterior 0..10, hole 4..6.
        let exterior = ring([(0, 0), (0, 10), (10, 10), (10, 0), (0, 0)])
        let hole = holeRing([(4, 4), (4, 6), (6, 6), (6, 4), (4, 4)])
        let part = PolygonPart(exterior: exterior, holes: [hole])

        let inHole = Coordinate(latitude: 5, longitude: 5)
        XCTAssertFalse(PointInPolygon.isPoint(inHole, inPolygon: part))

        // A point inside exterior but outside hole is inside.
        let inLand = Coordinate(latitude: 1, longitude: 1)
        XCTAssertTrue(PointInPolygon.isPoint(inLand, inPolygon: part))
    }

    func testPointOnHoleBoundaryCountsAsInside() {
        let exterior = ring([(0, 0), (0, 10), (10, 10), (10, 0), (0, 0)])
        let hole = holeRing([(4, 4), (4, 6), (6, 6), (6, 4), (4, 4)])
        let part = PolygonPart(exterior: exterior, holes: [hole])

        // On the hole boundary (lat 4, lon between 4 and 6) -> still land.
        let onHoleEdge = Coordinate(latitude: 4, longitude: 5)
        XCTAssertTrue(PointInPolygon.isPoint(onHoleEdge, inPolygon: part))
    }

    func testMultiPolygonInsideOneOfTwoSquares() {
        let squareA = PolygonPart(
            exterior: ring([(0, 0), (0, 1), (1, 1), (1, 0), (0, 0)]),
            holes: []
        )
        let squareB = PolygonPart(
            exterior: ring([(10, 10), (10, 11), (11, 11), (11, 10), (10, 10)]),
            holes: []
        )
        let parts = [squareA, squareB]

        XCTAssertTrue(PointInPolygon.isPoint(Coordinate(latitude: 0.5, longitude: 0.5), inMultiPolygon: parts))
        XCTAssertTrue(PointInPolygon.isPoint(Coordinate(latitude: 10.5, longitude: 10.5), inMultiPolygon: parts))
        XCTAssertFalse(PointInPolygon.isPoint(Coordinate(latitude: 5, longitude: 5), inMultiPolygon: parts))
    }

    func testRingClosureHandling() {
        // An unclosed square (no repeated first point) should still classify correctly,
        // because ray-casting wraps j = count-1 to 0.
        let unclosed: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 1),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 1, longitude: 0)
        ]
        XCTAssertTrue(PointInPolygon.isPoint(Coordinate(latitude: 0.5, longitude: 0.5), inRing: unclosed))
        XCTAssertFalse(PointInPolygon.isPoint(Coordinate(latitude: 5, longitude: 5), inRing: unclosed))
    }

    func testEmptyAndDegenerateRingReturnsFalse() {
        XCTAssertFalse(PointInPolygon.isPoint(Coordinate(latitude: 0, longitude: 0), inRing: []))

        let twoPoints: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1)
        ]
        XCTAssertFalse(PointInPolygon.isPoint(Coordinate(latitude: 0.5, longitude: 0.5), inRing: twoPoints))
    }
}
