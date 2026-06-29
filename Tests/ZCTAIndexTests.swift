import XCTest
import MapKit
import CoreLocation
@testable import Roam

final class ZCTAIndexTests: XCTestCase {

    private func sampleDatabasePath() -> String? {
        let bundle = Bundle(for: type(of: self))
        if let url = bundle.url(forResource: "zcta_sample", withExtension: "sqlite", subdirectory: "ZCTA") {
            return url.path
        }
        if let url = bundle.url(forResource: "zcta_sample", withExtension: "sqlite") {
            return url.path
        }
        return nil
    }

    func testLoadMetadataIsNotProduction() throws {
        let path = sampleDatabasePath()
        try XCTSkipIf(path == nil, "sample bundle not in test resources")
        let service = ZCTAGeometryService(databasePath: path!, treatAsProduction: false)
        let index = try XCTUnwrap(service.index)
        XCTAssertFalse(index.metadata.isProduction)
        XCTAssertFalse(service.status.isProduction)
        XCTAssertTrue(service.status.isSample)
    }

    func testMatchInsideSanFrancisco() throws {
        let path = sampleDatabasePath()
        try XCTSkipIf(path == nil, "sample bundle not in test resources")
        let service = ZCTAGeometryService(databasePath: path!, treatAsProduction: false)
        let index = try XCTUnwrap(service.index)

        let coord = Coordinate(latitude: 37.7793, longitude: -122.4193)
        let match = index.match(coordinate: coord)
        XCTAssertEqual(match?.code, "94102")
    }

    func testMatchFarOutsideReturnsNil() throws {
        let path = sampleDatabasePath()
        try XCTSkipIf(path == nil, "sample bundle not in test resources")
        let service = ZCTAGeometryService(databasePath: path!, treatAsProduction: false)
        let index = try XCTUnwrap(service.index)

        // New York City — far from the SF sample data.
        let coord = Coordinate(latitude: 40.0, longitude: -74.0)
        XCTAssertNil(index.match(coordinate: coord))
    }

    func testVisiblePolygonsForSFRegionReturnsItems() throws {
        let path = sampleDatabasePath()
        try XCTSkipIf(path == nil, "sample bundle not in test resources")
        let service = ZCTAGeometryService(databasePath: path!, treatAsProduction: false)
        let index = try XCTUnwrap(service.index)

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7793, longitude: -122.4193),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
        let items = index.visiblePolygons(
            in: region,
            includeVisitedCodes: [],
            currentCode: nil,
            selectedCode: nil,
            showUnvisited: true
        )
        XCTAssertFalse(items.isEmpty)
    }

    func testProductionFlagFalse() throws {
        let path = sampleDatabasePath()
        try XCTSkipIf(path == nil, "sample bundle not in test resources")
        let service = ZCTAGeometryService(databasePath: path!, treatAsProduction: false)
        XCTAssertFalse(service.status.isProduction)
    }
}
