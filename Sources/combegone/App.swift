import SwiftUI
import CombegoneCore

@main
struct CombegoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var queue = JobQueue()
    @Environment(\.openWindow) private var openWindow

    init() {
        // When launched outside a .app bundle (swift run), still behave like a normal app.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("combegone", id: "main") {
            ContentView()
                .environmentObject(queue)
                .frame(minWidth: 560, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About combegone") { openWindow(id: "about") }
            }
            CommandGroup(replacing: .newItem) {}
        }

        Window("About combegone", id: "about") {
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
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
