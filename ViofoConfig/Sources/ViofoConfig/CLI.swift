import Foundation

/// The app doubles as a command line reader so a configuration can be explained
/// or checked without opening a window:
///
///     ViofoConfig --report /Volumes/CARD/viofo_config.ini   # full Markdown explanation
///     ViofoConfig --check  /Volumes/CARD/viofo_config.ini   # advisories only
///     ViofoConfig --camera [http://host]                    # read the camera live
///     ViofoConfig --camera --export profile.json            # settings as JSON
///     ViofoConfig --camera --plan   profile.json            # what applying it would change
///     ViofoConfig --camera --apply  profile.json            # write it back
@main
enum EntryPoint {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--camera") {
            let host = args.first(where: { $0.hasPrefix("http://") })
            let allowCaution = args.contains("--allow-caution")
            // The value after the flag, unless it is another flag or the host.
            func operand(after flag: String) -> String? {
                guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
                let next = args[i + 1]
                return next.hasPrefix("-") || next.hasPrefix("http://") ? nil : next
            }
            let mode: CameraCLI.Mode
            if args.contains("--export") {
                mode = .export(operand(after: "--export"))
            } else if args.contains("--plan") {
                guard let p = operand(after: "--plan") else { return usage("--plan") }
                mode = .plan(p)
            } else if args.contains("--apply") {
                guard let p = operand(after: "--apply") else { return usage("--apply") }
                mode = .apply(p)
            } else {
                mode = .list
            }
            CameraCLI.run(host: host, mode: mode, allowCaution: allowCaution)
            return
        }
        if let flagIndex = args.firstIndex(where: { $0 == "--report" || $0 == "--check" }) {
            let flag = args[flagIndex]
            guard flagIndex + 1 < args.count else {
                FileHandle.standardError.write(Data("usage: ViofoConfig \(flag) <path to viofo_config.ini>\n".utf8))
                exit(2)
            }
            MainActor.assumeIsolated {
                run(flag: flag, path: args[flagIndex + 1])
            }
            return
        }
        // A bare path argument opens that file at launch: `open -a ViofoConfig --args <path>`.
        if let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) {
            Launch.initialURL = URL(fileURLWithPath: path)
        }
        ViofoConfigApp.main()
    }

    private static func usage(_ flag: String) {
        FileHandle.standardError.write(Data(
            "usage: ViofoConfig --camera \(flag) <profile.json>\n".utf8))
        exit(2)
    }

    @MainActor
    private static func run(flag: String, path: String) {
        let document = ConfigDocument()
        do {
            try document.load(from: URL(fileURLWithPath: path))
        } catch {
            FileHandle.standardError.write(Data("cannot read \(path): \(error.localizedDescription)\n".utf8))
            exit(1)
        }

        if flag == "--report" {
            print(Digest.markdownReport(document))
            return
        }

        print(Digest.headline(document))
        print()
        for line in Digest.lines(document) {
            print("\(line.title): \(line.body)\n")
        }
        let advisories = AdvisoryEngine.evaluate(document)
        print("— \(advisories.count) advisory item\(advisories.count == 1 ? "" : "s") —\n")
        for advisory in advisories {
            print("[\(advisory.severity.label)] \(advisory.title)")
            print(advisory.detail.split(separator: "\n").map { "    \($0)" }.joined(separator: "\n"))
            print()
        }
        // Non-zero exit when the configuration leaves a protection gap, so this
        // can be dropped into a script.
        exit(advisories.contains { $0.severity == .gap } ? 1 : 0)
    }
}
