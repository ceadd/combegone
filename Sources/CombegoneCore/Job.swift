import Foundation

public enum JobStage: Equatable, Sendable {
    case waiting
    case detecting
    case cutting
    case done(output: URL, breaks: Int, removedSeconds: Double, replacedOriginal: Bool)
    case noCommercials
    case failed(String)
    case cancelled

    public var isFinished: Bool {
        switch self {
        case .waiting, .detecting, .cutting: return false
        default: return true
        }
    }
}

@MainActor
public final class Job: ObservableObject, Identifiable {
    public let id = UUID()
    public let input: URL
    @Published public var stage: JobStage = .waiting
    @Published public var progress: Double = 0
    @Published public private(set) var log: [String] = []

    public init(input: URL) { self.input = input }

    func append(_ line: String) {
        log.append(line)
        if log.count > 2000 { log.removeFirst(log.count - 2000) }
    }
}

/// Processes dropped files one at a time.
@MainActor
public final class JobQueue: ObservableObject {
    @Published public private(set) var jobs: [Job] = []
    private let pipeline: Pipeline
    private let options: () -> ProcessingOptions
    private var current: (job: Job, task: Task<Void, Never>)?

    public init(pipeline: Pipeline = Pipeline(tools: .bundled()),
                options: @escaping () -> ProcessingOptions = { .load() }) {
        self.pipeline = pipeline
        self.options = options
    }

    public func add(_ urls: [URL]) {
        let existing = Set(jobs.filter { !$0.stage.isFinished }.map(\.input))
        for url in urls where !existing.contains(url) { jobs.append(Job(input: url)) }
        startNext()
    }

    public func cancel(_ job: Job) {
        if current?.job === job { current?.task.cancel() }
        else if job.stage == .waiting { job.stage = .cancelled }
    }

    public func remove(_ job: Job) {
        cancel(job)
        jobs.removeAll { $0 === job }
    }

    public func clearFinished() { jobs.removeAll { $0.stage.isFinished } }

    public var isBusy: Bool { current != nil }

    private func startNext() {
        guard current == nil, let next = jobs.first(where: { $0.stage == .waiting }) else { return }
        let opts = options() // settings are read when each file starts
        let task = Task { [pipeline] in
            await pipeline.process(next, options: opts)
            self.current = nil
            self.startNext()
        }
        current = (next, task)
    }
}
