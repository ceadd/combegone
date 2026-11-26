import XCTest
@testable import CombegoneCore

final class OptionsTests: XCTestCase {
    func testDefaultsChangeNothing() {
        let o = ProcessingOptions()
        XCTAssertFalse(o.replaceOriginal)
        XCTAssertFalse(o.customDetection)
        XCTAssertEqual(o.iniOverrides, [])
    }

    func testCustomDetectionWritesIniLines() {
        var o = ProcessingOptions()
        o.customDetection = true
        o.detectMethods = [.blackFrames, .silence]
        o.minCommercialBreak = 20
        o.keepFirstSeconds = 10
        XCTAssertEqual(o.iniOverrides, [
            "detect_method=65",
            "excessive_length_modifier=1",
            "min_commercialbreak=20",
            "max_commercialbreak=600",
            "min_show_segment_length=125",
            "min_commercial_size=4",
            "max_commercial_size=125",
            "thread_count=4",
        ])
    }

    func testKeepEndIsNotPassedToComskip() {
        var o = ProcessingOptions()
        o.keepLastSeconds = 120
        XCTAssertEqual(o.iniOverrides, [])
    }

    func testIniPutsOverridesFirstBecauseComskipUsesFirstMatch() {
        let s = Tools.iniContents(base: "detect_method=43\noutput_edl=0\n", overrides: ["detect_method=1"])
        XCTAssertEqual(s, "detect_method=1\noutput_edl=1\ndetect_method=43\noutput_edl=0\n")
    }

    func testRoundTripsThroughUserDefaults() {
        let d = UserDefaults(suiteName: "combegone-test-\(UUID())")!
        var o = ProcessingOptions()
        o.replaceOriginal = true
        o.customDetection = true
        o.detectMethods = [.logo, .sceneChange]
        o.maxCommercialBreak = 300
        o.save(to: d)
        XCTAssertEqual(ProcessingOptions.load(from: d), o)
    }

    func testDetectMethodDefaultMatchesBundledIni() {
        XCTAssertEqual(ProcessingOptions().detectMethods.bitmask, 111)
        XCTAssertFalse(ProcessingOptions().useUserIni)
    }
}
