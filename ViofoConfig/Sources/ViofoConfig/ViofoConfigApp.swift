import SwiftUI
import AppKit

struct ViofoConfigApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var document = ConfigDocument()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(document)
                .frame(minWidth: 940, minHeight: 620)
        }
        // The camera is a separate window: the file is whatever the last
        // requested export wrote, the camera is live, and conflating the two
        // would be misleading.
        Window("Camera", id: "camera") {
            CameraView()
        }
        .keyboardShortcut("k")

        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .newItem) {
                Button("Open…") { FileActions.open(into: document) }
                    .keyboardShortcut("o")
                Divider()
                Button("Save") { FileActions.save(document) }
                    .keyboardShortcut("s")
                    .disabled(document.fileURL == nil)
                Button("Save As…") { FileActions.saveAs(document) }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("Export Explanation…") { FileActions.exportReport(document) }
                    .keyboardShortcut("e")
                    .disabled(document.fileURL == nil)
                Button("Revert All Changes") { document.revertAll() }
                    .disabled(!document.isModified)
            }
            CommandGroup(after: .toolbar) {
                OpenCameraButton()
            }
        }
    }
}

/// Opens the camera window.
///
/// This needs `openWindow` from the environment, which means it has to be a
/// view rather than a bare closure in the command group. It used to open a
/// `viofoconfig://camera` URL, but that scheme was never registered, so the
/// menu item only ever produced "There is no application set to open the URL".
private struct OpenCameraButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        // No shortcut here: the Window scene already puts ⌘K on its own
        // "Camera" item, and a second one would collide.
        Button("Camera Over Wi-Fi…") { openWindow(id: "camera") }
    }
}

/// Files handed over at launch, before any view exists to receive them.
enum Launch {
    nonisolated(unsafe) static var initialURL: URL?
    static let openRequest = Notification.Name("ViofoConfig.openRequest")
}

/// Running the binary straight from `swift run` gives a process with no bundle,
/// which AppKit leaves as a background app. Force it forward so the window shows.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Double-clicking a viofo_config.ini, or dropping one on the icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        NotificationCenter.default.post(name: Launch.openRequest, object: url)
    }
}
