import Foundation

/// A cross-setting observation: something that is legal in the file but will not
/// behave the way the values suggest, or that the manual explicitly advises against.
struct Advisory: Identifiable, Hashable {
    enum Severity: Int, Comparable {
        case gap = 0      // protection you probably think you have, but do not
        case conflict     // two settings that contradict each other
        case note         // worth knowing, not wrong

        static func < (l: Severity, r: Severity) -> Bool { l.rawValue < r.rawValue }

        var label: String {
            switch self {
            case .gap:      "Gap"
            case .conflict: "Conflict"
            case .note:     "Note"
            }
        }

        var symbol: String {
            switch self {
            case .gap:      "exclamationmark.triangle.fill"
            case .conflict: "arrow.triangle.branch"
            case .note:     "info.circle"
            }
        }
    }

    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String
    /// Keys the advisory is about, so the UI can jump straight to them.
    let keys: [String]

    static func == (l: Advisory, r: Advisory) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
enum AdvisoryEngine {

    static func evaluate(_ doc: ConfigDocument) -> [Advisory] {
        var out: [Advisory] = []
        func int(_ key: String) -> Int? { doc.intValue(for: key) }
        func text(_ key: String) -> String? { doc.value(for: key).map(ConfigDocument.unquote) }

        // 1. Driving impact detection disabled.
        if int("G-sensor") == 0 {
            out.append(Advisory(
                severity: .gap,
                title: "No clip is locked automatically in a collision",
                detail: """
                    G-sensor is Off, so an impact while driving will not move the clip to \
                    DCIM\\Movie\\RO and loop recording is free to overwrite it. You would have \
                    to reach over and press the lock button yourself. The manual recommends \
                    Low, which is sensitive enough for a real hit without locking files over \
                    every pothole.
                    """,
                keys: ["G-sensor"]))
        }

        // 2. Resolution mode vs. the cameras that are switched on.
        if let raw = int("Resolution"), let mode = Schema.resolutionMode(for: raw) {
            var enabled: [CameraRole] = [.front]
            if let v = int("Interior Camera"), v != 0 { enabled.append(.interior) }
            if let v = int("Rear Camera"), v != 0 { enabled.append(.rear) }
            let missing = enabled.filter { !mode.roles.contains($0) }
            if !missing.isEmpty {
                let names = missing.map(\.rawValue).joined(separator: " and ")
                let suggestion = Schema.resolutionModes
                    .filter { m in enabled.allSatisfy(m.roles.contains) }
                    .map { "\($0.raw) (\($0.label))" }
                    .prefix(4)
                    .joined(separator: ", ")
                out.append(Advisory(
                    severity: .conflict,
                    title: "\(names) enabled, but the resolution mode does not include \(missing.count == 1 ? "it" : "them")",
                    detail: """
                        Resolution \(raw) records \(mode.roles.map(\.rawValue).joined(separator: " + ")) \
                        — \(mode.channels) channel\(mode.channels == 1 ? "" : "s"). \(names) \
                        \(missing.count == 1 ? "is" : "are") switched on but not part of that mode.

                        Modes covering everything you have enabled: \(suggestion.isEmpty ? "none in this table" : suggestion).

                        The camera does adapt the menu to the cameras it detects, so this may \
                        simply be a stale export — but it is worth confirming on the device that \
                        every channel you expect is actually being written.
                        """,
                    keys: ["Resolution", "Interior Camera", "Rear Camera"]))
            }
        }

        // 3. 4K 60fps and HDR are mutually exclusive.
        if let raw = int("Resolution"), let mode = Schema.resolutionMode(for: raw),
           mode.detail.contains("60fps"), let hdr = int("HDR Front"), hdr != 0 {
            out.append(Advisory(
                severity: .conflict,
                title: "60fps front recording and HDR cannot both be active",
                detail: """
                    Resolution \(raw) records the front channel at 60fps, but the manual states \
                    4K 60fps is available only when HDR is disabled. One of the two will lose: \
                    either drop HDR Front to Off, or choose a 30fps mode.
                    """,
                keys: ["Resolution", "HDR Front"]))
        }

        // 4. Stamps switched on with nothing to print.
        if int("Custom Stamp") == 1, (text("Custom Text Stamp") ?? "").isEmpty {
            out.append(Advisory(
                severity: .conflict,
                title: "Custom Stamp is on but the text is empty",
                detail: "Custom Text Stamp is blank, so the stamp prints nothing. Either set up to 11 characters of text, or turn the stamp off.",
                keys: ["Custom Stamp", "Custom Text Stamp"]))
        }
        if int("License Plate Stamp") == 1, (text("License Plate Number") ?? "").isEmpty {
            out.append(Advisory(
                severity: .conflict,
                title: "License Plate Stamp is on but no plate is set",
                detail: "License Plate Number is blank, so nothing is imprinted.",
                keys: ["License Plate Stamp", "License Plate Number"]))
        }

        // 5. Every channel the camera has for telling you something is wrong is muted.
        if int("Beep Sound") == 0, int("Voice Notification") == 0 {
            var detail = """
                Beep Sound and Voice Notification are both Off, so a card error, a failed \
                format, or a missing card passes in silence — the camera can stop recording \
                without you noticing until you next look at the screen.
                """
            if int("Parking Impact Notification") == 0 {
                detail += """


                    Parking Impact Notification is Off too, so an impact while the car was \
                    parked is not announced at startup either.
                    """
            }
            detail += """


                Voice Notification set to Only Critical Alerts restores just the four \
                announcements that matter, without the running commentary.
                """
            out.append(Advisory(
                severity: .gap,
                title: "The camera cannot tell you when it has stopped working",
                detail: detail,
                keys: ["Beep Sound", "Voice Notification", "Parking Impact Notification"]))
        }

        // 6. Parking section configured but switched off.
        if int("Parking Mode") == 0 {
            out.append(Advisory(
                severity: .note,
                title: "Parking Mode is Off — the rest of that section is inert",
                detail: """
                    Sensitivities, cut-offs, storage and geofencing are all configured but \
                    unused while Parking Mode is Off. The car is unmonitored once the engine \
                    stops. Enabling it needs a power source that stays live: the manual \
                    recommends the VIOFO HK4 or HK6 ACC hardwire kit.
                    """,
                keys: ["Parking Mode"]))
        }

        // 7. A battery-protection measure is armed with no threshold behind it.
        if int("Parking Mode") != 0, let measure = int("Vehicle Battery Protection") {
            let pairs: [Int: (String, String)] = [
                0: ("Cut-off time", "Cut-off time"),
                1: ("Cut-off Voltage", "Cut-off Voltage"),
                2: ("Cut-off BP100 Capacity", "Cut-off BP100 Capacity"),
            ]
            if let (name, key) = pairs[measure], int(key) == 0 {
                out.append(Advisory(
                    severity: .note,
                    title: "\(name) is the selected protection, but its threshold is Off",
                    detail: """
                        Vehicle Battery Protection selects \(name), yet \(key) is set to Off, \
                        so nothing limits parking recording. Per the manual, recording then \
                        continues until the hardwire kit's own low-voltage protection cuts \
                        power — which is a valid choice, just not one this setting is making.
                        """,
                    keys: ["Vehicle Battery Protection", key]))
            }
        }

        // 8. Low-power parking modes ignore the SSD.
        if let mode = int("Parking Mode"), mode == 1 || mode == 2,
           let storage = int("Parking Recording Storage"), storage != 0 {
            out.append(Advisory(
                severity: .conflict,
                title: "Parking storage is set to SSD, but this parking mode writes to the card",
                detail: """
                    The manual states that in Low Power Impact Detection and Hybrid Parking \
                    Recording modes, parking files are stored on the microSD card only. The \
                    camera cannot keep an external SSD powered while it sits in low-power \
                    standby, so this setting is overridden.
                    """,
                keys: ["Parking Recording Storage", "Parking Mode"]))
        }

        // 9. Geofencing needs a fix.
        if let geo = int("Geofencing"), geo != 0, int("GPS") == 0 {
            out.append(Advisory(
                severity: .conflict,
                title: "Geofencing is on but GPS is off",
                detail: "Without GPS the camera cannot tell whether it is inside a zone. Per the manual, a weak or lost signal makes it enter parking mode as usual, so the zones never take effect.",
                keys: ["Geofencing", "GPS"]))
        }

        // 10. Stamps that need hardware the config cannot confirm.
        if int("Vehicle Voltage Stamp") == 1 {
            out.append(Advisory(
                severity: .note,
                title: "Vehicle Voltage Stamp needs the HK6 hardwire cable",
                detail: "The manual is explicit that the dashcam must be powered by the VIOFO HK6 hardwire cable for a voltage value to appear. On a cigarette-lighter charger the stamp has nothing to show.",
                keys: ["Vehicle Voltage Stamp"]))
        }
        if int("Cut-off Voltage") ?? 0 != 0 {
            out.append(Advisory(
                severity: .note,
                title: "Cut-off Voltage needs the HK6 ACC hardwire kit",
                detail: "Voltage-based cut-off is only available with the VIOFO HK6 ACC hardwire kit; the HK4 and other power sources cannot report battery voltage.",
                keys: ["Cut-off Voltage"]))
        }

        // 11. US-only daylight saving.
        if int("Daylight Saving") == 1, let tz = int("Time Zone") {
            let usZones = Set([3, 4, 5, 6, 7, 8])
            let label = Schema.timeZones.first { $0.raw == tz }?.label ?? "code \(tz)"
            if !usZones.contains(tz) {
                out.append(Advisory(
                    severity: .conflict,
                    title: "Daylight Saving is on outside the US zones",
                    detail: """
                        The camera only implements United States daylight saving rules, and \
                        Time Zone is \(label). The clock will jump on US changeover dates, which \
                        is probably not what your local time does. Turn Daylight Saving off and \
                        shift the zone by hand, or pick the matching US zone.
                        """,
                    keys: ["Daylight Saving", "Time Zone"]))
            } else {
                out.append(Advisory(
                    severity: .note,
                    title: "Time Zone should be the standard-time offset",
                    detail: """
                        With Daylight Saving on, the camera adds the hour itself, so Time Zone \
                        wants your winter offset. \(label) means Mountain in winter and its \
                        daylight equivalent in summer — if the stamps read an hour off, this \
                        pair is where to look. Pacific is GMT-8, Central GMT-6, Eastern GMT-5.
                        """,
                    keys: ["Time Zone", "Daylight Saving"]))
            }
        }

        // 12. Auto HDR window with nothing scheduled.
        let hdrKeys = ["HDR Front", "HDR Rear", "HDR Interior"]
        if hdrKeys.allSatisfy({ (int($0) ?? 0) != 2 }) {
            let start = text("Auto HDR Timer Start") ?? ""
            let stop = text("Auto HDR Timer Stop") ?? ""
            if !start.isEmpty || !stop.isEmpty {
                out.append(Advisory(
                    severity: .note,
                    title: "The Auto HDR window is set but no channel uses it",
                    detail: "\(start)–\(stop) only applies to a channel set to Auto HDR Timer. All three are on a fixed On/Off setting, so the times are ignored.",
                    keys: ["Auto HDR Timer Start", "Auto HDR Timer Stop", "HDR Front"]))
            }
        }

        // 13. Manual's explicit parking recommendations.
        if int("Parking Mode") != 0, let motion = int("Parking Motion Detection"), motion > 1 {
            out.append(Advisory(
                severity: .note,
                title: "Parking Motion Detection is above the manual's recommendation",
                detail: "The manual suggests Low sensitivity in parking mode so that wind and rain do not trigger recordings, which fill the card and drain the battery.",
                keys: ["Parking Motion Detection"]))
        }

        // 14. Station mode mapped to a button with no network stored.
        let stationMapped = [int("Mic Button"), int("Action Button")].contains(11)
        if stationMapped, (text("STA mode SSID") ?? "").isEmpty {
            out.append(Advisory(
                severity: .conflict,
                title: "A remote button switches to Wi-Fi Station Mode, but no network is set",
                detail: "STA mode SSID is empty, so there is nothing for the camera to join when the button is pressed.",
                keys: ["STA mode SSID", "Mic Button", "Action Button"]))
        }

        // 15. Privacy mode overrides loop length.
        if int("Privacy Mode") == 1 {
            out.append(Advisory(
                severity: .note,
                title: "Privacy Mode overrides the loop length",
                detail: "While Privacy Mode is on, loop recording is forced to 1-minute clips and only the last 2, 4 or 6 files are kept, depending on the channel count. The Loop Recording setting has no effect.",
                keys: ["Privacy Mode", "Loop Recording"]))
        }

        // 16. Over-length text fields.
        for spec in Schema.allSettings {
            if case let .text(maxLength) = spec.kind,
               let value = text(spec.key), value.count > maxLength {
                out.append(Advisory(
                    severity: .conflict,
                    title: "\(spec.title) is longer than the firmware allows",
                    detail: "\(value.count) characters, maximum \(maxLength). The camera will reject or truncate it.",
                    keys: [spec.key]))
            }
        }

        // 17. Keys this build does not describe.
        let unknown = doc.unknownKeys(knownKeys: Schema.knownKeys)
        if !unknown.isEmpty {
            out.append(Advisory(
                severity: .note,
                title: "\(unknown.count) key\(unknown.count == 1 ? "" : "s") not in this app's catalogue",
                detail: """
                    \(unknown.joined(separator: ", ")).

                    Newer firmware, or a different camera edition. The values are preserved \
                    exactly when you save; read the comment above each key in the raw file for \
                    its legal codes.
                    """,
                keys: []))
        }

        return out.sorted { ($0.severity, $0.title) < ($1.severity, $1.title) }
    }
}

private func < (l: (Advisory.Severity, String), r: (Advisory.Severity, String)) -> Bool {
    l.0 == r.0 ? l.1 < r.1 : l.0 < r.0
}
