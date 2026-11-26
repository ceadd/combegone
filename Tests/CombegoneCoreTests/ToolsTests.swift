import XCTest
@testable import CombegoneCore

final class ToolsTests: XCTestCase {
    func testComskipArgs() {
        let args = Tools.comskipArgs(input: URL(fileURLWithPath: "/r/My Show.ts"),
                                     ini: URL(fileURLWithPath: "/t/comskip.ini"),
                                     outputDir: URL(fileURLWithPath: "/t"))
        XCTAssertEqual(args, ["--ini=/t/comskip.ini", "--output=/t", "/r/My Show.ts"])
    }

    func testIniForcesEDLOutput() {
        XCTAssertEqual(Tools.iniContents(base: "detect_method=43\n"), "output_edl=1\ndetect_method=43\n")
    }

    func testSegmentArgsUseStreamCopy() {
        let args = Tools.segmentArgs(input: URL(fileURLWithPath: "/r/a.ts"),
                                     segment: TimeRange(start: 30.5, end: 600),
                                     output: URL(fileURLWithPath: "/t/part1.ts"))
        XCTAssertEqual(Array(args.prefix(6)), ["-nostdin", "-hide_banner", "-y", "-ss", "30.500", "-i"])
        XCTAssertTrue(args.contains("/r/a.ts"))
        XCTAssertEqual(args[args.firstIndex(of: "-t")! + 1], "569.500")
        XCTAssertEqual(args[args.firstIndex(of: "-c")! + 1], "copy")
        XCTAssertEqual(args.last, "/t/part1.ts")
    }

    func testConcatListEscapesQuotes() {
        let list = Tools.concatList(parts: [URL(fileURLWithPath: "/t/it's 1.ts"), URL(fileURLWithPath: "/t/b.ts")])
        XCTAssertEqual(list, "file '/t/it'\\''s 1.ts'\nfile '/t/b.ts'\n")
    }

    func testJoinArgs() {
        let args = Tools.joinArgs(concatList: URL(fileURLWithPath: "/t/list.txt"),
                                  output: URL(fileURLWithPath: "/r/a (no ads).ts"))
        XCTAssertEqual(args, ["-nostdin", "-hide_banner", "-y", "-f", "concat", "-safe", "0",
                              "-i", "/t/list.txt", "-map", "0", "-c", "copy", "/r/a (no ads).ts"])
    }

    func testProcessRunnerCapturesLinesAndExitCode() async throws {
        var lines: [String] = []
        let code = try await ProcessRunner().run(URL(fileURLWithPath: "/bin/sh"),
                                                 ["-c", "echo one; echo two 1>&2; exit 3"]) { lines.append($0) }
        XCTAssertEqual(code, 3)
        XCTAssertEqual(Set(lines), ["one", "two"])
    }

    func testProcessRunnerCancelTerminatesChild() async throws {
        let task = Task { try await ProcessRunner().run(URL(fileURLWithPath: "/bin/sleep"), ["30"]) { _ in } }
        try await Task.sleep(nanoseconds: 200_000_000)
        let start = Date()
        task.cancel()
        _ = try? await task.value
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }
}

final class ProgressParsingTests: XCTestCase {
    func testComskipTimestamp() {
        XCTAssertEqual(Pipeline.leadingTimestamp("0:12:34.50 - 18842 frames in 20.1 sec"), 754.5)
        XCTAssertNil(Pipeline.leadingTimestamp("Commercials were found."))
    }
    func testFfmpegTime() {
        XCTAssertEqual(Pipeline.ffmpegTime("frame= 100 fps=0.0 q=-1.0 size= 1kB time=00:01:02.50 bitrate=1kbits/s"), 62.5)
    }
}
