import XCTest
import CoreLocation
@testable import Roam

final class BoundaryDistanceTests: XCTestCase {

    /// A ~0.01° square around (37.00…37.01, -122.00…-121.99).
    private func squarePart() -> PolygonPart {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.00, longitude: -122.00),
            CLLocationCoordinate2D(latitude: 37.00, longitude: -121.99),
            CLLocationCoordinate2D(latitude: 37.01, longitude: -121.99),
            CLLocationCoordinate2D(latitude: 37.01, longitude: -122.00),
            CLLocationCoordinate2D(latitude: 37.00, longitude: -122.00)
        ]
        return PolygonPart(exterior: PolygonRing(coordinates: coords, isHole: false), holes: [])
    }

    func testCenterDistanceIsAboutHalfTheNarrowerSide() {
        let center = Coordinate(latitude: 37.005, longitude: -121.995)
        let d = PointInPolygon.distanceToBoundaryMeters(from: center, parts: [squarePart()])
        XCTAssertNotNil(d)
        // Nearest edge is the E/W side: 0.005° lon * 111320 * cos(37°) ≈ 444 m.
        XCTAssertEqual(d!, 444, accuracy: 25)
    }

    func testPointNearEdgeHasSmallDistance() {
        // ~9 m inside the eastern edge (lon -121.99): 0.0001° * 111320 * cos(37°).
        let nearEdge = Coordinate(latitude: 37.005, longitude: -121.9901)
        let d = PointInPolygon.distanceToBoundaryMeters(from: nearEdge, parts: [squarePart()])
        XCTAssertNotNil(d)
        XCTAssertLessThan(d!, 30)
    }

    func testCloserToBoundaryIsSmaller() {
        let center = Coordinate(latitude: 37.005, longitude: -121.995)
        let nearEdge = Coordinate(latitude: 37.0005, longitude: -121.995)
        let dc = PointInPolygon.distanceToBoundaryMeters(from: center, parts: [squarePart()])!
        let de = PointInPolygon.distanceToBoundaryMeters(from: nearEdge, parts: [squarePart()])!
        XCTAssertLessThan(de, dc)
    }
}
