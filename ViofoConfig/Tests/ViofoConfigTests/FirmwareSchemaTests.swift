import XCTest
@testable import ViofoConfig

/// Cross-checks the hand-written schema against ground truth extracted from the
/// camera firmware itself.
///
/// `Fixtures/firmware-schema.json` is generated from the settings descriptor
/// table in `cardv` (`.data:0x110dc20`) — the same table the camera walks when
/// it writes `viofo_config.ini`. The schema in `Sources/` is written from the
/// user manual. Where the two disagree, the firmware is right about what the
/// file contains and the manual is right about what it means, so these tests
/// guard structure and value codes, not wording.
///
/// Provenance and the extraction method are documented in the firmware project:
/// https://github.com/ryjones/ViofoFirmwareThingy — see `cardv-re.md`.
final class FirmwareSchemaTests: XCTestCase {

    struct FirmwareOption: Decodable { let value: Int; let label: String }
    struct FirmwareSetting: Decodable {
        let key: String
        let section: String
        let order: Int
        let type: String
        let id: Int?
        let help: String
        let options: [FirmwareOption]?
        let bufferLength: Int?
        let maxLength: Int?

        enum CodingKeys: String, CodingKey {
            case key, section, order, type, id, help, options
            case bufferLength = "buffer_length"
            case maxLength = "max_length"
        }
    }
    struct FirmwareSchema: Decodable {
        let firmware: String
        let settings: [FirmwareSetting]
    }

    private static func firmwareSchema() throws -> FirmwareSchema {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "firmware-schema", withExtension: "json", subdirectory: "Fixtures"),
            "firmware-schema.json fixture missing"
        )
        return try JSONDecoder().decode(FirmwareSchema.self, from: Data(contentsOf: url))
    }

    func testKeySetMatchesFirmware() throws {
        let fw = try Self.firmwareSchema()
        let firmwareKeys = Set(fw.settings.map(\.key))
        let schemaKeys = Schema.knownKeys
        XCTAssertEqual(
            firmwareKeys.subtracting(schemaKeys), [],
            "keys the firmware exports but the schema does not describe"
        )
        XCTAssertEqual(
            schemaKeys.subtracting(firmwareKeys), [],
            "keys the schema describes but this firmware does not export"
        )
    }

    func testSectionsMatchFirmware() throws {
        let fw = try Self.firmwareSchema()
        for entry in fw.settings {
            guard let spec = Schema.setting(entry.key) else { continue }
            XCTAssertEqual(spec.section, entry.section, "section for \(entry.key)")
        }
    }

    func testOrderMatchesFirmware() throws {
        let fw = try Self.firmwareSchema()
        let firmwareOrder = fw.settings.sorted { $0.order < $1.order }.map(\.key)
        let schemaOrder = Schema.allSettings.map(\.key)
        XCTAssertEqual(schemaOrder, firmwareOrder, "settings must be listed in the order the camera writes them")
    }

    func testValueKindsMatchFirmware() throws {
        let fw = try Self.firmwareSchema()
        for entry in fw.settings {
            guard let spec = Schema.setting(entry.key) else { continue }
            switch (entry.type, spec.kind) {
            case ("int", .options): break
            case ("time", .time): break
            case ("text", .text(let maxLength)):
                // The firmware allocates a larger buffer than it advertises;
                // the schema's cap should match the documented one, and must
                // leave room for the terminator inside the real buffer.
                XCTAssertEqual(maxLength, entry.maxLength, "documented max length for \(entry.key)")
                if let buffer = entry.bufferLength {
                    XCTAssertLessThan(maxLength, buffer, "\(entry.key) must fit its \(buffer)-byte buffer")
                }
            default:
                XCTFail("\(entry.key): firmware says \(entry.type), schema says \(spec.kind)")
            }
        }
    }

    func testOptionCodesMatchFirmware() throws {
        let fw = try Self.firmwareSchema()
        for entry in fw.settings {
            guard let options = entry.options, let spec = Schema.setting(entry.key) else { continue }
            let firmwareValues = Set(options.map(\.value))
            let schemaValues = Set(spec.options.map(\.raw))
            XCTAssertEqual(
                schemaValues.subtracting(firmwareValues), [],
                "\(entry.key): schema offers codes the firmware does not accept"
            )
            XCTAssertEqual(
                firmwareValues.subtracting(schemaValues), [],
                "\(entry.key): firmware accepts codes the schema does not offer"
            )
        }
    }
}
