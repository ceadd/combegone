import XCTest
@testable import CombegoneCore

final class OutputNamingTests: XCTestCase {
    func testAppendsNoAdsSuffix() {
        let input = URL(fileURLWithPath: "/rec/Show S01E02.ts")
        let out = OutputNaming.outputURL(for: input) { _ in false }
        XCTAssertEqual(out.path, "/rec/Show S01E02 (no ads).ts")
    }

    func testAvoidsOverwritingExistingFile() {
        let input = URL(fileURLWithPath: "/rec/Movie.mpg")
        let taken: Set<String> = ["/rec/Movie (no ads).mpg", "/rec/Movie (no ads 2).mpg"]
        let out = OutputNaming.outputURL(for: input) { taken.contains($0.path) }
        XCTAssertEqual(out.path, "/rec/Movie (no ads 3).mpg")
    }

    func testFileWithoutExtension() {
        let input = URL(fileURLWithPath: "/rec/recording")
        XCTAssertEqual(OutputNaming.outputURL(for: input) { _ in false }.path, "/rec/recording (no ads)")
    }
}
