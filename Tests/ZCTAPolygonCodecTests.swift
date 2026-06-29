import XCTest
import CoreLocation
@testable import Roam

final class ZCTAPolygonCodecTests: XCTestCase {

    func testEncodeDecodeRoundTripPreservesCoordinates() {
        let original = [
            CLLocationCoordinate2D(latitude: 37.7793, longitude: -122.4193),
            CLLocationCoordinate2D(latitude: 37.7800, longitude: -122.4100),
            CLLocationCoordinate2D(latitude: 37.7700, longitude: -122.4000),
            CLLocationCoordinate2D(latitude: 37.7793, longitude: -122.4193)
        ]
        let data = ZCTAPolygonCodec.encode(original)
        let decoded = ZCTAPolygonCodec.decode(data)

        XCTAssertEqual(decoded.count, original.count)
        for (a, b) in zip(original, decoded) {
            XCTAssertEqual(a.latitude, b.latitude, accuracy: 1e-5)
            XCTAssertEqual(a.longitude, b.longitude, accuracy: 1e-5)
        }
    }

    func testEnsureClosedRepeatsFirstPoint() {
        let open = [
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 2, longitude: 2),
            CLLocationCoordinate2D(latitude: 3, longitude: 3)
        ]
        let closed = ZCTAPolygonCodec.ensureClosed(open)
        XCTAssertEqual(closed.count, open.count + 1)
        XCTAssertEqual(closed.first!.latitude, closed.last!.latitude)
        XCTAssertEqual(closed.first!.longitude, closed.last!.longitude)

        // Already-closed rings are returned unchanged in length.
        let already = ZCTAPolygonCodec.ensureClosed(closed)
        XCTAssertEqual(already.count, closed.count)
    }

    func testDecodeEmptyDataReturnsEmpty() {
        XCTAssertTrue(ZCTAPolygonCodec.decode(Data()).isEmpty)
    }

    func testDecodeMalformedOddLengthReturnsEmpty() {
        // Not a multiple of bytesPerPoint (8).
        let malformed = Data([0x01, 0x02, 0x03])
        XCTAssertTrue(ZCTAPolygonCodec.decode(malformed).isEmpty)
    }

    func testNoNaNInDecodedOutput() {
        let original = [
            CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
            CLLocationCoordinate2D(latitude: -33.8700, longitude: 151.2100)
        ]
        let decoded = ZCTAPolygonCodec.decode(ZCTAPolygonCodec.encode(original))
        for c in decoded {
            XCTAssertFalse(c.latitude.isNaN)
            XCTAssertFalse(c.longitude.isNaN)
            XCTAssertTrue(c.latitude.isFinite)
            XCTAssertTrue(c.longitude.isFinite)
        }
    }
}
