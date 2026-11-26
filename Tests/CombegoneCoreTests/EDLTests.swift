import XCTest
@testable import CombegoneCore

final class EDLTests: XCTestCase {
    func testParsesComskipEDL() {
        let ranges = EDL.parse("0.00\t30.50\t0\n600.0\t780.2\t0\n")
        XCTAssertEqual(ranges, [TimeRange(start: 0, end: 30.5), TimeRange(start: 600, end: 780.2)])
    }

    func testIgnoresMalformedLinesAndSortsAndMerges() {
        let text = "garbage\n900\t950\t0\n\n100\t200\t0\n150\t250\t0\n300\t290\t0\n"
        XCTAssertEqual(EDL.parse(text), [TimeRange(start: 100, end: 250), TimeRange(start: 900, end: 950)])
    }

    func testKeepSegmentsBetweenCuts() {
        let cuts = [TimeRange(start: 0, end: 30.5), TimeRange(start: 600, end: 780.2)]
        XCTAssertEqual(Segments.keep(cuts: cuts, duration: 1800),
                       [TimeRange(start: 30.5, end: 600), TimeRange(start: 780.2, end: 1800)])
    }

    func testNoCutsKeepsWholeFile() {
        XCTAssertEqual(Segments.keep(cuts: [], duration: 100), [TimeRange(start: 0, end: 100)])
    }

    func testCutRunningToEndLeavesNoTrailingSegment() {
        let cuts = [TimeRange(start: 50, end: 100.2)]
        XCTAssertEqual(Segments.keep(cuts: cuts, duration: 100), [TimeRange(start: 0, end: 50)])
    }

    func testDropsTinySlivers() {
        let cuts = [TimeRange(start: 0.2, end: 10), TimeRange(start: 10.3, end: 20)]
        XCTAssertEqual(Segments.keep(cuts: cuts, duration: 30), [TimeRange(start: 20, end: 30)])
    }

    func testProtectEndTrimsFinalBreakButKeepsAds() {
        // Break 300–402.5 swallowed 40s of credits; keep the last 45s.
        let cuts = [TimeRange(start: 100, end: 160), TimeRange(start: 300, end: 402.5)]
        XCTAssertEqual(Segments.protect(cuts: cuts, duration: 402.5, keepFirst: 0, keepLast: 45),
                       [TimeRange(start: 100, end: 160), TimeRange(start: 300, end: 357.5)])
    }

    func testProtectStartDropsCutsInsideWindow() {
        let cuts = [TimeRange(start: 0, end: 20), TimeRange(start: 25, end: 90), TimeRange(start: 200, end: 260)]
        XCTAssertEqual(Segments.protect(cuts: cuts, duration: 500, keepFirst: 30, keepLast: 0),
                       [TimeRange(start: 30, end: 90), TimeRange(start: 200, end: 260)])
    }

    func testProtectOffChangesNothing() {
        let cuts = [TimeRange(start: 0, end: 20)]
        XCTAssertEqual(Segments.protect(cuts: cuts, duration: 100, keepFirst: 0, keepLast: 0), cuts)
    }

    func testRemovedSeconds() {
        let keep = [TimeRange(start: 30, end: 600), TimeRange(start: 780, end: 1800)]
        XCTAssertEqual(Segments.removedSeconds(keep: keep, duration: 1800), 210, accuracy: 0.001)
    }
}
