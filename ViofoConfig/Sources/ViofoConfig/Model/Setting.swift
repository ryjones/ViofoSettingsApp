import Foundation

/// One selectable value of an enumerated dash cam setting.
struct SettingOption: Identifiable, Hashable {
    let raw: Int
    let label: String
    /// Extra qualifier shown next to the label, e.g. "2 channels" or "HK6 required".
    var note: String? = nil

    var id: Int { raw }
}

/// How a setting's value is encoded in viofo_config.ini.
enum ValueKind {
    /// Integer code chosen from a fixed list.
    case options([SettingOption])
    /// Quoted free text with a firmware length cap.
    case text(maxLength: Int)
    /// Quoted 24-hour "hh:mm:ss".
    case time
}

/// A single documented line of the exported configuration.
struct SettingSpec: Identifiable, Hashable {
    /// Exact key as it appears in the file. Also the identity.
    let key: String
    let section: String
    /// Short human title for the UI (usually the key itself).
    let title: String
    let kind: ValueKind
    /// One line describing what the setting does.
    let summary: String
    /// Longer explanation drawn from the A329S manual.
    let manual: String
    /// Manual page reference, nil when the manual does not cover the key.
    var manualRef: String? = nil
    /// Hardware the setting depends on, e.g. "VIOFO HK6 ACC hardwire kit".
    var requires: String? = nil
    /// True when the firmware exports the key but manual V26.01.09 does not describe it.
    var undocumented: Bool { manualRef == nil }

    var id: String { key }

    static func == (lhs: SettingSpec, rhs: SettingSpec) -> Bool { lhs.key == rhs.key }
    func hash(into hasher: inout Hasher) { hasher.combine(key) }

    var options: [SettingOption] {
        if case let .options(list) = kind { return list }
        return []
    }

    /// Human label for a raw file value, falling back to the raw text for
    /// codes this schema does not know about (newer firmware, other editions).
    func label(forRawValue value: String) -> String {
        switch kind {
        case .options(let list):
            if let n = Int(value.trimmingCharacters(in: .whitespaces)),
               let match = list.first(where: { $0.raw == n }) {
                return match.label
            }
            return "Unknown code \(value)"
        case .text:
            let unquoted = ConfigDocument.unquote(value)
            return unquoted.isEmpty ? "(empty)" : unquoted
        case .time:
            return ConfigDocument.unquote(value)
        }
    }
}

/// A [Section] of the ini file, in file order.
struct SectionSpec: Identifiable, Hashable {
    let name: String
    /// What this group of settings covers, for the section header.
    let blurb: String
    let settings: [SettingSpec]

    var id: String { name }

    static func == (lhs: SectionSpec, rhs: SectionSpec) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}
