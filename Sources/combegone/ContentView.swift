import SwiftUI
import UniformTypeIdentifiers
import CombegoneCore

struct ContentView: View {
    @EnvironmentObject var queue: JobQueue
    @State private var isTargeted = false
    @State private var showImporter = false
    @AppStorage(ProcessingOptions.Key.replaceOriginal) private var replaceOriginal = false

    var body: some View {
        VStack(spacing: 0) {
            dropZone
                .padding(20)

            if !queue.jobs.isEmpty {
                Divider()
                List {
                    ForEach(queue.jobs) { job in
                        JobRow(job: job)
                    }
                }
                .listStyle(.inset)
                HStack {
                    Spacer()
                    Button("Clear Finished") { queue.clearFinished() }
                        .disabled(!queue.jobs.contains { $0.stage.isFinished })
                }
                .padding(10)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings")
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.movie, .audiovisualContent, .data],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { queue.add(urls) }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "scissors")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drop recordings here")
                .font(.title3.weight(.medium))
            Button("Choose Files…") { showImporter = true }
                .controlSize(.large)
            Text(replaceOriginal ? "Originals are replaced with the cut version (change in Settings)."
                                 : "A copy without commercials is saved next to each original.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: queue.jobs.isEmpty ? 300 : 150)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
                .background(RoundedRectangle(cornerRadius: 14).fill(isTargeted ? Color.accentColor.opacity(0.08) : .clear))
        )
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter { $0.isFileURL && !$0.hasDirectoryPath }
            queue.add(files)
            return !files.isEmpty
        } isTargeted: { isTargeted = $0 }
    }
}
