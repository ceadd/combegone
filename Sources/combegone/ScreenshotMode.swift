import AppKit
import SwiftUI
import CombegoneCore

/// Developer tool for the README images: `scripts/screenshots.sh` launches the app with
/// COMBEGONE_SCREENSHOTS=<dir> and COMBEGONE_DEMO_FILES=<a:b:c>. The app then photographs its
/// own windows (no Screen Recording permission needed) and quits. Inactive otherwise.
@MainActor
enum ScreenshotMode {
    static var outputDir: URL? {
        ProcessInfo.processInfo.environment["COMBEGONE_SCREENSHOTS"].map { URL(fileURLWithPath: $0) }
    }

    static func run(queue: JobQueue, openWindow: OpenWindowAction, openSettings: OpenSettingsAction) {
        guard let dir = outputDir else { return }
        let files = (ProcessInfo.processInfo.environment["COMBEGONE_DEMO_FILES"] ?? "")
            .split(separator: ":").map { URL(fileURLWithPath: String($0)) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        Task { @MainActor in
            NSApp.appearance = NSAppearance(named: .aqua)
            await pause(1.5)
            snap(title: "ComBeGone", to: dir.appendingPathComponent("main-empty.png"))

            queue.add(files)
            // Wait until at least one file is finished and another is part-way through.
            for _ in 0..<600 {
                let done = queue.jobs.contains { if case .done = $0.stage { return true }; return false }
                let busy = queue.jobs.contains { ($0.stage == .detecting || $0.stage == .cutting) && $0.progress > 0.25 }
                if done && busy { break }
                await pause(0.25)
            }
            snap(title: "ComBeGone", to: dir.appendingPathComponent("main-working.png"))

            UserDefaults.standard.set(1, forKey: "com_apple_SwiftUI_Settings_selectedTabIndex")
            openSettings()
            await pause(1.5)
            snap(titlePrefix: "Detection", to: dir.appendingPathComponent("settings-detection.png"))

            UserDefaults.standard.set(0, forKey: "com_apple_SwiftUI_Settings_selectedTabIndex")
            NSApp.windows.first { $0.title.hasPrefix("Detection") }?.close()
            await pause(0.5)
            openSettings()
            await pause(1.5)
            snap(titlePrefix: "General", to: dir.appendingPathComponent("settings-general.png"))

            openWindow(id: "about")
            await pause(1.5)
            snap(title: "About ComBeGone", to: dir.appendingPathComponent("about.png"))

            for job in queue.jobs { queue.cancel(job) }
            await pause(0.5)
            NSApp.terminate(nil)
        }
    }

    private static func pause(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1e9)) }

    private static func snap(title: String? = nil, titlePrefix: String? = nil, to url: URL) {
        guard let window = NSApp.windows.first(where: { w in
            if let title { return w.title == title }
            if let titlePrefix { return w.title.hasPrefix(titlePrefix) }
            return false
        }) else {
            print("screenshot: no window for \(title ?? titlePrefix ?? ""); have \(NSApp.windows.map(\.title))"); return
        }
        // The frame view includes the title bar and toolbar, not just the content.
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("screenshot: \(url.lastPathComponent)")
    }
}
