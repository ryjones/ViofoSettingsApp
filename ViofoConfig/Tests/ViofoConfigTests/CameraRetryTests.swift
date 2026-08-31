import XCTest
@testable import ViofoConfig

/// The camera's access point has no uplink, and macOS intermittently fails the
/// request before it leaves the machine — URLSession returns
/// NSURLErrorNotConnectedToInternet while curl to the same address succeeds.
/// These cover which failures are worth another probe.
final class CameraRetryTests: XCTestCase {

    private func urlError(_ code: Int) -> Error {
        NSError(domain: NSURLErrorDomain, code: code)
    }

    func testTheFlakeThatPromptedThisIsRetried() {
        XCTAssertTrue(CameraProtocol.Retry.isTransient(urlError(NSURLErrorNotConnectedToInternet)))
    }

    func testOtherConnectionFailuresAreRetried() {
        for code in [NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost,
                     NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed] {
            XCTAssertTrue(CameraProtocol.Retry.isTransient(urlError(code)), "code \(code)")
        }
    }

    /// A reply that arrived and was wrong is not a connection problem. Repeating
    /// it would fail identically, and for a write it would be a second write.
    func testARepliedErrorIsNotRetried() {
        XCTAssertFalse(CameraProtocol.Retry.isTransient(CameraError.badResponse))
        XCTAssertFalse(CameraProtocol.Retry.isTransient(CameraError.destructive(3010)))
        XCTAssertFalse(CameraProtocol.Retry.isTransient(urlError(NSURLErrorUnsupportedURL)))
    }

    /// Probing stops at the budget, not at a fixed number of attempts.
    func testRetriesAreBoundedByElapsedTime() {
        let e = urlError(NSURLErrorTimedOut)
        XCTAssertTrue(CameraProtocol.Retry.shouldRetry(e, elapsed: 0))
        XCTAssertTrue(CameraProtocol.Retry.shouldRetry(e, elapsed: CameraProtocol.Retry.budget - 1))
        XCTAssertFalse(CameraProtocol.Retry.shouldRetry(e, elapsed: CameraProtocol.Retry.budget))
    }

    /// The flake this exists for fails instantly, so a ten second budget at half
    /// second intervals should give it plenty of attempts.
    func testTheInstantFailureGetsManyAttempts() {
        let e = urlError(NSURLErrorNotConnectedToInternet)
        var elapsed = 0.0, attempts = 0
        while CameraProtocol.Retry.shouldRetry(e, elapsed: elapsed) {
            elapsed += CameraProtocol.Retry.interval
            attempts += 1
        }
        XCTAssertGreaterThanOrEqual(attempts, 15, "expected roughly budget/interval probes")
        XCTAssertLessThanOrEqual(elapsed, CameraProtocol.Retry.budget)
    }

    /// A dead camera must not hang the window. The socket timeout has to stay
    /// under the budget, or a single attempt could run past it on its own.
    func testAnAttemptCannotOutlastTheBudget() {
        XCTAssertLessThan(CameraProtocol.Retry.interval, CameraProtocol.Retry.budget)
        XCTAssertLessThanOrEqual(CameraProtocol.Retry.budget, 15,
                                 "a failing connect should not hang the window")
    }

}
