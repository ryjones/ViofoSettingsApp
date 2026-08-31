import Foundation

/// The camera's numbered-command HTTP API, as verified against an A329S running
/// `VIOFO_A329S_V2.2_260815`. See docs/camera-http-api.md.
///
///     http://192.168.1.254/?custom=1&cmd=<number>[&par=<int>][&str=<text>]
///
/// Replies are XML. Note that `cmd=3014` returns a *flat token stream* — `<Cmd>`
/// and `<Status>` alternate at one level, and only string-valued settings get
/// their own `<Function>` wrapper — so it has to be parsed in document order
/// rather than by element nesting.
enum CameraProtocol {

    static let defaultHost = URL(string: "http://192.168.1.254")!

    enum Command: Int {
        case systemInfo      = 3012   // firmware version, in <String>
        case queryAllStatus  = 3014   // every setting with its current value
        case movieRecord     = 2001   // 1 starts recording, 0 stops it
        case exportToCard    = 3021   // writes viofo_config.ini -- see below
        // Named as if they bracket a settings session, but on V2.2_260815 9222
        // leaves the camera recording, and a write that needs recording stopped
        // is still dropped after sending it. Use 2001 instead.
        case settingsEnter   = 9222
        case settingsExit    = 9223
    }

    /// `cmd=3021` is the camera's own "export settings to the card" action: its
    /// handler is a bare call to the export routine. It is not used here, and
    /// the app takes a JSON profile from `cmd=3014` instead, because it is
    /// unreliable — the export refuses while the camera is in recording mode,
    /// and answers `<Status>0</Status>` either way, so a caller cannot tell
    /// whether anything was written. Verified: stopping recording with
    /// `cmd=2001&par=0` and calling it still produced no file.
    static let exportIsUnreliable = true

    /// Commands that erase storage or reset the camera. Never sent.
    ///
    /// 3010 formats the card, 3011 resets to factory, 9317 formats the SSD.
    /// 9316 is listed under two names — `CMD_BAK_SDCARD_TO_SSD` and
    /// `CMD_DELETE_SSD_FILE` — so depending on its parameter it may delete
    /// files. It is refused rather than characterised by experiment.
    ///
    /// 8230 is `system_reboot`: its handler prints that banner, exports the
    /// settings, then drops the camera. Not destructive, but nothing here has a
    /// reason to reboot the camera out from under the user.
    static let destructive: Set<Int> = [3010, 3011, 8230, 9316, 9317]

    static func url(host: URL, cmd: Int, par: Int? = nil, str: String? = nil) -> URL? {
        var items = [URLQueryItem(name: "custom", value: "1"),
                     URLQueryItem(name: "cmd", value: String(cmd))]
        if let par { items.append(URLQueryItem(name: "par", value: String(par))) }
        if let str { items.append(URLQueryItem(name: "str", value: str)) }
        var comps = URLComponents(url: host, resolvingAgainstBaseURL: false)
        comps?.path = "/"
        comps?.queryItems = items
        return comps?.url
    }

    /// Parses a reply into command → value, in document order.
    ///
    /// A `<String>` overrides the `<Status>` that preceded it for the same
    /// command, which is how multi-channel settings like exposure arrive
    /// (`8220` carries `"6,6,6"`).
    static func parseValues(_ xml: String) -> [Int: String] {
        var values: [Int: String] = [:]
        var current: Int?
        let pattern = try! NSRegularExpression(pattern: "<(Cmd|Status|String)>\\s*([^<]*?)\\s*</\\1>")
        let ns = xml as NSString
        for m in pattern.matches(in: xml, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: m.range(at: 1))
            let text = ns.substring(with: m.range(at: 2))
            switch tag {
            case "Cmd":    current = Int(text)
            case "Status", "String":
                if let c = current { values[c] = text }
            default: break
            }
        }
        return values
    }

    /// A write reply carries `<Status>0</Status>` on success.
    static func writeSucceeded(_ xml: String) -> Bool {
        let v = parseValues(xml)
        return v.values.first == "0" || xml.contains("<Status>0</Status>")
    }

    /// When to try a request again.
    ///
    /// The camera's access point has no uplink, and macOS sometimes decides the
    /// path is unusable and fails the request outright — `URLSession` returns
    /// `NSURLErrorNotConnectedToInternet` while `curl` to the same address at
    /// the same moment succeeds. It clears on its own within a second or two, so
    /// the fix is to probe again rather than to report the camera missing.
    ///
    /// Only failures raised *before* a reply arrives are retried. Those cannot
    /// have changed anything on the camera, which is what makes it safe to
    /// repeat a write.
    enum Retry {
        /// Probe again this often.
        static let interval: Double = 0.5

        /// Keep probing until the request as a whole has taken this long, then
        /// fail. The socket timeout is kept below this so an attempt cannot run
        /// past the budget on its own — a camera that is switched off burns the
        /// full timeout every attempt, and an earlier cut of this took 36
        /// seconds to report one.
        static let budget: Double = 10.0

        private static let transient: Set<Int> = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost,
            NSURLErrorTimedOut,
            NSURLErrorDNSLookupFailed,
            NSURLErrorResourceUnavailable,
        ]

        /// True when the request never reached the camera.
        static func isTransient(_ error: Error) -> Bool {
            // A reply that arrived and was wrong is not a connection problem;
            // repeating it would just fail the same way.
            if error is CameraError { return false }
            let ns = error as NSError
            return ns.domain == NSURLErrorDomain && transient.contains(ns.code)
        }

        static func shouldRetry(_ error: Error, elapsed: Double) -> Bool {
            isTransient(error) && elapsed + interval < budget
        }
    }

    /// The firmware version string from a `cmd=3012` reply.
    static func firmwareVersion(_ xml: String) -> String? {
        guard let r = xml.range(of: "<String>"), let e = xml.range(of: "</String>") else { return nil }
        return String(xml[r.upperBound..<e.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
