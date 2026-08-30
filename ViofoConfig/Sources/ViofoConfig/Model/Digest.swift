import Foundation

/// Plain-language summaries of what a configuration actually does, assembled from
/// the values rather than listed key by key.
@MainActor
enum Digest {

    struct Line: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    static func headline(_ doc: ConfigDocument) -> String {
        guard let raw = doc.intValue(for: "Resolution"),
              let mode = Schema.resolutionMode(for: raw) else { return "Unknown recording mode" }
        return "\(mode.label) — \(mode.roles.map(\.rawValue).joined(separator: " + "))"
    }

    static func lines(_ doc: ConfigDocument) -> [Line] {
        var out: [Line] = []
        func label(_ key: String) -> String {
            guard let spec = Schema.setting(key), let raw = doc.value(for: key) else { return "—" }
            return spec.label(forRawValue: raw)
        }
        func int(_ key: String) -> Int? { doc.intValue(for: key) }

        // Driving
        var driving = "Clips are \(label("Loop Recording").lowercased()) long at \(label("Video Bitrate").lowercased()) bitrate"
        driving += int("Record Audio") == 0 ? ", without audio." : " with audio."
        if let g = int("G-sensor"), g == 0 {
            driving += " Impacts are not detected, so nothing is locked against being overwritten."
        } else {
            driving += " The G-sensor is set to \(label("G-sensor").lowercased()), locking a clip when it fires."
        }
        if let mode = int("Multiplex Video"), mode == 0 {
            driving += " Each camera writes its own file."
        } else {
            driving += " Channels are combined into one file (\(label("Multiplex Video")))."
        }
        out.append(Line(title: "While driving", body: driving))

        // Parking
        let parking: String
        if int("Parking Mode") == 0 {
            parking = "Parking Mode is Off — once the engine stops the camera stops with it, and nothing in the Parking Recording section applies."
        } else {
            var p = "Parked, the camera runs \(label("Parking Mode"))"
            if int("Parking Mode") == 1 {
                p += " (\(label("Hybrid Parking mode")))"
            }
            p += ". G-sensor \(label("Parking G-sensor").lowercased()), motion \(label("Parking Motion Detection").lowercased()), "
            p += "GPS \(label("Parking GPS").lowercased()), HDR \(label("Parking HDR").lowercased()), "
            p += "recording to \(label("Parking Recording Storage"))."
            let measure = int("Vehicle Battery Protection") ?? 0
            let thresholdKey = ["Cut-off time", "Cut-off Voltage", "Cut-off BP100 Capacity"][min(measure, 2)]
            if int(thresholdKey) == 0 {
                p += " No cut-off is set, so it runs until the hardwire kit removes power."
            } else {
                p += " It stops or downshifts at \(label(thresholdKey))."
            }
            parking = p
        }
        out.append(Line(title: "While parked", body: parking))

        // Picture
        var picture = "HDR is \(label("HDR Front").lowercased()) front, \(label("HDR Rear").lowercased()) rear, \(label("HDR Interior").lowercased()) interior."
        let evs = ["EV Front", "EV Interior", "EV Rear"].map { label($0) }
        picture += evs.allSatisfy { $0 == "+0.0" }
            ? " Exposure is at the default on every camera."
            : " Exposure compensation: front \(evs[0]), interior \(evs[1]), rear \(evs[2])."
        picture += " Anti-flicker is set for \(label("Frequency"))."
        out.append(Line(title: "Picture", body: picture))

        // Stamps
        let stampKeys = [
            ("Date Stamp", "date"), ("GPS Speed Stamp", "speed"), ("GPS Coordinates Stamp", "coordinates"),
            ("Custom Stamp", "custom text"), ("License Plate Stamp", "plate"), ("Logo Stamp", "logo"),
            ("Brand Model Stamp", "model"), ("Resolution Stamp", "resolution"),
            ("Vehicle Voltage Stamp", "voltage"), ("Battery pack Capacity Stamp", "battery capacity"),
        ]
        let on = stampKeys.filter { int($0.0) == 1 }.map(\.1)
        var stamps = on.isEmpty
            ? "Nothing is imprinted on the video."
            : "Burned into the picture in \(label("Stamp Text Color").lowercased()): \(on.joined(separator: ", "))."
        if int("License Plate Stamp") == 1 {
            let plate = ConfigDocument.unquote(doc.value(for: "License Plate Number") ?? "")
            if !plate.isEmpty { stamps += " Plate reads \(plate)." }
        }
        out.append(Line(title: "Stamps", body: stamps))

        // Storage and connectivity
        var system = "Driving footage goes to \(label("Driving Recording Storage")). "
        system += int("Wi-Fi") == 1
            ? "Wi-Fi is on at \(label("Wi-Fi Frequency")). "
            : "Wi-Fi is off, so the app cannot connect. "
        system += int("GPS") == 1 ? "GPS is on, " : "GPS is off, so there is no speed, position or clock sync, "
        system += "clock is \(label("Time Zone")) with daylight saving \(label("Daylight Saving").lowercased()), "
        system += "speed in \(label("Speed Units"))."
        out.append(Line(title: "System", body: system))

        // Feedback
        var feedback = "Beeps \(label("Beep Sound").lowercased()), voice notification \(label("Voice Notification").lowercased()), voice control \(label("Voice Control").lowercased())."
        if int("Beep Sound") == 0 && int("Voice Notification") == 0 {
            feedback += " The camera has no way to tell you about a card failure."
        }
        feedback += " Screen blanks after \(label("Screen Saver").lowercased())."
        out.append(Line(title: "Feedback", body: feedback))

        return out
    }

    /// A full Markdown report: every key, its value, the manual explanation, and the advisories.
    static func markdownReport(_ doc: ConfigDocument) -> String {
        var md = "# VIOFO A329S configuration\n\n"
        if let url = doc.fileURL { md += "`\(url.path)`\n\n" }
        md += "Explanations from A329S Series user manual V26.01.09.\n\n"

        md += "## Summary\n\n**\(headline(doc))**\n\n"
        for line in lines(doc) {
            md += "**\(line.title).** \(line.body)\n\n"
        }

        let advisories = AdvisoryEngine.evaluate(doc)
        if !advisories.isEmpty {
            md += "## Things to look at\n\n"
            for a in advisories {
                md += "### \(a.severity.label): \(a.title)\n\n\(a.detail)\n\n"
            }
        }

        md += "## Settings\n\n"
        for section in Schema.sections {
            let present = section.settings.filter { doc.value(for: $0.key) != nil }
            guard !present.isEmpty else { continue }
            md += "### [\(section.name)]\n\n\(section.blurb)\n\n"
            for spec in present {
                let raw = doc.value(for: spec.key) ?? ""
                md += "**\(spec.title) = \(raw.trimmingCharacters(in: .whitespaces))** — \(spec.label(forRawValue: raw))\n\n"
                if let ref = spec.manualRef {
                    md += "*\(spec.summary) (Manual \(ref))*\n\n"
                } else {
                    md += "*\(spec.summary) (not in manual V26.01.09)*\n\n"
                }
                if let requires = spec.requires {
                    md += "> Requires: \(requires)\n\n"
                }
                md += spec.manual.replacingOccurrences(of: "\n", with: "\n") + "\n\n"
            }
        }
        return md
    }
}
