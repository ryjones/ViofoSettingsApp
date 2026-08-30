import XCTest
@testable import ViofoConfig

@MainActor
final class ConfigDocumentTests: XCTestCase {

    private let sample = """
        [Video Settings]
        # Video Bitrate, 0:Low; 1:Normal; 2:High; 3:Maximum
        Video Bitrate=2
        # G-sensor, 0:Off; 1:Low; 2:Medium; 3:High
        G-sensor=0

        [Stamp]
        # Custom Text Stamp, Maximum length: 11 characters
        Custom Text Stamp=""
        License Plate Number="EXAMPLE"

        """

    /// The whole point of writing this file back is that the camera still reads
    /// it, so an untouched document has to serialize to exactly what came in.
    func testRoundTripIsByteIdentical() throws {
        let doc = ConfigDocument()
        doc.load(text: sample)
        XCTAssertEqual(doc.serialized(), sample)
        XCTAssertFalse(doc.isModified)
    }

    func testEditTouchesOnlyItsOwnLine() throws {
        let doc = ConfigDocument()
        doc.load(text: sample)
        doc.setInt(1, for: "G-sensor")

        XCTAssertTrue(doc.isModified)
        XCTAssertTrue(doc.isChanged("G-sensor"))
        XCTAssertFalse(doc.isChanged("Video Bitrate"))
        XCTAssertEqual(doc.serialized(),
                       sample.replacingOccurrences(of: "G-sensor=0", with: "G-sensor=1"))
        // Every explanatory comment survives the edit.
        XCTAssertTrue(doc.serialized().contains("# G-sensor, 0:Off; 1:Low; 2:Medium; 3:High"))
    }

    func testRevertRestoresTheOriginalText() throws {
        let doc = ConfigDocument()
        doc.load(text: sample)
        doc.setInt(3, for: "Video Bitrate")
        doc.setQuoted("RY", for: "Custom Text Stamp")
        doc.revertAll()
        XCTAssertEqual(doc.serialized(), sample)
        XCTAssertFalse(doc.isModified)
    }

    func testQuotedValuesKeepTheirQuotes() throws {
        let doc = ConfigDocument()
        doc.load(text: sample)
        XCTAssertEqual(ConfigDocument.unquote(doc.value(for: "License Plate Number") ?? ""), "EXAMPLE")
        doc.setQuoted("ABC123", for: "License Plate Number")
        XCTAssertTrue(doc.serialized().contains("License Plate Number=\"ABC123\""))
    }

    func testUnknownKeysArePreservedNotDropped() throws {
        let withFuture = sample + "Some Future Key=7\n"
        let doc = ConfigDocument()
        doc.load(text: withFuture)
        XCTAssertEqual(doc.unknownKeys(knownKeys: Schema.knownKeys), ["Some Future Key"])
        XCTAssertEqual(doc.serialized(), withFuture)
    }

    func testCRLFFilesStayCRLF() throws {
        let crlf = sample.replacingOccurrences(of: "\n", with: "\r\n")
        let doc = ConfigDocument()
        doc.load(text: crlf)
        XCTAssertEqual(doc.serialized(), crlf)
    }
}

@MainActor
final class AdvisoryTests: XCTestCase {

    private func document(_ pairs: [String: String]) -> ConfigDocument {
        let doc = ConfigDocument()
        doc.load(text: pairs.map { "\($0.key)=\($0.value)" }.joined(separator: "\n") + "\n")
        return doc
    }

    func testDisabledGSensorIsReportedAsAGap() {
        let advisories = AdvisoryEngine.evaluate(document(["G-sensor": "0"]))
        XCTAssertTrue(advisories.contains { $0.severity == .gap && $0.keys.contains("G-sensor") })
    }

    func testEnabledGSensorIsNotReported() {
        let advisories = AdvisoryEngine.evaluate(document(["G-sensor": "1"]))
        XCTAssertFalse(advisories.contains { $0.keys.contains("G-sensor") })
    }

    func testRearCameraOutsideTheResolutionModeIsAConflict() {
        let doc = document(["Resolution": "14", "Rear Camera": "1", "Interior Camera": "1"])
        XCTAssertTrue(AdvisoryEngine.evaluate(doc).contains {
            $0.severity == .conflict && $0.title.contains("Rear")
        })
    }

    func testThreeChannelModeCoversBothSecondaryCameras() {
        let doc = document(["Resolution": "33", "Rear Camera": "1", "Interior Camera": "1"])
        XCTAssertFalse(AdvisoryEngine.evaluate(doc).contains { $0.keys.contains("Resolution") })
    }

    func testSixtyFPSWithHDRIsAConflict() {
        let doc = document(["Resolution": "1", "HDR Front": "1"])
        XCTAssertTrue(AdvisoryEngine.evaluate(doc).contains { $0.title.contains("60fps") })
    }

    func testEmptyCustomStampIsAConflict() {
        let doc = document(["Custom Stamp": "1", "Custom Text Stamp": "\"\""])
        XCTAssertTrue(AdvisoryEngine.evaluate(doc).contains { $0.keys.contains("Custom Text Stamp") })
    }

    func testLowPowerParkingModeOverridesSSDStorage() {
        let doc = document(["Parking Mode": "2", "Parking Recording Storage": "1"])
        XCTAssertTrue(AdvisoryEngine.evaluate(doc).contains {
            $0.keys.contains("Parking Recording Storage")
        })
    }

    func testOverlongTextIsFlagged() {
        let doc = document(["License Plate Number": "\"THIS-IS-FAR-TOO-LONG\""])
        XCTAssertTrue(AdvisoryEngine.evaluate(doc).contains { $0.title.contains("longer than") })
    }

    func testEveryOptionCodeIsUnique() {
        for spec in Schema.allSettings {
            let codes = spec.options.map(\.raw)
            XCTAssertEqual(codes.count, Set(codes).count, "duplicate code in \(spec.key)")
        }
    }

    func testEveryKeyInTheRealExportIsExplained() throws {
        let doc = try Fixture.realExport()
        XCTAssertEqual(doc.unknownKeys(knownKeys: Schema.knownKeys), [],
                       "the schema has no entry for these keys")
    }
}

/// A real A329S export, kept byte-faithful to what the camera writes so the
/// parser is exercised against genuine output. Only the license plate is
/// altered; see Fixtures/README.md.
@MainActor
enum Fixture {
    static let placeholderPlate = "EXAMPLE"

    static func url() throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: "viofo_config",
                                        withExtension: "ini",
                                        subdirectory: "Fixtures"),
                      "fixture missing from the test bundle")
    }

    static func realExport() throws -> ConfigDocument {
        let doc = ConfigDocument()
        try doc.load(from: try url())
        return doc
    }
}

@MainActor
final class RealExportTests: XCTestCase {

    /// The fixture is only safe to ship because it carries no real plate. If a
    /// live export is ever copied in here, this is what catches it.
    func testFixtureCarriesNoRealPlate() throws {
        let doc = try Fixture.realExport()
        XCTAssertEqual(ConfigDocument.unquote(doc.value(for: "License Plate Number") ?? ""),
                       Fixture.placeholderPlate)
        for key in ["Custom Text Stamp", "STA mode SSID", "STA mode password"] {
            XCTAssertEqual(ConfigDocument.unquote(doc.value(for: key) ?? ""), "",
                           "\(key) should be empty in a shipped fixture")
        }
    }

    /// The camera has to still read a file this app has written, so a real
    /// export must survive a load and save untouched.
    func testRealExportRoundTripsByteIdentical() throws {
        let original = try String(contentsOf: try Fixture.url(), encoding: .utf8)
        let doc = try Fixture.realExport()
        XCTAssertEqual(doc.serialized(), original)
        XCTAssertFalse(doc.isModified)
    }

    func testRealExportParsesEveryKey() throws {
        let doc = try Fixture.realExport()
        // 81 keys across the 11 sections the firmware writes.
        XCTAssertEqual(doc.currentValues.count, 81)
        XCTAssertEqual(doc.missingKeys(knownKeys: Schema.allSettings.map(\.key)), [])
    }

    func testEditingTheRealExportChangesOneLineOnly() throws {
        let original = try String(contentsOf: try Fixture.url(), encoding: .utf8)
        let doc = try Fixture.realExport()
        doc.setInt(1, for: "G-sensor")
        let changed = doc.serialized()

        let before = original.components(separatedBy: "\n")
        let after = changed.components(separatedBy: "\n")
        XCTAssertEqual(before.count, after.count)
        let differing = zip(before, after).filter { $0 != $1 }
        XCTAssertEqual(differing.count, 1)
        XCTAssertEqual(differing.first?.1, "G-sensor=1")
    }

    func testAdvisoriesRunAgainstTheRealExport() throws {
        let doc = try Fixture.realExport()
        let advisories = AdvisoryEngine.evaluate(doc)
        // Whatever else it finds, it must not invent unknown-key noise.
        XCTAssertFalse(advisories.contains { $0.title.contains("not in this app") })
        XCTAssertFalse(Digest.headline(doc).isEmpty)
        XCTAssertFalse(Digest.markdownReport(doc).isEmpty)
    }
}
