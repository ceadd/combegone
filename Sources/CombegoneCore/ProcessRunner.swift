import Foundation

public struct ProcessError: Error, LocalizedError {
    public var message: String
    public var errorDescription: String? { message }
}

/// Runs a bundled tool with an argument array (never through a shell), streaming
/// stdout and stderr lines. Cancelling the Swift task terminates the child process.
public final class ProcessRunner: @unchecked Sendable {
    public init() {}

    public func run(_ executable: URL, _ arguments: [String],
                    onLine: @escaping (String) -> Void) async throws -> Int32 {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let lock = NSLock()
        var buffer = Data()
        func emit(_ data: Data, flush: Bool) {
            lock.lock(); defer { lock.unlock() }
            buffer.append(data)
            // ffmpeg/comskip use \r for in-place progress, so split on both.
            while let i = buffer.firstIndex(where: { $0 == 10 || $0 == 13 }) {
                let line = String(decoding: buffer[buffer.startIndex..<i], as: UTF8.self)
                buffer.removeSubrange(buffer.startIndex...i)
                if !line.isEmpty { onLine(line) }
            }
            if flush, !buffer.isEmpty {
                onLine(String(decoding: buffer, as: UTF8.self)); buffer.removeAll()
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Int32, Error>) in
                pipe.fileHandleForReading.readabilityHandler = { h in
                    let d = h.availableData
                    if d.isEmpty { h.readabilityHandler = nil } else { emit(d, flush: false) }
                }
                process.terminationHandler = { p in
                    pipe.fileHandleForReading.readabilityHandler = nil
                    emit(pipe.fileHandleForReading.readDataToEndOfFile(), flush: true)
                    cont.resume(returning: p.terminationStatus)
                }
                do {
                    try process.run()
                    if Task.isCancelled { process.terminate() }
                } catch {
                    process.terminationHandler = nil
                    cont.resume(throwing: ProcessError(message: "Couldn't start \(executable.lastPathComponent): \(error.localizedDescription)"))
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}
