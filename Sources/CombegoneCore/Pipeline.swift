import Foundation

/// comskip → EDL → ffmpeg stream-copy cut, the same idea as the `comcut` script.
public struct Pipeline: Sendable {
    public var tools: ToolPaths
    public init(tools: ToolPaths) { self.tools = tools }

    @MainActor
    public func process(_ job: Job, options: ProcessingOptions = ProcessingOptions()) async {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("combegone-\(job.id.uuidString)")
        defer { try? fm.removeItem(at: work) }

        do {
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            guard fm.isReadableFile(atPath: job.input.path) else { throw ProcessError(message: "Can't read the file.") }

            // 1. Length of the recording.
            job.stage = .detecting
            job.progress = 0
            let duration = try await probeDuration(job)

            // 2. Find the commercials.
            let ini = work.appendingPathComponent("comskip.ini")
            let iniSource = tools.iniSource(useUserIni: options.useUserIni)
            let base = (try? String(contentsOf: iniSource, encoding: .utf8))
                ?? (try? String(contentsOf: iniSource, encoding: .isoLatin1)) ?? ""
            try Tools.iniContents(base: base, overrides: options.iniOverrides).write(to: ini, atomically: true, encoding: .utf8)

            let code = try await run(job, tools.comskip,
                                     Tools.comskipArgs(input: job.input, ini: ini, outputDir: work)) { line in
                if let t = Self.leadingTimestamp(line), duration > 0 { job.progress = min(t / duration, 1) }
            }
            try Task.checkCancellation()
            let edlURL = work.appendingPathComponent(job.input.deletingPathExtension().lastPathComponent + ".edl")
            guard let edlText = try? String(contentsOf: edlURL, encoding: .utf8) else {
                // comskip exits 1 when it finds nothing; it may skip writing the EDL then.
                if code == 0 || code == 1 { job.stage = .noCommercials; return }
                throw ProcessError(message: "Commercial detection failed (comskip exit \(code)).")
            }
            let cuts = Segments.protect(cuts: EDL.parse(edlText), duration: duration,
                                        keepFirst: Double(options.keepFirstSeconds),
                                        keepLast: Double(options.keepLastSeconds))
            let keep = Segments.keep(cuts: cuts, duration: duration)
            guard !cuts.isEmpty, keep != [TimeRange(start: 0, end: duration)] else { job.stage = .noCommercials; return }
            guard !keep.isEmpty else { throw ProcessError(message: "The whole recording was detected as commercials, so nothing was saved.") }

            // 3. Copy out the parts to keep, then join them.
            job.stage = .cutting
            job.progress = 0
            let ext = job.input.pathExtension.isEmpty ? "ts" : job.input.pathExtension
            let total = keep.reduce(0) { $0 + $1.length }
            var doneSeconds = 0.0
            var parts: [URL] = []
            for (i, seg) in keep.enumerated() {
                let part = work.appendingPathComponent("part\(i).\(ext)")
                let c = try await run(job, tools.ffmpeg, Tools.segmentArgs(input: job.input, segment: seg, output: part)) { line in
                    if let t = Self.ffmpegTime(line) { job.progress = min((doneSeconds + t) / total, 1) * 0.95 }
                }
                try Task.checkCancellation()
                guard c == 0 else { throw ProcessError(message: "Cutting failed (ffmpeg exit \(c)).") }
                doneSeconds += seg.length
                parts.append(part)
            }

            let list = work.appendingPathComponent("list.txt")
            try Tools.concatList(parts: parts).write(to: list, atomically: true, encoding: .utf8)
            // Join into a hidden file in the same folder, so the final rename/replace is instant and on the same disk.
            let tmpOut = job.input.deletingLastPathComponent()
                .appendingPathComponent(".\(job.input.deletingPathExtension().lastPathComponent).combegone-\(job.id.uuidString.prefix(8)).\(ext)")
            defer { try? fm.removeItem(at: tmpOut) }
            let j = try await run(job, tools.ffmpeg, Tools.joinArgs(concatList: list, output: tmpOut)) { _ in }
            try Task.checkCancellation()
            guard j == 0 else { throw ProcessError(message: "Joining failed (ffmpeg exit \(j)).") }

            // Sanity-check the result before it takes the original's place.
            let newDuration = try await probeDuration(job, tmpOut)
            guard newDuration > total * 0.9 else {
                throw ProcessError(message: "The cut file came out shorter than expected, so it wasn't saved.")
            }

            let output: URL
            if options.replaceOriginal {
                output = try fm.replaceItemAt(job.input, withItemAt: tmpOut) ?? job.input
            } else {
                output = OutputNaming.outputURL(for: job.input)
                try fm.moveItem(at: tmpOut, to: output)
            }

            job.progress = 1
            job.stage = .done(output: output, breaks: cuts.count,
                              removedSeconds: Segments.removedSeconds(keep: keep, duration: duration),
                              replacedOriginal: options.replaceOriginal)
        } catch is CancellationError {
            job.stage = .cancelled
        } catch {
            job.stage = Task.isCancelled ? .cancelled : .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func probeDuration(_ job: Job, _ file: URL? = nil) async throws -> Double {
        var out = ""
        let code = try await run(job, tools.ffprobe, Tools.probeDurationArgs(input: file ?? job.input)) { out = $0 }
        guard code == 0, let d = Double(out.trimmingCharacters(in: .whitespaces)), d > 0 else {
            throw ProcessError(message: "This doesn't look like a video file ffmpeg can read.")
        }
        return d
    }

    @MainActor
    private func run(_ job: Job, _ exe: URL, _ args: [String],
                     onLine: @escaping @MainActor (String) -> Void) async throws -> Int32 {
        job.append("$ \(exe.lastPathComponent) \(args.joined(separator: " "))")
        let code = try await ProcessRunner().run(exe, args) { line in
            Task { @MainActor in job.append(line); onLine(line) }
        }
        try Task.checkCancellation()
        return code
    }

    /// comskip progress lines start with the position, e.g. "0:12:34.56 - 18842 frames ..."
    static func leadingTimestamp(_ line: String) -> Double? {
        let token = line.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
        return parseClock(token)
    }

    /// ffmpeg stats lines contain "time=00:01:02.34".
    static func ffmpegTime(_ line: String) -> Double? {
        guard let r = line.range(of: "time=") else { return nil }
        let token = line[r.upperBound...].split(separator: " ").first.map(String.init) ?? ""
        return parseClock(token)
    }

    static func parseClock(_ s: String) -> Double? {
        let parts = s.split(separator: ":")
        guard parts.count == 3, let h = Double(parts[0]), let m = Double(parts[1]), let sec = Double(parts[2]) else { return nil }
        return h * 3600 + m * 60 + sec
    }
}
