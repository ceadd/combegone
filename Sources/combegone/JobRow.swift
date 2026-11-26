import SwiftUI
import CombegoneCore

struct JobRow: View {
    @EnvironmentObject var queue: JobQueue
    @ObservedObject var job: Job
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: icon).foregroundStyle(iconColor)
                Text(job.input.lastPathComponent)
                    .lineLimit(1).truncationMode(.middle)
                    .font(.body.weight(.medium))
                Spacer()
                actions
            }
            switch job.stage {
            case .detecting, .cutting:
                ProgressView(value: job.progress) { Text(status).font(.caption).foregroundStyle(.secondary) }
            default:
                Text(status).font(.caption).foregroundStyle(job.stage.isFailure ? .red : .secondary)
            }
            if case .failed = job.stage {
                DisclosureGroup("Details", isExpanded: $showDetails) {
                    ScrollView {
                        Text(job.log.suffix(200).joined(separator: "\n"))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 140)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var actions: some View {
        switch job.stage {
        case .done(let output, _, _, _):
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([output]) }
        case .detecting, .cutting, .waiting:
            Button("Cancel") { queue.cancel(job) }
        default:
            Button { queue.remove(job) } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("Remove from list")
        }
    }

    private var status: String {
        switch job.stage {
        case .waiting: return "Waiting"
        case .detecting: return "Finding commercials… \(Int(job.progress * 100))%"
        case .cutting: return "Cutting… \(Int(job.progress * 100))%"
        case .done(_, let breaks, let removed, let replaced):
            return "Done — \(breaks) break\(breaks == 1 ? "" : "s"), \(Self.duration(removed)) removed"
                + (replaced ? " · original replaced" : "")
        case .noCommercials: return "No commercials found — nothing to cut"
        case .failed(let msg): return "Failed: \(msg)"
        case .cancelled: return "Cancelled"
        }
    }

    private var icon: String {
        switch job.stage {
        case .done: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .noCommercials: return "info.circle"
        case .cancelled: return "xmark.circle"
        case .waiting: return "clock"
        default: return "film"
        }
    }

    private var iconColor: Color {
        switch job.stage {
        case .done: return .green
        case .failed: return .red
        default: return .secondary
        }
    }

    static func duration(_ s: Double) -> String {
        let m = Int((s / 60).rounded())
        return m >= 1 ? "\(m) min" : "\(Int(s)) sec"
    }
}

extension JobStage {
    var isFailure: Bool { if case .failed = self { return true }; return false }
}
