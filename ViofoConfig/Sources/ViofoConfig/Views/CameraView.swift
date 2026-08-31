import SwiftUI

/// Live settings, read from and written to the camera over Wi-Fi.
struct CameraView: View {
    @StateObject private var client = CameraClient()
    @State private var showUnknown = false
    /// Edits staged but not yet written. Changing a picker, or loading a saved
    /// file, lands here; nothing reaches the camera until Apply. Writes can stop
    /// recording, so batching them keeps that to one interruption.
    @State private var edits: [Int: Int] = [:]
    /// Settings written to the camera during this session.
    @State private var applied: Set<Int> = []
    /// What the last save to a file recorded, so a row can say whether the value
    /// it is showing now is the one on disk.
    @State private var savedValues: [Int: String] = [:]
    /// Which row's caution note is open. `.help()` alone was not enough: a
    /// tooltip on a bare Image inside a List row never gets a tracking area, so
    /// nothing appeared on hover, and the note is a paragraph -- too much for a
    /// tooltip even where one works.
    @State private var cautionFor: Int?
    /// A profile chosen for applying, held until the plan has been confirmed.
    @State private var confirming = false
    @State private var applying = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch client.state {
            case .idle, .connecting, .failed:
                placeholder
            case .connected:
                settingsList
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .confirmationDialog("Apply these changes to the camera?",
                            isPresented: $confirming, titleVisibility: .visible) {
            Button("Write \(edits.count) setting" + (edits.count == 1 ? "" : "s")) { applyEdits() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(editSummary())
        }
    }

    // MARK: - Profiles

    private func profile() -> CameraProfile {
        let firmware: String
        if case .connected(let f) = client.state { firmware = f } else { firmware = "unknown" }
        return CameraProfile.capture(settings: client.settings,
                                     model: CameraCommandCatalog.model,
                                     firmware: firmware,
                                     host: client.host.absoluteString)
    }

    /// Loading a file stages its differences; it does not write. The same Apply
    /// button then covers both hand edits and a loaded file.
    private func loadProfile() {
        guard let loaded = FileActions.openProfile() else { return }
        let live = Dictionary(client.settings.map { ($0.cmd, $0.value) },
                              uniquingKeysWith: { a, _ in a })
        for change in loaded.plan(against: live).changes {
            if let v = Int(change.to) { edits[change.cmd] = v }
        }
    }

    /// What a row should show: the staged value if there is one, else the
    /// camera's.
    private func shownValue(_ setting: CameraClient.LiveSetting) -> String {
        edits[setting.cmd].map(String.init) ?? setting.value
    }

    private func editSummary() -> String {
        let lines = edits.sorted { $0.key < $1.key }.prefix(12).map { cmd, value -> String in
            let command = CameraCommandCatalog.command(cmd)
            let from = client.settings.first { $0.cmd == cmd }?.value ?? "?"
            let to = String(value)
            return "\(command?.title ?? "cmd \(cmd)"): "
                 + "\(command?.label(for: from) ?? from) → \(command?.label(for: to) ?? to)"
        }
        let rest = edits.count - lines.count
        return lines.joined(separator: "\n") + (rest > 0 ? "\n… and \(rest) more" : "")
    }

    private func applyEdits() {
        let changes = edits
        applying = true
        Task {
            let result = await client.apply(changes)
            // Keep anything the camera refused staged, so it is still visible.
            edits = edits.filter { result.failed.contains($0.key) }
            applied.formUnion(changes.keys.filter { !result.failed.contains($0) })
            applying = false
        }
    }

    /// The leading status column. Three things are worth distinguishing: a
    /// change that has not left the app, one written to the camera, and one that
    /// exists in a file on disk. They are not exclusive -- a value can be
    /// applied and then saved -- so the most recent state wins.
    @ViewBuilder
    private func statusMark(_ setting: CameraClient.LiveSetting) -> some View {
        if edits[setting.cmd] != nil {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.green)
                .help("Edited — not yet applied to the camera")
        } else if applied.contains(setting.cmd), savedValues[setting.cmd] != setting.value {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.blue)
                .help("Applied to the camera, not yet saved to a file")
        } else if savedValues[setting.cmd] == setting.value, !savedValues.isEmpty {
            Image(systemName: "doc.circle.fill")
                .foregroundStyle(.secondary)
                .help("Saved to a file")
        } else {
            Color.clear
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            switch client.state {
            case .connected(let firmware):
                Label(firmware, systemImage: "wifi")
                    .font(.system(.body, design: .monospaced))
                if client.retriedProbes > 0 {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(.orange)
                        .help("\(client.retriedProbes) request\(client.retriedProbes == 1 ? "" : "s") "
                              + "needed a retry. The link is flaky, so a write may not get through "
                              + "first time.")
                }
                Spacer()
                Toggle("Show unrecognised", isOn: $showUnknown)
                    .toggleStyle(.checkbox)
                    .help("List settings missing from the catalogue, and highlight every "
                          + "setting whose value the app cannot translate")
                Button("Save…") {
                    if FileActions.saveProfile(profile()) {
                        savedValues = Dictionary(client.settings.map { ($0.cmd, $0.value) },
                                                 uniquingKeysWith: { a, _ in a })
                    }
                }
                    .help("Save these settings to a file")
                    .disabled(applying)
                Button("Load…") { loadProfile() }
                    .help("Stage the settings in a saved file, ready to apply")
                    .disabled(applying)
                Button("Revert") { edits.removeAll() }
                    .disabled(edits.isEmpty || applying)
                Button(edits.isEmpty ? "Apply" : "Apply \(edits.count)") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(edits.isEmpty || applying)
                    .help("Write the staged changes to the camera")
                Button("Refresh") { Task { await client.refresh() } }
                    .disabled(!edits.isEmpty || applying)
                    .help(edits.isEmpty ? "Re-read the camera"
                          : "Revert or apply the staged changes first")
            default:
                Label("Not connected", systemImage: "wifi.slash").foregroundStyle(.secondary)
                Spacer()
                Button("Connect") { Task { await client.connect() } }
                    .disabled(client.state == .connecting)
            }
        }
        .padding(12)
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "wifi.router").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Connect to the camera's Wi-Fi").font(.headline)
            Text("""
                Turn the camera's Wi-Fi on, join its network from this Mac, then \
                press Connect. You will not have internet while joined — the \
                camera's access point has no uplink.
                """)
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
            if case .failed(let message) = client.state {
                Text(message).font(.callout).foregroundStyle(.red)
                    .multilineTextAlignment(.center).frame(maxWidth: 380)
            }
            Spacer()
        }
        .padding()
    }

    private var visible: [CameraClient.LiveSetting] {
        client.settings.filter { showUnknown || $0.isKnown }
    }

    /// True when the app can list the setting but not say what its value means:
    /// either it is absent from the catalogue, or it has no option labels, or it
    /// carries several channels at once ("6,6,6") and no single label applies.
    ///
    /// On this firmware nothing is absent from the catalogue, so filtering alone
    /// made the checkbox look broken -- it revealed nothing because there was
    /// nothing to reveal. Highlighting is what actually shows the gap: 93
    /// settings are named, but not all of them are understood.
    /// A staged edit outranks the undecoded highlight: it is the thing the user
    /// most needs to see before pressing Apply.
    private func rowTint(_ setting: CameraClient.LiveSetting) -> Color? {
        if edits[setting.cmd] != nil { return Color.green.opacity(0.20) }
        if showUnknown && isUndecoded(setting) { return Color.yellow.opacity(0.22) }
        return nil
    }

    private func isUndecoded(_ setting: CameraClient.LiveSetting) -> Bool {
        guard let command = setting.command else { return true }
        guard let options = command.options, !options.isEmpty else { return true }
        guard let value = Int(setting.value) else { return true }
        return !options.contains { $0.value == value }
    }

    private var settingsList: some View {
        List {
            if let error = client.lastError {
                Text(error).foregroundStyle(.red).font(.callout)
            }
            if client.pausingRecording {
                Label("Recording stopped so the camera will accept these settings — "
                      + "it ignores some of them while recording. Restarting after.",
                      systemImage: "pause.circle")
                    .font(.callout).foregroundStyle(.orange)
            }
            Section("\(visible.count) settings") {
                ForEach(visible) { setting in
                    row(setting)
                        .listRowBackground(rowTint(setting))
                }
            }
            if showUnknown {
                let undecoded = visible.filter(isUndecoded).count
                let missing = client.settings.filter { !$0.isKnown }.count
                Text("\(undecoded) highlighted: the camera reports a value the app cannot "
                     + "translate. \(missing) of those are not in the catalogue at all — on "
                     + "\(CameraCommandCatalog.firmwareObserved) that should be none, since the "
                     + "catalogue is generated from this firmware's own dispatch table. The rest "
                     + "are named but have no option labels, so their raw value is shown as-is.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    /// The provenance of a row: its command number, the firmware setting it maps
    /// to, and the `viofo_config.ini` key if the camera exports it under one.
    private func subtitle(_ setting: CameraClient.LiveSetting) -> String {
        var parts = ["cmd \(setting.cmd)"]
        if let id = setting.command?.settingID {
            parts.append(String(format: "setting 0x%02x", id))
        }
        if let ini = setting.command?.iniKeys?.first {
            parts.append(ini)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func row(_ setting: CameraClient.LiveSetting) -> some View {
        HStack {
            statusMark(setting)
                .frame(width: 17, height: 17)
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(setting.title)
                    if CameraCommandCatalog.isCautioned(setting.cmd) {
                        Button {
                            cautionFor = cautionFor == setting.cmd ? nil : setting.cmd
                        } label: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Why this one needs care")
                        .accessibilityLabel("Why this setting needs care")
                        .popover(isPresented: Binding(
                            get: { cautionFor == setting.cmd },
                            set: { if !$0 { cautionFor = nil } })) {
                                Text(CameraCommandCatalog.cautionNote ?? "")
                                    .font(.callout)
                                    .textSelection(.enabled)
                                    .frame(width: 340, alignment: .leading)
                                    .padding(14)
                            }
                    }
                }
                Text(subtitle(setting))
                    .font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            if applying && edits[setting.cmd] != nil {
                ProgressView().controlSize(.small)
            } else if let options = setting.command?.options, !options.isEmpty,
                      Int(setting.value) != nil {
                Picker("", selection: Binding(
                    get: { edits[setting.cmd] ?? Int(setting.value) ?? -1 },
                    set: { newValue in
                        // Staged, not sent. Choosing the camera's current value
                        // again is not an edit.
                        if String(newValue) == setting.value {
                            edits.removeValue(forKey: setting.cmd)
                        } else {
                            edits[setting.cmd] = newValue
                        }
                    })) {
                        ForEach(options, id: \.value) { Text($0.label).tag($0.value) }
                        if !options.contains(where: { $0.value == Int(setting.value) }) {
                            Text(setting.value).tag(Int(setting.value) ?? -1)
                        }
                    }
                    .labelsHidden().frame(width: 220)
            } else {
                Text(setting.value)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .padding(.vertical, 2)
    }
}
