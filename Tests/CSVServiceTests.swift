import XCTest
@testable import Roam

final class CSVServiceTests: XCTestCase {

    private let service = CSVService()

    func testEscapePlainFieldUnquoted() {
        XCTAssertEqual(service.escape("hello"), "hello")
        XCTAssertEqual(service.escape("94102"), "94102")
    }

    func testEscapeCommaWrapsInQuotes() {
        XCTAssertEqual(service.escape("a,b"), "\"a,b\"")
    }

    func testEscapeQuoteDoublesAndWraps() {
        // A field containing a quote: quotes doubled, whole field wrapped.
        XCTAssertEqual(service.escape("she said \"hi\""), "\"she said \"\"hi\"\"\"")
    }

    func testEscapeNewlineWrapsInQuotes() {
        XCTAssertEqual(service.escape("line1\nline2"), "\"line1\nline2\"")
    }

    func testVisitsCSVHeaderRow() {
        let csv = service.visitsCSV([])
        let firstLine = csv.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init)
        XCTAssertEqual(firstLine, CSVService.visitHeaders.joined(separator: ","))
    }

    func testSummaryCSVHeaderRow() {
        let csv = service.summaryCSV([])
        let firstLine = csv.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init)
        XCTAssertEqual(firstLine, CSVService.summaryHeaders.joined(separator: ","))
    }

    func testValueWithCommaRoundTripsAsQuotedField() {
        let summary = TrackedZCTAExportDTO(
            zctaCode: "94102",
            displayName: "Civic Center",
            note: "great, place",
            firstEnteredAt: Date(timeIntervalSince1970: 1_000_000),
            lastEnteredAt: Date(timeIntervalSince1970: 1_000_500),
            lastSeenAt: Date(timeIntervalSince1970: 1_000_500),
            visitCount: 3,
            totalDurationSeconds: 1234,
            firstEntryLatitude: 37.7793,
            firstEntryLongitude: -122.4193,
            centroidLatitude: 37.78,
            centroidLongitude: -122.42,
            isFavorite: true,
            isArchived: false
        )

        let csv = service.summaryCSV([summary])
        // The note "great, place" must be quoted in the output.
        XCTAssertTrue(csv.contains("\"great, place\""))
    }

    func testVisitsCSVProducesDataRow() {
        let visit = ZCTAVisitExportDTO(
            visitId: UUID(),
            zctaCode: "94102",
            enteredAt: Date(timeIntervalSince1970: 1_000_000),
            exitedAt: Date(timeIntervalSince1970: 1_000_600),
            durationSeconds: 600,
            entryLatitude: 37.7793,
            entryLongitude: -122.4193,
            lastLatitude: 37.7795,
            lastLongitude: -122.4190,
            detectionSource: "standardLocation",
            confidence: "high",
            acceptedSampleCount: 5,
            isSimulated: false
        )
        let csv = service.visitsCSV([visit])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        // header + one data row + trailing empty from final "\n"
        XCTAssertTrue(lines.count >= 2)
        XCTAssertTrue(csv.contains("94102"))
    }
}
