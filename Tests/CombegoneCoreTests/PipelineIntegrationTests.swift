import XCTest
@testable import CombegoneCore

/// Runs the real bundled tools on a sample recording (copied to a temp folder first).
/// COMBEGONE_SAMPLE=/path/to/recording.ts swift test --filter PipelineIntegrationTests
@MainActor
final class PipelineIntegrationTests: XCTestCase {
    private var sample: URL!
    private var tools: ToolPaths!

    override func setUp() async throws {
        guard let path = ProcessInfo.processInfo.environment["COMBEGONE_SAMPLE"] else { throw XCTSkip("no sample") }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bin = root.appendingPathComponent("vendor/bin")
        tools = ToolPaths(comskip: bin.appendingPathComponent("comskip"), ffmpeg: bin.appendingPathComponent("ffmpeg"),
                          ffprobe: bin.appendingPathComponent("ffprobe"),
                          defaultIni: root.appendingPathComponent("Resources/comskip.ini"))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cg-it-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        sample = dir.appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: sample)
    }

    private func run(_ options: ProcessingOptions) async -> Job {
        let job = Job(input: sample)
        await Pipeline(tools: tools).process(job, options: options)
        return job
    }

    func testDefaultSavesCopyAndKeepsOriginal() async throws {
        let before = try FileManager.default.attributesOfItem(atPath: sample.path)[.size] as! Int
        let job = await run(ProcessingOptions())
        guard case .done(let output, _, let removed, false) = job.stage else { return XCTFail("stage: \(job.stage)") }
        XCTAssertTrue(output.lastPathComponent.contains("(no ads)"))
        XCTAssertGreaterThan(removed, 30)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: sample.path)[.size] as! Int, before)
    }

    func testReplaceOriginalKeepsNameAndShrinksFile() async throws {
        let before = try FileManager.default.attributesOfItem(atPath: sample.path)[.size] as! Int
        var o = ProcessingOptions(); o.replaceOriginal = true
        let job = await run(o)
        guard case .done(let output, _, _, true) = job.stage else { return XCTFail("stage: \(job.stage)") }
        XCTAssertEqual(output.standardizedFileURL.path, sample.standardizedFileURL.path)
        XCTAssertLessThan(try FileManager.default.attributesOfItem(atPath: sample.path)[.size] as! Int, before)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: sample.deletingLastPathComponent().path)
        XCTAssertEqual(leftovers, [sample.lastPathComponent])
    }

    func testCustomDetectionSettingsReachComskip() async throws {
        // With the defaults the 62s break is removed; forcing a 200s minimum break must change comskip's answer.
        var o = ProcessingOptions(); o.customDetection = true; o.minCommercialBreak = 200
        let job = await run(o)
        if case .done(_, _, let removed, _) = job.stage {
            XCTAssertGreaterThan(abs(removed - 62), 5, "custom settings had no effect")
        } else if job.stage != .noCommercials {
            XCTFail("stage: \(job.stage)")
        }
    }
}

/// COMBEGONE_CREDITS_SAMPLE: a recording ending show → ad break → short credits.
@MainActor
final class KeepEndIntegrationTests: XCTestCase {
    func testKeepLastSecondsSavesCredits() async throws {
        guard let path = ProcessInfo.processInfo.environment["COMBEGONE_CREDITS_SAMPLE"] else { throw XCTSkip("no sample") }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bin = root.appendingPathComponent("vendor/bin")
        let tools = ToolPaths(comskip: bin.appendingPathComponent("comskip"), ffmpeg: bin.appendingPathComponent("ffmpeg"),
                              ffprobe: bin.appendingPathComponent("ffprobe"),
                              defaultIni: root.appendingPathComponent("Resources/comskip.ini"))
        func removed(_ o: ProcessingOptions) async throws -> Double {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cg-ke-\(UUID())")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let copy = dir.appendingPathComponent("Ending.ts")
            try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: copy)
            let job = Job(input: copy)
            await Pipeline(tools: tools).process(job, options: o)
            guard case .done(_, _, let r, _) = job.stage else { XCTFail("stage \(job.stage)"); return 0 }
            return r
        }
        let plain = try await removed(ProcessingOptions())
        var keep = ProcessingOptions(); keep.keepLastSeconds = 45
        let kept = try await removed(keep)
        print("REMOVED default=\(plain) keepLast120=\(kept)")
        XCTAssertLessThan(kept, plain - 35, "credits should survive with keepLastSeconds")
        XCTAssertGreaterThan(kept, 55, "the ads must still be removed")
    }
}
