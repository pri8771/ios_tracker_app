import XCTest
@testable import Roam

final class USStateResolverTests: XCTestCase {

    func testKnownPrefixesResolveToStates() {
        XCTAssertEqual(USStateResolver.state(forZIP: "94103")?.code, "CA")
        XCTAssertEqual(USStateResolver.state(forZIP: "10001")?.code, "NY")
        XCTAssertEqual(USStateResolver.state(forZIP: "33101")?.code, "FL")
        XCTAssertEqual(USStateResolver.state(forZIP: "75201")?.code, "TX")
        XCTAssertEqual(USStateResolver.state(forZIP: "99501")?.code, "AK")
        XCTAssertEqual(USStateResolver.state(forZIP: "60601")?.code, "IL")
    }

    func testLeadingZeroCodesResolve() {
        // 02139 = Cambridge, MA; 01776 = Sudbury, MA.
        XCTAssertEqual(USStateResolver.state(forZIP: "02139")?.code, "MA")
        XCTAssertEqual(USStateResolver.state(forZIP: "01776")?.code, "MA")
        // 00601 = Puerto Rico.
        XCTAssertEqual(USStateResolver.state(forZIP: "00601")?.code, "PR")
    }

    func testStateNameResolved() {
        XCTAssertEqual(USStateResolver.state(forZIP: "94103")?.name, "California")
    }

    func testInvalidInputsReturnNil() {
        XCTAssertNil(USStateResolver.state(forZIP: ""))
        XCTAssertNil(USStateResolver.state(forZIP: "ab"))
        XCTAssertNil(USStateResolver.state(forZIP: "12"))   // too short
    }

    func testDistinctStatesAreDedupedAndSorted() {
        let states = USStateResolver.states(forZIPs: ["94103", "90001", "10001", "94110"])
        XCTAssertEqual(states.map(\.code), ["CA", "NY"])  // sorted by name: California < New York
    }

    func testApproximateCountsAvailableForAllStates() {
        for code in USStateResolver.allStateCodes {
            XCTAssertNotNil(USStateResolver.approximateZCTACount(for: code), "missing count for \(code)")
        }
        XCTAssertEqual(USStateResolver.allStateCodes.count, 50)
    }
}
