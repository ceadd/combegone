import SwiftUI
import CombegoneCore

@main
struct CombegoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var queue = JobQueue()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    init() {
        // When launched outside a .app bundle (swift run), still behave like a normal app.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("ComBeGone", id: "main") {
            ContentView()
                .environmentObject(queue)
                .frame(minWidth: 560, minHeight: 420)
                .onAppear {
                    appDelegate.attach { [queue] urls in queue.add(urls) }
                    ScreenshotMode.run(queue: queue, openWindow: openWindow, openSettings: openSettings)
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ComBeGone") { openWindow(id: "about") }
            }
            CommandGroup(replacing: .newItem) {}
        }

        Window("About ComBeGone", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var handler: (([URL]) -> Void)?
    private var pending: [URL] = []

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Files dropped on the Dock icon or opened with "Open With → ComBeGone".
    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter { $0.isFileURL }
        if let handler { handler(files) } else { pending += files }
    }

    func attach(_ handler: @escaping ([URL]) -> Void) {
        self.handler = handler
        if !pending.isEmpty { handler(pending); pending = [] }
    }
}
