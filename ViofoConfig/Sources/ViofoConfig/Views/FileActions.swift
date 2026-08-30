import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
enum FileActions {

    static var lastError: String?

    static func open(into document: ConfigDocument) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "ini") ?? .plainText, .plainText, .data]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.message = "Choose viofo_config.ini, normally in the root of the camera's card."
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url, into: document)
    }

    static func load(_ url: URL, into document: ConfigDocument) {
        do {
            try document.load(from: url)
            remember(url)
        } catch {
            present(error.localizedDescription)
        }
    }

    static func save(_ document: ConfigDocument) {
        guard document.fileURL != nil else { return saveAs(document) }
        do { try document.save() } catch { present(error.localizedDescription) }
    }

    static func saveAs(_ document: ConfigDocument) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = document.fileURL?.lastPathComponent ?? "viofo_config.ini"
        panel.allowedContentTypes = [UTType(filenameExtension: "ini") ?? .plainText]
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try document.save(to: url) } catch { present(error.localizedDescription) }
    }

    static func exportReport(_ document: ConfigDocument) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "viofo-settings-explained.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Digest.markdownReport(document).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            present(error.localizedDescription)
        }
    }

    /// Cards mount under /Volumes, so look there for an exported config: at the
    /// root, where the camera writes it, and one directory down, where it tends
    /// to end up once it has been filed away.
    static func discoverCards() -> [URL] {
        let fm = FileManager.default
        var found: [URL] = []

        func consider(_ url: URL) {
            guard fm.fileExists(atPath: url.path), !found.contains(url) else { return }
            found.append(url)
        }

        for volume in (try? fm.contentsOfDirectory(atPath: "/Volumes")) ?? [] {
            let root = URL(fileURLWithPath: "/Volumes").appendingPathComponent(volume)
            consider(root.appendingPathComponent(name))
            let children = (try? fm.contentsOfDirectory(at: root,
                                                       includingPropertiesForKeys: [.isDirectoryKey],
                                                       options: [.skipsHiddenFiles])) ?? []
            for child in children where (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                consider(child.appendingPathComponent(name))
            }
        }

        consider(URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(name))
        return found
    }

    private static let name = "viofo_config.ini"

    // MARK: - Recents

    private static let recentsKey = "recentConfigPaths"

    static var recents: [URL] {
        (UserDefaults.standard.stringArray(forKey: recentsKey) ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func remember(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        UserDefaults.standard.set(Array(paths.prefix(8)), forKey: recentsKey)
    }

    private static func present(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Something went wrong"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

extension ConfigDocument {

    func intBinding(_ key: String, fallback: Int = 0) -> Binding<Int> {
        Binding(
            get: { self.intValue(for: key) ?? fallback },
            set: { self.setInt($0, for: key) }
        )
    }

    func textBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { ConfigDocument.unquote(self.value(for: key) ?? "") },
            set: { self.setQuoted($0, for: key) }
        )
    }

    func isChanged(_ key: String) -> Bool {
        guard let now = value(for: key), let then = original[key] else { return false }
        return now != then
    }
}
