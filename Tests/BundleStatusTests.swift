import XCTest
@testable import Roam

final class BundleStatusTests: XCTestCase {

    private let meta = ZCTABundleMetadata.unknown

    func testProductionAllowsTracking() {
        XCTAssertTrue(ZCTABundleStatus.production(meta).allowsTracking)
    }

    func testSampleAllowsTrackingForLabeledBeta() {
        // The beta ships labeled, limited (sample) geography and must still track.
        XCTAssertTrue(ZCTABundleStatus.sample(meta).allowsTracking)
    }

    func testMissingBlocksTracking() {
        XCTAssertFalse(ZCTABundleStatus.missing.allowsTracking)
    }

    func testStatusFlags() {
        XCTAssertTrue(ZCTABundleStatus.sample(meta).isSample)
        XCTAssertTrue(ZCTABundleStatus.production(meta).isProduction)
        XCTAssertTrue(ZCTABundleStatus.missing.isMissing)
    }
}
