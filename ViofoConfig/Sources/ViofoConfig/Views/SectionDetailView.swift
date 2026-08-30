import SwiftUI

struct SectionDetailView: View {
    let section: SectionSpec
    let search: String
    let advisories: [Advisory]

    @EnvironmentObject private var document: ConfigDocument

    private var visible: [SettingSpec] {
        let present = section.settings.filter { document.value(for: $0.key) != nil }
        guard !search.isEmpty else { return present }
        let q = search.lowercased()
        return present.filter {
            $0.title.lowercased().contains(q)
            || $0.summary.lowercased().contains(q)
            || $0.manual.lowercased().contains(q)
            || $0.options.contains { $0.label.lowercased().contains(q) }
        }
    }

    private var absent: [SettingSpec] {
        section.settings.filter { document.value(for: $0.key) == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("[\(section.name)]")
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                    Text(section.blurb)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 2)

                if visible.isEmpty {
                    ContentUnavailableView(
                        search.isEmpty ? "Nothing in this section" : "No matches",
                        systemImage: "magnifyingglass",
                        description: Text(search.isEmpty
                                          ? "The open file contains none of this section's keys."
                                          : "No setting here matches “\(search)”.")
                    )
                    .padding(.top, 40)
                }

                ForEach(visible) { spec in
                    SettingCard(spec: spec, advisories: advisories.filter { $0.keys.contains(spec.key) })
                        .id(spec.key)
                }

                if !absent.isEmpty && search.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not present in this file")
                            .font(.headline)
                        Text(absent.map(\.title).joined(separator: ", "))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("These belong to camera editions or firmware other than the one that wrote this export.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(26)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingCard: View {
    let spec: SettingSpec
    let advisories: [Advisory]

    @EnvironmentObject private var document: ConfigDocument
    @State private var expanded = false

    private var changed: Bool { document.isChanged(spec.key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(spec.title)
                            .font(.headline)
                        if changed { Circle().fill(.orange).frame(width: 6, height: 6) }
                    }
                    Text(spec.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                control
                    .frame(maxWidth: 300, alignment: .trailing)
            }

            HStack(spacing: 8) {
                if let ref = spec.manualRef {
                    Badge(text: "Manual \(ref)", tint: .secondary)
                } else {
                    Badge(text: "Not in manual V26.01.09", tint: .purple)
                }
                if let requires = spec.requires {
                    Badge(text: requires, tint: .teal)
                }
                if changed, let was = document.original[spec.key] {
                    Badge(text: "was \(spec.label(forRawValue: was))", tint: .orange)
                    Button("Revert") { document.revert(key: spec.key) }
                        .buttonStyle(.link)
                        .font(.caption)
                }
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.18)) { expanded.toggle() }
                } label: {
                    Label(expanded ? "Hide" : "What this does",
                          systemImage: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }

            if expanded {
                Text(spec.manual)
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            ForEach(advisories) { advisory in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: advisory.severity.symbol)
                        .foregroundStyle(advisory.severity == .gap ? .orange : .secondary)
                    Text(advisory.title)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((advisory.severity == .gap ? Color.orange : Color.secondary).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(changed ? Color.orange.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var control: some View {
        switch spec.kind {
        case .options(let options):
            OptionPicker(spec: spec, options: options)
        case .text(let maxLength):
            VStack(alignment: .trailing, spacing: 3) {
                TextField("", text: document.textBinding(spec.key))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                let count = ConfigDocument.unquote(document.value(for: spec.key) ?? "").count
                Text("\(count)/\(maxLength)")
                    .font(.caption2)
                    .foregroundStyle(count > maxLength ? Color.red : Color.secondary.opacity(0.7))
            }
        case .time:
            TextField("hh:mm:ss", text: document.textBinding(spec.key))
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .monospaced()
        }
    }
}

/// A menu picker that keeps working when the file holds a code this build does
/// not know — the unknown value is added to the list rather than silently reset.
struct OptionPicker: View {
    let spec: SettingSpec
    let options: [SettingOption]
    @EnvironmentObject private var document: ConfigDocument

    var body: some View {
        let current = document.intValue(for: spec.key) ?? options.first?.raw ?? 0
        let known = options.contains { $0.raw == current }
        let list = known ? options : options + [SettingOption(raw: current, label: "Unknown code \(current)")]

        Picker("", selection: document.intBinding(spec.key, fallback: current)) {
            ForEach(list) { option in
                HStack {
                    Text(option.label)
                    if let note = option.note {
                        Text("· \(note)").foregroundStyle(.secondary)
                    }
                }
                .tag(option.raw)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(minWidth: 200)
    }
}

struct Badge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
