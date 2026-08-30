import SwiftUI

struct OverviewView: View {
    let advisories: [Advisory]
    @Binding var route: Route?
    @EnvironmentObject private var document: ConfigDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Digest.headline(document))
                        .font(.title.weight(.semibold))
                    if let url = document.fileURL {
                        Text(url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if !advisories.isEmpty {
                    Button {
                        route = .advisories
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checklist")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summaryLine)
                                    .fontWeight(.medium)
                                Text("Settings that contradict each other, or leave a gap in what the camera protects.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                    .background(gapCount > 0 ? Color.orange.opacity(0.14) : Color.secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 10))
                }

                ForEach(Digest.lines(document)) { line in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(line.title)
                            .font(.headline)
                        Text(line.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("About this file")
                        .font(.headline)
                    Text(Schema.aboutFile)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text("\(document.currentValues.count) keys")
                    Text("·")
                    Text("\(Schema.allSettings.filter { document.value(for: $0.key) != nil }.count) explained")
                    Text("·")
                    Text("explanations from manual V26.01.09")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var gapCount: Int { advisories.filter { $0.severity == .gap }.count }

    private var summaryLine: String {
        let conflicts = advisories.filter { $0.severity == .conflict }.count
        var parts: [String] = []
        if gapCount > 0 { parts.append("\(gapCount) gap\(gapCount == 1 ? "" : "s")") }
        if conflicts > 0 { parts.append("\(conflicts) conflict\(conflicts == 1 ? "" : "s")") }
        let notes = advisories.count - gapCount - conflicts
        if notes > 0 { parts.append("\(notes) note\(notes == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }
}

struct AdvisoryListView: View {
    let advisories: [Advisory]
    @Binding var route: Route?
    @EnvironmentObject private var document: ConfigDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Things to look at")
                    .font(.title.weight(.semibold))
                Text("Nothing here is invalid — the camera will accept every one of these. They are places where two settings disagree, or where the configuration protects less than it appears to.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if advisories.isEmpty {
                    ContentUnavailableView("Nothing stands out",
                                           systemImage: "checkmark.seal",
                                           description: Text("No contradictions found between the settings in this file."))
                        .padding(.top, 40)
                }

                ForEach(advisories) { advisory in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 8) {
                            Image(systemName: advisory.severity.symbol)
                                .foregroundStyle(tint(advisory.severity))
                            Text(advisory.title)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Badge(text: advisory.severity.label, tint: tint(advisory.severity))
                        }
                        Text(advisory.detail)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(.primary.opacity(0.85))
                        if !advisory.keys.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(advisory.keys, id: \.self) { key in
                                    if let spec = Schema.setting(key), document.value(for: key) != nil {
                                        Button {
                                            route = .section(spec.section)
                                        } label: {
                                            Text("\(spec.title): \(spec.label(forRawValue: document.value(for: key) ?? ""))")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.link)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tint(advisory.severity).opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                }
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private func tint(_ severity: Advisory.Severity) -> Color {
        switch severity {
        case .gap:      .orange
        case .conflict: .yellow
        case .note:     .secondary
        }
    }
}

struct RawFileView: View {
    @EnvironmentObject private var document: ConfigDocument

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(document.serialized())
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background)
    }
}
