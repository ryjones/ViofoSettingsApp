import Foundation

/// The bundled description of every key the A329S firmware exports, with the
/// explanation taken from the A329S Series user manual V26.01.09.
enum Schema {

    static let sections: [SectionSpec] = [
        videoSettings,
        parkingRecording,
        hdr,
        exposureValue,
        stamp,
        imageRotateMirror,
        systemSettings,
        bluetoothButtons,
        led,
        parkingModeLED,
        wifiStationMode,
    ]

    static let allSettings: [SettingSpec] = sections.flatMap(\.settings)

    static let byKey: [String: SettingSpec] = {
        Dictionary(uniqueKeysWithValues: allSettings.map { ($0.key, $0) })
    }()

    static let knownKeys: Set<String> = Set(allSettings.map(\.key))

    static func setting(_ key: String) -> SettingSpec? { byKey[key] }

    /// About the file itself, shown on the welcome screen.
    static let aboutFile = """
        The camera writes viofo_config.ini to the root of the microSD card when \
        you remove the card, provided System Settings ▸ Export Settings is On. \
        The manual (p.65) presents it as a read-out you open with VIOFO's \
        configuration tool to review the camera's current settings — it does not \
        document loading an edited file back into the camera. Treat saved changes \
        as a record of what you intend to set on the camera, and verify on the \
        device itself.
        """

    // Reusable option lists.
    static let offOn: [SettingOption] = [
        SettingOption(raw: 0, label: "Off"),
        SettingOption(raw: 1, label: "On"),
    ]

    static let cameraAvailability: [SettingOption] = [
        SettingOption(raw: 0, label: "Off"),
        SettingOption(raw: 1, label: "On"),
        SettingOption(raw: 2, label: "Only On while Driving"),
        SettingOption(raw: 3, label: "Only On while Parking"),
    ]

    static let sensitivity: [SettingOption] = [
        SettingOption(raw: 1, label: "Low"),
        SettingOption(raw: 2, label: "Medium"),
        SettingOption(raw: 3, label: "High"),
    ]

    static let exposureValues: [SettingOption] = [
        SettingOption(raw: 0,  label: "+2.0"),
        SettingOption(raw: 1,  label: "+1.6"),
        SettingOption(raw: 2,  label: "+1.3"),
        SettingOption(raw: 3,  label: "+1.0"),
        SettingOption(raw: 4,  label: "+0.6"),
        SettingOption(raw: 5,  label: "+0.3"),
        SettingOption(raw: 6,  label: "+0.0", note: "default"),
        SettingOption(raw: 7,  label: "-0.3"),
        SettingOption(raw: 8,  label: "-0.6"),
        SettingOption(raw: 9,  label: "-1.0"),
        SettingOption(raw: 10, label: "-1.3"),
        SettingOption(raw: 11, label: "-1.6"),
        SettingOption(raw: 12, label: "-2.0"),
    ]

    static let hdrModes: [SettingOption] = [
        SettingOption(raw: 0, label: "Off"),
        SettingOption(raw: 1, label: "On", note: "default"),
        SettingOption(raw: 2, label: "Auto HDR Timer"),
    ]

    /// The Bluetooth remote codes differ between the two buttons: on the Mic
    /// button 2 is the microphone toggle, on the Action button 2 is Wi-Fi.
    static func bluetoothOptions(primary: String, secondary: String) -> [SettingOption] {
        [
            SettingOption(raw: 2,  label: primary),
            SettingOption(raw: 3,  label: "Take a Photo"),
            SettingOption(raw: 4,  label: secondary),
            SettingOption(raw: 5,  label: "Power Off"),
            SettingOption(raw: 6,  label: "Switch to Timelapse Recording"),
            SettingOption(raw: 7,  label: "Turn On / Off HDR"),
            SettingOption(raw: 8,  label: "Parking Mode"),
            SettingOption(raw: 9,  label: "Turn On / Off Rear Cam"),
            SettingOption(raw: 10, label: "Turn On / Off Interior Cam"),
            SettingOption(raw: 11, label: "Wi-Fi Station Mode"),
            SettingOption(raw: 12, label: "Switch Live Video Source"),
        ]
    }
}
