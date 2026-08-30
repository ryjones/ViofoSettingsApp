import SwiftUI

enum Route: Hashable {
    case overview
    case advisories
    case section(String)
    case raw
}

struct ContentView: View {
    @EnvironmentObject private var document: ConfigDocument
    @State private var route: Route? = .overview
    @State private var search = ""

    private var advisories: [Advisory] { AdvisoryEngine.evaluate(document) }
    private var isLoaded: Bool { !document.lines.isEmpty }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            Group {
                if !isLoaded {
                    WelcomeView()
                } else {
                    switch route ?? .overview {
                    case .overview:
                        OverviewView(advisories: advisories, route: $route)
                    case .advisories:
                        AdvisoryListView(advisories: advisories, route: $route)
                    case .section(let name):
                        if let section = Schema.sections.first(where: { $0.name == name }) {
                            SectionDetailView(section: section, search: search, advisories: advisories)
                        }
                    case .raw:
                        RawFileView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .searchable(text: $search, placement: .sidebar, prompt: "Search settings")
        .toolbar { toolbarContent }
        .navigationTitle(document.fileURL?.lastPathComponent ?? "VIOFO Settings")
        .navigationSubtitle(isLoaded ? Digest.headline(document) : "")
        .onAppear {
            if let url = Launch.initialURL {
                Launch.initialURL = nil
                FileActions.load(url, into: document)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Launch.openRequest)) { note in
            if let url = note.object as? URL { FileActions.load(url, into: document) }
        }
        .onChange(of: search) { _, value in
            // Typing a query jumps to the first section that contains a match.
            guard !value.isEmpty,
                  let hit = Schema.sections.first(where: { section in
                      section.settings.contains { matches($0, value) }
                  })
            else { return }
            if case .section(let current) = route ?? .overview,
               Schema.sections.first(where: { $0.name == current })?.settings.contains(where: { matches($0, value) }) == true {
                return
            }
            route = .section(hit.name)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $route) {
            if isLoaded {
                Section {
                    Label("Overview", systemImage: "doc.text.magnifyingglass")
                        .tag(Route.overview)
                    HStack {
                        Label("Things to look at", systemImage: "checklist")
                        Spacer()
                        if !advisories.isEmpty {
                            Text("\(advisories.count)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(Route.advisories)
                }

                Section("Settings") {
                    ForEach(Schema.sections) { section in
                        let hits = matchCount(section)
                        HStack {
                            Text(section.name)
                            Spacer()
                            if !search.isEmpty {
                                Text("\(hits)")
                                    .monospacedDigit()
                                    .foregroundStyle(hits == 0 ? .tertiary : .secondary)
                            } else if changedCount(section) > 0 {
                                Circle().fill(.orange).frame(width: 7, height: 7)
                            }
                        }
                        .tag(Route.section(section.name))
                        .opacity(search.isEmpty || hits > 0 ? 1 : 0.4)
                    }
                }

                Section {
                    Label("Raw file", systemImage: "curlybraces")
                        .tag(Route.raw)
                }
            } else {
                Text("No file open")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
    }

    private func matches(_ spec: SettingSpec, _ query: String) -> Bool {
        let q = query.lowercased()
        return spec.title.lowercased().contains(q)
            || spec.summary.lowercased().contains(q)
            || spec.manual.lowercased().contains(q)
            || spec.options.contains { $0.label.lowercased().contains(q) }
    }

    private func matchCount(_ section: SectionSpec) -> Int {
        guard !search.isEmpty else { return section.settings.count }
        return section.settings.filter { matches($0, search) }.count
    }

    private func changedCount(_ section: SectionSpec) -> Int {
        section.settings.filter { document.isChanged($0.key) }.count
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            if document.isModified {
                Text("Edited")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.orange.opacity(0.18), in: Capsule())
                    .foregroundStyle(.orange)
            }
            Button {
                document.revertAll()
            } label: {
                Label("Revert", systemImage: "arrow.uturn.backward")
            }
            .disabled(!document.isModified)
            .help("Restore every value to what the file contained when it was opened")

            Button {
                FileActions.open(into: document)
            } label: {
                Label("Open", systemImage: "folder")
            }
            .help("Open a viofo_config.ini")

            Button {
                FileActions.save(document)
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(!isLoaded)
            .help("Write the file back, preserving its comments and layout")

            Button {
                FileActions.exportReport(document)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(!isLoaded)
            .help("Save a Markdown explanation of this configuration")
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var document: ConfigDocument
    @State private var candidates: [URL] = FileActions.discoverCards()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("VIOFO A329S Settings")
                        .font(.largeTitle.weight(.semibold))
                    Text("Read, explain and edit the configuration the camera exports to its memory card.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text(Schema.aboutFile)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

                if !candidates.isEmpty {
                    fileList("Found on mounted volumes", icon: "sdcard", urls: candidates)
                }

                let recents = FileActions.recents.filter { !candidates.contains($0) }
                if !recents.isEmpty {
                    fileList("Opened recently", icon: "clock", urls: recents)
                }

                HStack(spacing: 12) {
                    Button("Open File…") { FileActions.open(into: document) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Button("Rescan Volumes") { candidates = FileActions.discoverCards() }
                        .controlSize(.large)
                }
            }
            .padding(34)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private func fileList(_ title: String, icon: String, urls: [URL]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            ForEach(urls, id: \.self) { url in
                Button {
                    FileActions.load(url, into: document)
                } label: {
                    HStack {
                        Image(systemName: icon)
                        VStack(alignment: .leading) {
                            Text(url.deletingLastPathComponent().lastPathComponent)
                                .fontWeight(.medium)
                            Text(url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(10)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
