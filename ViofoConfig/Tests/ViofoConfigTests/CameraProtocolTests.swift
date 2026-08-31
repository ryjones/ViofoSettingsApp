import XCTest
@testable import ViofoConfig

/// The wire format was observed on an A329S running VIOFO_A329S_V2.2_260815.
/// `Fixtures/camera-3014.xml` reproduces its shape with invented values — a real
/// capture carries the owner's settings and licence plate.
final class CameraProtocolTests: XCTestCase {

    private func fixture() throws -> String {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "camera-3014", withExtension: "xml", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// cmd=3014 is a flat stream: <Cmd> and <Status> alternate at one level and
    /// only string-valued settings get their own <Function> wrapper. Parsing by
    /// element nesting loses nearly everything.
    func testParsesFlatTokenStream() throws {
        let values = CameraProtocol.parseValues(try fixture())
        XCTAssertEqual(values[2003], "5")
        XCTAssertEqual(values[2007], "1")
        XCTAssertEqual(values[8200], "2")
        XCTAssertEqual(values[9352], "1")
    }

    /// A <String> supersedes the <Status> for the same command; that is how
    /// multi-channel settings arrive, e.g. exposure as "6,6,6".
    func testStringSupersedesStatus() throws {
        let values = CameraProtocol.parseValues(try fixture())
        XCTAssertEqual(values[8220], "6,6,6")
    }

    /// Some values are not integers at all: resolution comes back as a packed
    /// front/rear pair, which is why nothing here parses values as Int.
    func testNonIntegerValuesSurvive() throws {
        XCTAssertEqual(CameraProtocol.parseValues(try fixture())[8222], "2,7")
    }

    func testFirmwareVersionExtraction() {
        let xml = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <Function><Cmd>3012</Cmd><Status>0</Status>
            <String>VIOFO_A329S_V2.2_260815</String></Function>
            """
        XCTAssertEqual(CameraProtocol.firmwareVersion(xml), "VIOFO_A329S_V2.2_260815")
    }

    func testWriteSuccessDetection() {
        XCTAssertTrue(CameraProtocol.writeSucceeded(
            "<Function><Cmd>8214</Cmd><Status>0</Status></Function>"))
    }

    func testURLShape() throws {
        let url = try XCTUnwrap(CameraProtocol.url(host: CameraProtocol.defaultHost, cmd: 8214, par: 1))
        XCTAssertEqual(url.absoluteString, "http://192.168.1.254/?custom=1&cmd=8214&par=1")
    }

    /// Formatting the card and resetting the camera must never be reachable.
    func testDestructiveCommandsAreListed() {
        for cmd in [3010, 3011, 9316, 9317] {
            XCTAssertTrue(CameraProtocol.destructive.contains(cmd), "cmd \(cmd) must be refused")
        }
    }

    /// 93 settings: every dispatch-table row with a non-zero setting id, which is
    /// exactly what cmd=3014 reports. See docs/camera-http-api.md section 5.
    func testCatalogLoads() {
        XCTAssertEqual(CameraCommandCatalog.all.count, 93)
        XCTAssertEqual(CameraCommandCatalog.command(2011)?.key, "CMD_SET_G_SENSOR")
        XCTAssertEqual(CameraCommandCatalog.command(2011)?.label(for: "1"), "Low")
        // Adjacent Bluetooth key bindings that a name-matching heuristic
        // conflated; see docs/camera-http-api.md section 6.
        XCTAssertEqual(CameraCommandCatalog.command(9313)?.key, "CMD_BLUETOOTH_KEY_AUDIO_RECORD")
        XCTAssertEqual(CameraCommandCatalog.command(9314)?.key, "CMD_BLUETOOTH_KEY_ACTION")
    }

    /// 8220 is exposure for all three cameras at once, which is why its value
    /// arrives as "6,6,6" rather than an integer.
    func testMultiplexedCommandsKeepTheirAliases() {
        let exposure = CameraCommandCatalog.command(8220)
        XCTAssertTrue(exposure?.carriesMultipleSettings == true)
        XCTAssertEqual(exposure?.aliases?.count, 2)
    }

    /// Where the camera exports a setting to viofo_config.ini, that key is the
    /// clearest name for it, so it wins over VIOFO's CMD_ constant.
    func testTitlePrefersTheIniKey() {
        XCTAssertEqual(CameraCommandCatalog.command(2003)?.title, "Loop Recording")
    }

    /// A setting the camera does not export to the ini falls back to the
    /// humanised VIOFO name, and one VIOFO does not describe either falls back
    /// to the firmware handler.
    func testTitleFallsBackWhenThereIsNoIniKey() {
        XCTAssertNil(CameraCommandCatalog.command(2004)?.iniKeys)
        XCTAssertEqual(CameraCommandCatalog.command(2004)?.title, "Set Hdr")
        XCTAssertEqual(CameraCommandCatalog.command(2001)?.title, "Movie Rec")
    }

    /// And with no title at all, CameraCommand humanises the key itself.
    func testTitleHumanisesTheKeyWhenUntitled() throws {
        let json = #"{"cmd": 2003, "key": "CMD_SET_LOOP_REC"}"#
        let c = try JSONDecoder().decode(CameraCommand.self, from: Data(json.utf8))
        XCTAssertEqual(c.title, "Set Loop Rec")
    }

    /// The setting id is the bridge between the HTTP API and viofo_config.ini,
    /// read out of the firmware dispatch table rather than matched by name.
    func testSettingIdsBridgeToTheIni() {
        let resolution = CameraCommandCatalog.command(8222)
        XCTAssertEqual(resolution?.settingID, 0x1a)
        XCTAssertEqual(resolution?.iniKeys?.first, "Resolution")

        // Two commands, one setting: both carry 0x11, Live Video Source.
        XCTAssertEqual(CameraCommandCatalog.command(3028)?.settingID, 0x11)
        XCTAssertEqual(CameraCommandCatalog.command(8202)?.settingID, 0x11)
    }

    /// The 22 commands VIOFO's database does not describe are named from the
    /// firmware now, so nothing a live camera reports shows up as unrecognised.
    func testCommandsAbsentFromViofosDatabaseAreStillNamed() {
        for cmd in [2001, 2012, 3028, 8216, 9341, 9353, 9362] {
            XCTAssertNotNil(CameraCommandCatalog.command(cmd), "cmd \(cmd) should be known")
        }
        XCTAssertEqual(CameraCommandCatalog.command(9341)?.title, "Hybrid Parking mode")
        XCTAssertEqual(CameraCommandCatalog.command(2012)?.handler,
                       "WiFiCmd_OnExeSetAutoRecording")
    }

    /// Neither is a trigger: both are set_setting() toggles, and turning 9352 off
    /// stops the camera writing viofo_config.ini at all.
    func testExportAndImportSettingsAreFlaggedForCaution() {
        XCTAssertTrue(CameraCommandCatalog.isCautioned(9352))
        XCTAssertTrue(CameraCommandCatalog.isCautioned(9353))
        XCTAssertFalse(CameraCommandCatalog.isCautioned(8214))
        XCTAssertNotNil(CameraCommandCatalog.cautionNote)
    }

    /// Actions and getters are not settings and are deliberately absent: the
    /// catalogue is only what cmd=3014 can report.
    func testActionCommandsAreNotInTheSettingsCatalogue() {
        for cmd in [3002, 3010, 3011, 3026, 8230, 9316, 9317] {
            XCTAssertNil(CameraCommandCatalog.command(cmd),
                         "cmd \(cmd) is an action, not a setting")
        }
    }
}
