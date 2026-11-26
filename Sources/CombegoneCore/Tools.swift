import Foundation

/// Locations of the tools bundled inside combegone.app.
public struct ToolPaths: Sendable {
    public var comskip: URL
    public var ffmpeg: URL
    public var ffprobe: URL
    public var defaultIni: URL

    public init(comskip: URL, ffmpeg: URL, ffprobe: URL, defaultIni: URL) {
        self.comskip = comskip; self.ffmpeg = ffmpeg; self.ffprobe = ffprobe; self.defaultIni = defaultIni
    }

    public static func bundled(_ bundle: Bundle = .main) -> ToolPaths {
        let res = bundle.resourceURL ?? bundle.bundleURL
        let bin = res.appendingPathComponent("bin")
        return ToolPaths(comskip: bin.appendingPathComponent("comskip"),
                         ffmpeg: bin.appendingPathComponent("ffmpeg"),
                         ffprobe: bin.appendingPathComponent("ffprobe"),
                         defaultIni: res.appendingPathComponent("comskip.ini"))
    }

    /// `~/.comskip.ini` if the user has one, otherwise the bundled default.
    public func iniSource(useUserIni: Bool = true) -> URL {
        guard useUserIni else { return defaultIni }
        let user = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".comskip.ini")
        return FileManager.default.fileExists(atPath: user.path) ? user : defaultIni
    }
}

public enum Tools {
    public static func comskipArgs(input: URL, ini: URL, outputDir: URL) -> [String] {
        ["--ini=\(ini.path)", "--output=\(outputDir.path)", input.path]
    }

    /// The ini we hand comskip. comskip takes the FIRST occurrence of each setting
    /// (it uses strstr on the whole file), so overrides and `output_edl=1` go on top.
    public static func iniContents(base: String, overrides: [String] = []) -> String {
        (overrides + ["output_edl=1"]).map { $0 + "\n" }.joined() + base
    }

    /// Copies one kept piece out of the recording without re-encoding.
    public static func segmentArgs(input: URL, segment: TimeRange, output: URL) -> [String] {
        ["-nostdin", "-hide_banner", "-y",
         "-ss", fmt(segment.start), "-i", input.path,
         "-t", fmt(segment.length),
         "-map", "0:v?", "-map", "0:a?", "-map", "0:s?",
         "-c", "copy", "-avoid_negative_ts", "make_zero",
         output.path]
    }

    /// Input list for ffmpeg's concat demuxer.
    public static func concatList(parts: [URL]) -> String {
        parts.map { "file '\($0.path.replacingOccurrences(of: "'", with: "'\\''"))'\n" }.joined()
    }

    public static func joinArgs(concatList: URL, output: URL) -> [String] {
        ["-nostdin", "-hide_banner", "-y", "-f", "concat", "-safe", "0",
         "-i", concatList.path, "-map", "0", "-c", "copy", output.path]
    }

    public static func probeDurationArgs(input: URL) -> [String] {
        ["-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", input.path]
    }

    static func fmt(_ t: Double) -> String { String(format: "%.3f", t) }
}
