import Foundation

/// Reads and writes camera settings over Wi-Fi.
///
/// Deliberately does not go through `viofo_config.ini`: that file is written
/// only when you ask the camera to export its settings, so it is stale from
/// then on, and the camera never reads it back. See docs/camera-http-api.md.
@MainActor
final class CameraClient: ObservableObject {

    enum State: Equatable {
        case idle
        case connecting
        case connected(firmware: String)
        case failed(String)
    }

    struct LiveSetting: Identifiable, Hashable {
        let cmd: Int
        var value: String
        var command: CameraCommand?
        var id: Int { cmd }
        var isKnown: Bool { command != nil }
        var title: String { command?.title ?? "Command \(cmd)" }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var settings: [LiveSetting] = []
    @Published private(set) var lastError: String?
    /// True while recording is stopped to let writes through, so the window can
    /// say so rather than appearing to hang.
    @Published private(set) var pausingRecording = false
    /// How many extra probes it took to get through, this session. Worth
    /// surfacing only because a link that needs retries is a link that will
    /// drop mid-write.
    @Published private(set) var retriedProbes = 0

    var host: URL = CameraProtocol.defaultHost

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 3
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    // MARK: - Requests

    /// Fetches a URL, retrying the connection failures that this camera's
    /// uplink-less access point provokes. See `CameraProtocol.Retry`.
    private func get(_ url: URL) async throws -> String {
        var attempt = 0
        let started = Date()
        while true {
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw CameraError.badResponse
                }
                if attempt > 0 { retriedProbes += attempt }
                return String(decoding: data, as: UTF8.self)
            } catch {
                guard CameraProtocol.Retry.shouldRetry(error,
                                                       elapsed: Date().timeIntervalSince(started))
                else { throw error }
                try await Task.sleep(
                    nanoseconds: UInt64(CameraProtocol.Retry.interval * 1_000_000_000))
                attempt += 1
            }
        }
    }

    private func send(cmd: Int, par: Int? = nil, str: String? = nil) async throws -> String {
        guard !CameraProtocol.destructive.contains(cmd) else { throw CameraError.destructive(cmd) }
        guard let url = CameraProtocol.url(host: host, cmd: cmd, par: par, str: str) else {
            throw CameraError.badURL
        }
        return try await get(url)
    }

    // MARK: - Public API

    func connect() async {
        state = .connecting
        lastError = nil
        do {
            let xml = try await send(cmd: CameraProtocol.Command.systemInfo.rawValue)
            let firmware = CameraProtocol.firmwareVersion(xml) ?? "unknown"
            state = .connected(firmware: firmware)
            await refresh()
        } catch {
            state = .failed(Self.describe(error, host: host))
        }
    }

    func refresh() async {
        do {
            let xml = try await send(cmd: CameraProtocol.Command.queryAllStatus.rawValue)
            let values = CameraProtocol.parseValues(xml)
            settings = values.keys.sorted().map { cmd in
                LiveSetting(cmd: cmd, value: values[cmd] ?? "",
                            command: CameraCommandCatalog.command(cmd))
            }
        } catch {
            lastError = Self.describe(error, host: host)
        }
    }

    /// Writes a batch of settings, then reports what actually landed.
    ///
    /// The read-back is not a formality. Recording-related settings are refused
    /// while the camera is recording, and the refusal is **silent**: the camera
    /// answers `<Status>0</Status>` and keeps the old value. Verified on
    /// V2.2_260815 with cmd=2003 (Loop Recording) — writing 1 while recording
    /// reports success and leaves it at 5; the identical write lands once
    /// recording is stopped.
    ///
    /// So anything that did not take is retried with recording stopped, and
    /// recording is restarted afterwards. That happens **once for the whole
    /// batch** rather than per setting, which is the main reason writes are
    /// staged and applied together.
    ///
    /// `cmd=9222` does not help. It is named as if it enters a settings mode,
    /// but on this firmware it leaves the camera recording and the write is
    /// still dropped.
    @discardableResult
    func apply(_ changes: [Int: Int]) async -> (written: Int, failed: [Int]) {
        guard !changes.isEmpty else { return (0, []) }
        lastError = nil
        var failed: [Int] = []
        do {
            for (cmd, value) in changes.sorted(by: { $0.key < $1.key }) {
                if try await put(cmd: cmd, value: value), took(cmd, value) { continue }
                failed.append(cmd)
            }
            if !failed.isEmpty, isRecording {
                pausingRecording = true
                defer { pausingRecording = false }
                _ = try await send(cmd: CameraProtocol.Command.movieRecord.rawValue, par: 0)
                try await Task.sleep(nanoseconds: 1_200_000_000)
                var stillFailed: [Int] = []
                for cmd in failed {
                    guard let value = changes[cmd] else { continue }
                    if try await put(cmd: cmd, value: value), took(cmd, value) { continue }
                    stillFailed.append(cmd)
                }
                _ = try? await send(cmd: CameraProtocol.Command.movieRecord.rawValue, par: 1)
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await refresh()
                failed = stillFailed
            }
        } catch {
            lastError = Self.describe(error, host: host)
        }
        if !failed.isEmpty, lastError == nil {
            let names = failed.map { CameraCommandCatalog.command($0)?.title ?? "cmd \($0)" }
            lastError = "The camera would not take: " + names.joined(separator: ", ")
        }
        return (changes.count - failed.count, failed)
    }

    @discardableResult
    func write(cmd: Int, value: Int) async -> Bool {
        await apply([cmd: value]).failed.isEmpty
    }

    private func took(_ cmd: Int, _ value: Int) -> Bool {
        settings.first { $0.cmd == cmd }?.value == String(value)
    }

    /// One write plus a refresh. Returns false only when the camera says no —
    /// the caller still has to check whether the value actually changed.
    private func put(cmd: Int, value: Int) async throws -> Bool {
        let xml = try await send(cmd: cmd, par: value)
        guard CameraProtocol.writeSucceeded(xml) else {
            lastError = "camera rejected \(cmd)=\(value)"
            return false
        }
        await refresh()
        return true
    }

    /// True while the camera is recording. `cmd=2016` reports a counter that
    /// climbs while recording and reads 0 when stopped.
    var isRecording: Bool {
        guard let v = settings.first(where: { $0.cmd == CameraProtocol.Command.movieRecord.rawValue })?.value,
              let n = Int(v) else { return false }
        return n != 0
    }

    @discardableResult
    func write(cmd: Int, text: String) async -> Bool {
        do {
            let xml = try await send(cmd: cmd, str: text)
            guard CameraProtocol.writeSucceeded(xml) else {
                lastError = "camera rejected \(cmd)=\"\(text)\""
                return false
            }
            await refresh()
            return true
        } catch {
            lastError = Self.describe(error, host: host)
            return false
        }
    }

    /// The camera's own export, for reference. It exists only if an export has
    /// been requested on the device, and reflects the settings as of that
    /// moment -- not anything written since. Expect a 404 if none has.
    func downloadConfig() async throws -> String {
        try await get(host.appendingPathComponent("viofo_config.ini"))
    }

    private static func describe(_ error: Error, host: URL) -> String {
        if let e = error as? CameraError { return e.description }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            // Every one of these has already been retried, so by now the camera
            // really is not answering. "Network unavailable" used to be reported
            // here, which read as though the Mac had no network at all when in
            // fact it was joined to the camera and the camera was simply off.
            switch ns.code {
            case NSURLErrorCannotConnectToHost, NSURLErrorTimedOut,
                 NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                // Deliberately no count: the time budget can cut the attempts
                // short, so a fixed number would often be wrong.
                return "No answer from \(host.host() ?? host.absoluteString) after retrying for "
                     + "\(Int(CameraProtocol.Retry.budget)) seconds. "
                     + "Check the camera is on and this Mac has joined its Wi-Fi."
            default: break
            }
        }
        return ns.localizedDescription
    }
}

enum CameraError: Error, CustomStringConvertible {
    case badURL
    case badResponse
    case destructive(Int)

    var description: String {
        switch self {
        case .badURL: return "Could not build the request URL."
        case .badResponse: return "The camera returned an unexpected response."
        case .destructive(let c): return "Refusing to send command \(c): it erases storage or resets the camera."
        }
    }
}
