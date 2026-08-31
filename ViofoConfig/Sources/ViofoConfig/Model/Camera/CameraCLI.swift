import Foundation

/// `ViofoConfig --camera` — reads the camera over Wi-Fi, and optionally exports
/// its settings as JSON or writes an edited profile back.
///
///     --camera                        list what the camera holds
///     --camera --export [file]        write a JSON profile (stdout if no file)
///     --camera --plan   <file>        show what applying it would change
///     --camera --apply  <file>        write the changes, reading each one back
///
/// `--apply` refuses destructive commands outright, and refuses the cautioned
/// ones unless `--allow-caution` is given.
enum CameraCLI {

    enum Mode {
        case list
        case export(String?)
        case plan(String)
        case apply(String)
    }

    static func run(host: String?, mode: Mode = .list, allowCaution: Bool = false) {
        let client = MainActor.assumeIsolated { CameraClient() }
        if let host, let url = URL(string: host) {
            MainActor.assumeIsolated { client.host = url }
        }
        // The work runs on the main actor, so the main thread must keep
        // servicing it rather than block on a semaphore.
        nonisolated(unsafe) var finished = false
        nonisolated(unsafe) var status: Int32 = 0
        Task { @MainActor in
            defer { finished = true }
            await client.connect()
            guard case .connected(let firmware) = client.state else {
                if case .failed(let message) = client.state { fail(message) }
                status = 1
                return
            }
            switch mode {
            case .list:            list(client, firmware: firmware)
            case .export(let path): status = export(client, firmware: firmware, to: path)
            case .plan(let path):   status = await applyOrPlan(client, path: path,
                                                               allowCaution: allowCaution, write: false)
            case .apply(let path):  status = await applyOrPlan(client, path: path,
                                                               allowCaution: allowCaution, write: true)
            }
        }
        while !finished {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        if status != 0 { exit(status) }
    }

    private static func fail(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    // MARK: - list

    @MainActor
    private static func list(_ client: CameraClient, firmware: String) {
        print("camera   \(client.host.absoluteString)")
        print("firmware \(firmware)")
        let known = client.settings.filter(\.isKnown)
        print("settings \(client.settings.count) (\(known.count) described, "
              + "\(client.settings.count - known.count) unrecognised)\n")
        for s in client.settings {
            let label = s.command?.label(for: s.value) ?? s.value
            let name = s.command?.key ?? "—"
            print(String(format: "  %-5d %-38s %-14s %@",
                         s.cmd, (name as NSString).utf8String!,
                         (s.value as NSString).utf8String!, label))
        }
    }

    // MARK: - export

    @MainActor
    private static func export(_ client: CameraClient, firmware: String, to path: String?) -> Int32 {
        let profile = CameraProfile.capture(settings: client.settings,
                                            model: CameraCommandCatalog.model,
                                            firmware: firmware,
                                            host: client.host.absoluteString)
        do {
            let json = try profile.json()
            guard let path else { print(json); return 0 }
            try json.write(toFile: path, atomically: true, encoding: .utf8)
            let writable = profile.settings.filter(\.writable).count
            FileHandle.standardError.write(Data(
                "wrote \(path): \(profile.settings.count) settings, \(writable) writable\n".utf8))
            return 0
        } catch {
            fail("cannot write profile: \(error.localizedDescription)")
            return 1
        }
    }

    // MARK: - plan / apply

    @MainActor
    private static func applyOrPlan(_ client: CameraClient, path: String,
                                    allowCaution: Bool, write: Bool) async -> Int32 {
        let profile: CameraProfile
        do {
            profile = try CameraProfile.load(Data(contentsOf: URL(fileURLWithPath: path)))
        } catch {
            fail("cannot read \(path): \(error.localizedDescription)")
            return 1
        }
        if profile.firmware != CameraCommandCatalog.firmwareObserved {
            fail("note: profile was taken from \(profile.firmware), "
                 + "catalogue describes \(CameraCommandCatalog.firmwareObserved)")
        }

        let live = Dictionary(client.settings.map { ($0.cmd, $0.value) },
                              uniquingKeysWith: { a, _ in a })
        let plan = profile.plan(against: live, allowCaution: allowCaution)

        let refused = plan.skipped.filter { if case .readOnly = $0.why { return true } else { return false } }
        for r in refused {
            if case .readOnly(let why) = r.why { print("skip   \(r.cmd) \(r.title) — \(why)") }
        }
        guard !plan.isEmpty else {
            print("nothing to change (\(plan.skipped.count) settings already match or are read-only)")
            return 0
        }
        for c in plan.changes {
            print("\(write ? "write" : "would") \(c.cmd) \(c.title): \(c.from) -> \(c.to)")
        }
        guard write else {
            print("\n\(plan.changes.count) change\(plan.changes.count == 1 ? "" : "s"); "
                  + "re-run with --apply to write them")
            return 0
        }

        var failures = 0
        for c in plan.changes {
            guard let value = Int(c.to) else { continue }
            let ok = await client.write(cmd: c.cmd, value: value)
            let now = client.settings.first { $0.cmd == c.cmd }?.value ?? "?"
            if ok {
                print("  ok   \(c.cmd) now \(now)")
            } else {
                failures += 1
                print("  FAIL \(c.cmd) still \(now)"
                      + (client.lastError.map { " — \($0)" } ?? ""))
            }
        }
        print("\n\(plan.changes.count - failures)/\(plan.changes.count) written")
        return failures == 0 ? 0 : 1
    }
}
