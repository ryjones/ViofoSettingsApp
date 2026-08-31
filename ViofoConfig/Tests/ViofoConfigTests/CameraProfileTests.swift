import XCTest
@testable import ViofoConfig

/// The JSON profile is the replacement for `viofo_config.ini`: taken from
/// `cmd=3014`, edited by hand, written back over HTTP.
final class CameraProfileTests: XCTestCase {

    private func live(_ pairs: [Int: String]) -> [CameraClient.LiveSetting] {
        pairs.keys.sorted().map {
            CameraClient.LiveSetting(cmd: $0, value: pairs[$0]!,
                                     command: CameraCommandCatalog.command($0))
        }
    }

    private func profile(_ pairs: [Int: String]) -> CameraProfile {
        CameraProfile.capture(settings: live(pairs), model: "A329S",
                              firmware: CameraCommandCatalog.firmwareObserved,
                              host: "http://192.168.1.254")
    }

    // MARK: - Capture

    func testCaptureNamesAndDecodesEachSetting() {
        let p = profile([8214: "0"])                      // Beep Sound, Off
        let e = try? XCTUnwrap(p.settings.first)
        XCTAssertEqual(e?.cmd, 8214)
        XCTAssertEqual(e?.iniKey, "Beep Sound")
        XCTAssertEqual(e?.value, "0")
        XCTAssertEqual(e?.label, "OFF")
        XCTAssertTrue(e?.writable ?? false)
    }

    /// The label is a convenience for the reader. If it were the same as the
    /// raw value it is noise, so it is left out.
    func testLabelIsOmittedWhenItAddsNothing() {
        let p = profile([2020: "50"])                     // no option list
        XCTAssertNil(p.settings.first?.label)
    }

    func testRoundTripsThroughJSON() throws {
        let original = profile([8214: "0", 9321: "0"])
        let decoded = try CameraProfile.load(Data(original.json().utf8))
        XCTAssertEqual(decoded.settings.map(\.cmd), original.settings.map(\.cmd))
        XCTAssertEqual(decoded.settings.map(\.value), original.settings.map(\.value))
        XCTAssertEqual(decoded.firmware, original.firmware)
    }

    // MARK: - Planning

    func testUnchangedValuesProduceNoWrites() {
        let p = profile([8214: "0"])
        XCTAssertTrue(p.plan(against: [8214: "0"]).isEmpty)
    }

    func testAnEditBecomesOneWrite() {
        var p = profile([8214: "0"])
        p.settings[0].value = "1"
        let plan = p.plan(against: [8214: "0"])
        XCTAssertEqual(plan.changes, [.init(cmd: 8214, title: "Beep Sound", from: "0", to: "1")])
    }

    /// 8220 answers "6,6,6" for front/interior/rear at once. A single `par=`
    /// cannot say that, so it is exported for reference and refused on write.
    func testMultiChannelValuesAreRefused() {
        var p = profile([8220: "6,6,6"])
        XCTAssertFalse(p.settings[0].writable)
        p.settings[0].value = "7,7,7"
        let plan = p.plan(against: [8220: "6,6,6"])
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.skipped.first?.why, .readOnly("multi-channel"))
    }

    func testCautionedCommandsNeedTheFlag() {
        var p = profile([9352: "1"])                      // Export Settings
        p.settings[0].value = "0"
        XCTAssertTrue(p.plan(against: [9352: "1"]).isEmpty)
        XCTAssertEqual(p.plan(against: [9352: "1"], allowCaution: true).changes.count, 1)
    }

    /// A profile is a file the user edits, so a hand-set `"writable": true` on a
    /// destructive command must not be believed.
    func testDestructiveCommandsAreRefusedEvenIfTheFileSaysWritable() throws {
        let json = """
        {"model":"A329S","firmware":"\(CameraCommandCatalog.firmwareObserved)",
         "host":"http://192.168.1.254","captured":"2026-08-30T00:00:00Z",
         "settings":[{"cmd":3010,"key":"CMD_FORMAT","title":"Format",
                      "value":"1","writable":true}]}
        """
        let p = try CameraProfile.load(Data(json.utf8))
        let plan = p.plan(against: [3010: "0"])
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.skipped.first?.why, .readOnly("destructive"))
    }

    func testNonNumericEditsAreRejectedRatherThanSent() {
        var p = profile([8214: "0"])
        p.settings[0].value = "On"                        // label, not a value
        let plan = p.plan(against: [8214: "0"])
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.skipped.first?.why, .notInteger("On"))
    }

    func testSettingsTheCameraDoesNotReportAreSkipped() {
        let p = profile([8214: "0"])
        XCTAssertEqual(p.plan(against: [:]).skipped.first?.why, .notASetting)
    }
}
