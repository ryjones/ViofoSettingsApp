import Foundation

/// An in-memory viofo_config.ini that round-trips byte-for-byte apart from the
/// values the user actually changes. The camera exports the file with a comment
/// above every key listing its legal codes; those comments are preserved.
@MainActor
final class ConfigDocument: ObservableObject {

    enum Line: Equatable {
        case blank
        case comment(String)          // full text including the leading '#'
        case section(String)          // section name without brackets
        case pair(key: String, value: String, spacing: String)
        case raw(String)              // anything unrecognised, passed through
    }

    @Published private(set) var lines: [Line] = []
    @Published private(set) var original: [String: String] = [:]
    @Published var fileURL: URL?
    /// Line ending used by the source file, so saving does not rewrite the whole thing.
    private var lineEnding = "\n"
    private var trailingNewline = true

    var isModified: Bool {
        currentValues != original
    }

    var currentValues: [String: String] {
        var out: [String: String] = [:]
        for case let .pair(key, value, _) in lines { out[key] = value }
        return out
    }

    /// Keys present in the file but absent from the bundled schema.
    func unknownKeys(knownKeys: Set<String>) -> [String] {
        currentValues.keys.filter { !knownKeys.contains($0) }.sorted()
    }

    /// Keys the schema documents but this particular export does not contain.
    func missingKeys(knownKeys: [String]) -> [String] {
        let present = Set(currentValues.keys)
        return knownKeys.filter { !present.contains($0) }
    }

    // MARK: - Access

    func value(for key: String) -> String? { currentValues[key] }

    func intValue(for key: String) -> Int? {
        guard let raw = value(for: key) else { return nil }
        return Int(raw.trimmingCharacters(in: .whitespaces))
    }

    func setValue(_ newValue: String, for key: String) {
        guard let index = lines.firstIndex(where: {
            if case let .pair(k, _, _) = $0 { return k == key }
            return false
        }) else { return }
        guard case let .pair(k, old, spacing) = lines[index], old != newValue else { return }
        lines[index] = .pair(key: k, value: newValue, spacing: spacing)
    }

    func setInt(_ newValue: Int, for key: String) {
        setValue(String(newValue), for: key)
    }

    /// Text and time values are stored quoted in the exported file.
    func setQuoted(_ newValue: String, for key: String) {
        setValue("\"\(newValue)\"", for: key)
    }

    func revert(key: String) {
        if let value = original[key] { setValue(value, for: key) }
    }

    func revertAll() {
        for (key, value) in original { setValue(value, for: key) }
    }

    // MARK: - Load / save

    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw ConfigError.notReadable
        }
        parse(text)
        fileURL = url
        original = currentValues
    }

    func load(text: String, url: URL? = nil) {
        parse(text)
        fileURL = url
        original = currentValues
    }

    func save(to url: URL) throws {
        try serialized().write(to: url, atomically: true, encoding: .utf8)
        fileURL = url
        original = currentValues
    }

    func save() throws {
        guard let fileURL else { throw ConfigError.noDestination }
        try save(to: fileURL)
    }

    func serialized() -> String {
        var out: [String] = []
        for line in lines {
            switch line {
            case .blank:                       out.append("")
            case .comment(let text):           out.append(text)
            case .section(let name):           out.append("[\(name)]")
            case .pair(let k, let v, let sp):  out.append("\(k)\(sp)=\(v)")
            case .raw(let text):               out.append(text)
            }
        }
        return out.joined(separator: lineEnding) + (trailingNewline ? lineEnding : "")
    }

    // MARK: - Parsing

    private func parse(_ text: String) {
        lineEnding = text.contains("\r\n") ? "\r\n" : "\n"
        trailingNewline = text.hasSuffix("\n")

        var parsed: [Line] = []
        let rawLines = text.components(separatedBy: lineEnding)
        var body = rawLines
        // components() leaves a trailing empty element for a final newline.
        if trailingNewline, body.last?.isEmpty == true { body.removeLast() }

        for raw in body {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                parsed.append(.blank)
            } else if trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                parsed.append(.comment(raw))
            } else if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                parsed.append(.section(String(trimmed.dropFirst().dropLast())))
            } else if let eq = raw.firstIndex(of: "=") {
                let lhs = String(raw[raw.startIndex..<eq])
                let value = String(raw[raw.index(after: eq)...])
                let key = lhs.trimmingCharacters(in: .whitespaces)
                // Keep any padding between key and '=' so the file looks untouched.
                let spacing = String(lhs.dropFirst(key.count))
                parsed.append(.pair(key: key, value: value, spacing: spacing))
            } else {
                parsed.append(.raw(raw))
            }
        }
        lines = parsed
    }

    // MARK: - Helpers

    nonisolated static func unquote(_ value: String) -> String {
        var s = value.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 {
            s = String(s.dropFirst().dropLast())
        }
        return s
    }
}

enum ConfigError: LocalizedError {
    case notReadable
    case noDestination

    var errorDescription: String? {
        switch self {
        case .notReadable:  "The file could not be decoded as text."
        case .noDestination: "No file has been opened yet — use Save As."
        }
    }
}
