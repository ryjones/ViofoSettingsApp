import Foundation

/// What each command number means, and which values it accepts.
///
/// The command set itself is read out of `cardv`'s HTTP dispatch table — see
/// docs/camera-http-api.md §5 and `tools/re/dump_api_table.py` in the firmware
/// project. This catalogue holds the 93 entries that are *settings* (those whose
/// table row carries a non-zero setting id), which is exactly what `cmd=3014`
/// reports back. The other 77 commands the camera accepts are actions and
/// getters; they live in `api-map.json` in the firmware project, not here.
///
/// Option labels are the one part still owed to VIOFO's own app database, which
/// describes 71 of the 93. The remaining 22 are named from the firmware but have
/// no label list, so they are shown read-only rather than given invented options.
struct CameraCommand: Decodable, Identifiable, Hashable {
    struct Option: Decodable, Hashable { let value: Int; let label: String }

    let cmd: Int
    let key: String
    /// Display name. Prefers the `viofo_config.ini` key where the setting is
    /// exported, else VIOFO's name, else the firmware handler's.
    let explicitTitle: String?
    /// The firmware setting id this command reads and writes — the same
    /// numbering `viofo_config.ini` and `firmware-schema.json` use.
    let settingID: Int?
    /// The matching key(s) in `viofo_config.ini`, where the setting is exported.
    let iniKeys: [String]?
    let section: String?
    let handler: String?
    /// Command numbers are not unique per setting. Some carry several channels
    /// at once and answer with a comma-separated value — 8220 returns exposure
    /// for front, interior and rear as "6,6,6".
    let aliases: [String]?
    let options: [Option]?

    enum CodingKeys: String, CodingKey {
        case cmd, key, settingID = "setting_id", explicitTitle = "title"
        case iniKeys = "ini_keys", section, handler, aliases, options
    }

    var carriesMultipleSettings: Bool { !(aliases ?? []).isEmpty }

    var id: Int { cmd }

    /// "CMD_SET_LOOP_REC" -> "Set Loop Rec"
    var title: String {
        if let explicitTitle, !explicitTitle.isEmpty { return explicitTitle }
        return key.replacingOccurrences(of: "CMD_", with: "")
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    func label(for value: String) -> String {
        if let n = Int(value), let match = options?.first(where: { $0.value == n }) {
            return match.label
        }
        return value
    }
}

enum CameraCommandCatalog {
    private struct File: Decodable {
        let model: String
        let firmwareObserved: String
        let destructive: [Int]
        let caution: [Int]?
        let cautionNote: String?
        let commands: [CameraCommand]
        enum CodingKeys: String, CodingKey {
            case model, destructive, caution, commands
            case firmwareObserved = "firmware_observed"
            case cautionNote = "caution_note"
        }
    }

    private static let file: File? = {
        guard let url = Bundle.module.url(forResource: "camera-commands", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    static let all: [CameraCommand] = file?.commands ?? []
    static let byCmd: [Int: CameraCommand] =
        Dictionary(all.map { ($0.cmd, $0) }, uniquingKeysWith: { first, _ in first })
    static let firmwareObserved = file?.firmwareObserved ?? "unknown"
    static let model = file?.model ?? "unknown"

    /// Writable, but with a consequence that is not obvious from the name.
    /// 9352 and 9353 are Export and Import Settings, and both are toggles rather
    /// than triggers: the camera only writes `viofo_config.ini` while 9352 is on.
    static let caution: Set<Int> = Set(file?.caution ?? [])
    static let cautionNote = file?.cautionNote

    static func command(_ cmd: Int) -> CameraCommand? { byCmd[cmd] }
    static func isDestructive(_ cmd: Int) -> Bool { CameraProtocol.destructive.contains(cmd) }
    static func isCautioned(_ cmd: Int) -> Bool { caution.contains(cmd) }
}
