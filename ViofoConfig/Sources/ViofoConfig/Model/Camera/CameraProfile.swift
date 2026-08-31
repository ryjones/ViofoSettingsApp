import Foundation

/// A snapshot of the camera's live settings, as JSON, for editing and writing
/// back over HTTP.
///
/// This deliberately replaces the `viofo_config.ini` route. That file is written
/// only when an export is requested on the device, the camera never reads it
/// back, and on this firmware the request cannot be made over the network at
/// all: `cmd=3021` calls the export routine but it refuses while the camera is
/// in its recording mode, and `cmd=8230` reboots. A profile taken from
/// `cmd=3014` has none of those problems — it is the live state, and every value
/// in it can be written back with `?custom=1&cmd=<n>&par=<v>`.
struct CameraProfile: Codable {

    struct Entry: Codable {
        let cmd: Int
        let key: String
        let title: String
        let settingID: Int?
        let iniKey: String?
        /// The raw value the camera reports, and what a write must send.
        var value: String
        /// The decoded value where a label list exists — for the reader, not
        /// for the parser. Editing this has no effect; edit `value`.
        let label: String?
        /// False when this entry cannot be written back. See `note`.
        let writable: Bool
        let note: String?

        enum CodingKeys: String, CodingKey {
            case cmd, key, title, settingID = "setting_id", iniKey = "ini_key"
            case value, label, writable, note
        }
    }

    let model: String
    let firmware: String
    let host: String
    let captured: Date
    var settings: [Entry]

    // MARK: - Why an entry may be read-only

    /// Commands that answer with several channels at once — 8220 returns
    /// exposure as "6,6,6" for front/interior/rear, 8222 resolution as "2,7".
    /// A single `par=` cannot express that, and how the firmware splits the
    /// value has not been established, so these are exported for reference and
    /// refused on write rather than guessed at.
    static func multiChannel(_ value: String) -> Bool { value.contains(",") }

    static func readOnlyNote(cmd: Int, value: String) -> String? {
        if CameraProtocol.destructive.contains(cmd) { return "destructive; never written" }
        if CameraCommandCatalog.isCautioned(cmd) { return "gated; write only with --allow-caution" }
        if multiChannel(value) { return "multi-channel value; par= cannot express it" }
        return nil
    }

    // MARK: - Capture

    static func capture(settings live: [CameraClient.LiveSetting],
                        model: String,
                        firmware: String,
                        host: String,
                        now: Date = Date()) -> CameraProfile {
        let entries = live.map { s -> Entry in
            let note = readOnlyNote(cmd: s.cmd, value: s.value)
            let decoded = s.command?.label(for: s.value)
            return Entry(cmd: s.cmd,
                         key: s.command?.key ?? "SETTING_\(s.cmd)",
                         title: s.title,
                         settingID: s.command?.settingID,
                         iniKey: s.command?.iniKeys?.first,
                         value: s.value,
                         label: decoded == s.value ? nil : decoded,
                         writable: note == nil,
                         note: note)
        }
        return CameraProfile(model: model, firmware: firmware, host: host,
                             captured: now, settings: entries)
    }

    // MARK: - Serialisation

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func json() throws -> String {
        String(decoding: try Self.encoder().encode(self), as: UTF8.self)
    }

    static func load(_ data: Data) throws -> CameraProfile {
        try decoder().decode(CameraProfile.self, from: data)
    }

    // MARK: - Planning a write

    struct Change: Equatable {
        let cmd: Int
        let title: String
        let from: String
        let to: String
    }

    enum Skip: Equatable {
        case notASetting, readOnly(String), unchanged, notInteger(String)
    }

    struct Plan {
        var changes: [Change] = []
        var skipped: [(cmd: Int, title: String, why: Skip)] = []
        var isEmpty: Bool { changes.isEmpty }
    }

    /// Works out what would have to be written to make `live` match this
    /// profile. Never contacts the camera.
    func plan(against live: [Int: String], allowCaution: Bool = false) -> Plan {
        var plan = Plan()
        for entry in settings {
            guard let current = live[entry.cmd] else {
                plan.skipped.append((entry.cmd, entry.title, .notASetting)); continue
            }
            guard current != entry.value else {
                plan.skipped.append((entry.cmd, entry.title, .unchanged)); continue
            }
            // A profile is a file the user edits, so re-derive the refusal here
            // rather than trusting the `writable` flag it carries.
            if CameraProtocol.destructive.contains(entry.cmd) {
                plan.skipped.append((entry.cmd, entry.title, .readOnly("destructive"))); continue
            }
            if CameraCommandCatalog.isCautioned(entry.cmd), !allowCaution {
                plan.skipped.append((entry.cmd, entry.title, .readOnly("gated; needs --allow-caution"))); continue
            }
            if Self.multiChannel(entry.value) || Self.multiChannel(current) {
                plan.skipped.append((entry.cmd, entry.title, .readOnly("multi-channel"))); continue
            }
            guard Int(entry.value) != nil else {
                plan.skipped.append((entry.cmd, entry.title, .notInteger(entry.value))); continue
            }
            plan.changes.append(Change(cmd: entry.cmd, title: entry.title,
                                       from: current, to: entry.value))
        }
        return plan
    }
}
