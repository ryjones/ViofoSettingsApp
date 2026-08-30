import Foundation

/// One entry of the Resolution table, kept structured so the advisory checks can
/// reason about how many channels a mode actually records.
struct ResolutionMode: Identifiable {
    let raw: Int
    let label: String
    let detail: String
    /// Camera roles the mode records, in order.
    let roles: [CameraRole]

    var id: Int { raw }
    var channels: Int { roles.count }
}

enum CameraRole: String, CaseIterable {
    case front = "Front"
    case interior = "Interior"
    case rear = "Rear"
    case telephoto = "Front Tele"
}

extension Schema {

    static let resolutionModes: [ResolutionMode] = [
        .init(raw: 1,  label: "4K 60fps",                    detail: "3840x2160P 60fps", roles: [.front]),
        .init(raw: 2,  label: "4K 21:9 60fps",               detail: "3840x1600 60fps",  roles: [.front]),
        .init(raw: 3,  label: "4K 30fps",                    detail: "3840x2160P 30fps", roles: [.front]),
        .init(raw: 4,  label: "4K 21:9 30fps",               detail: "3840x1600 30fps",  roles: [.front]),
        .init(raw: 5,  label: "2K 60fps",                    detail: "2560x1440P 60fps", roles: [.front]),
        .init(raw: 7,  label: "2K 30fps",                    detail: "2560x1440P 30fps", roles: [.front]),
        .init(raw: 10, label: "1080P30",                     detail: "1920x1080 30fps",  roles: [.front]),
        .init(raw: 11, label: "4K P60 + 2K P30",             detail: "3840x2160P 60fps + 2560x1440P 30fps", roles: [.front, .interior]),
        .init(raw: 12, label: "4K P60 21:9 + 2K 21:9",       detail: "3840x1600 60fps + 2560x1080 30fps",   roles: [.front, .interior]),
        .init(raw: 13, label: "4K P60 21:9 + 2K 16:9",       detail: "3840x1600 60fps + 2560x1440 30fps",   roles: [.front, .interior]),
        .init(raw: 14, label: "4K P30 + 2K P30",             detail: "3840x2160P 30fps + 2560x1440P 30fps", roles: [.front, .interior]),
        .init(raw: 15, label: "4K 21:9 + 2K 21:9",           detail: "3840x1600 30fps + 2560x1080 30fps",   roles: [.front, .interior]),
        .init(raw: 16, label: "4K 21:9 + 2K 16:9",           detail: "3840x1600 30fps + 2560x1440 30fps",   roles: [.front, .interior]),
        .init(raw: 17, label: "2K P60 + 2K P30",             detail: "2560x1440P 60fps + 2560x1440P 30fps", roles: [.front, .interior]),
        .init(raw: 18, label: "2K P30 + 2K P30",             detail: "2560x1440P 30fps + 2560x1440P 30fps", roles: [.front, .interior]),
        .init(raw: 21, label: "1080 P30 + 1080 P30",         detail: "1920x1080 30fps + 1920x1080 30fps",   roles: [.front, .interior]),
        .init(raw: 22, label: "4K P60 + 2K P30",             detail: "3840x2160P 60fps + 2560x1440P 30fps", roles: [.front, .rear]),
        .init(raw: 23, label: "4K P60 21:9 + 2K 21:9",       detail: "3840x1600 60fps + 2560x1080 30fps",   roles: [.front, .rear]),
        .init(raw: 24, label: "4K P60 21:9 + 2K 16:9",       detail: "3840x1600 60fps + 2560x1440P 30fps",  roles: [.front, .telephoto]),
        .init(raw: 25, label: "4K P30 + 2K P30",             detail: "3840x2160P 30fps + 2560x1440P 30fps", roles: [.front, .rear]),
        .init(raw: 26, label: "4K 21:9 + 2K 21:9",           detail: "3840x1600 30fps + 2560x1080 30fps",   roles: [.front, .rear]),
        .init(raw: 27, label: "4K 21:9 30fps + 2K 30fps 16:9", detail: "3840x1600 30fps + 2560x1440P 30fps", roles: [.front, .telephoto]),
        .init(raw: 28, label: "2K P60 + 2K P30",             detail: "2560x1440P 60fps + 2560x1440P 30fps", roles: [.front, .rear]),
        .init(raw: 29, label: "2K P30 + 2K P30",             detail: "2560x1440P 30fps + 2560x1440P 30fps", roles: [.front, .rear]),
        .init(raw: 32, label: "1080 P30 + 1080 P30",         detail: "1920x1080 30fps + 1920x1080 30fps",   roles: [.front, .rear]),
        .init(raw: 33, label: "4K P30 + 2K P30 + 2K P30",    detail: "3840x2160 30fps + 2560x1440 30fps + 2560x1440 30fps", roles: [.front, .interior, .rear]),
        .init(raw: 34, label: "4K 21:9 + 2K 21:9 + 2K 21:9", detail: "3840x1600 30fps + 2560x1080 30fps + 2560x1080 30fps", roles: [.front, .interior, .rear]),
        .init(raw: 35, label: "4K 21:9 + 2K 16:9 + 2K 16:9", detail: "3840x1600 30fps + 2560x1440 30fps + 2560x1440 30fps", roles: [.front, .telephoto, .rear]),
        .init(raw: 36, label: "2K P30 + 2K P30 + 2K P30",    detail: "2560x1440 30fps + 2560x1440 30fps + 2560x1440 30fps", roles: [.front, .interior, .rear]),
        .init(raw: 37, label: "1080 P30 + 1080 P30 + 1080 P30", detail: "1920x1080 30fps + 1920x1080 30fps + 1920x1080 30fps", roles: [.front, .interior, .rear]),
    ]

    static func resolutionMode(for raw: Int) -> ResolutionMode? {
        resolutionModes.first { $0.raw == raw }
    }

    static let videoSettings = SectionSpec(
        name: "Video Settings",
        blurb: "What the camera records while you are driving: channels, quality, clip length and the sensors that lock a file.",
        settings: [
            SettingSpec(
                key: "Resolution",
                section: "Video Settings",
                title: "Resolution",
                kind: .options(resolutionModes.map {
                    SettingOption(
                        raw: $0.raw,
                        label: "\($0.label) — \($0.roles.map(\.rawValue).joined(separator: " + "))",
                        note: $0.detail
                    )
                }),
                summary: "Frame size and rate for every recording channel.",
                manual: """
                    4K is 3840x2160P and 2K is 2560x1440P; the 21:9 variants are \
                    3840x1600P and 2560x1080P. The list is grouped into 1-, 2- and \
                    3-channel modes, and the mode you pick has to match the cameras \
                    you actually have connected.

                    4K 60fps is available only when HDR is disabled.
                    """,
                manualRef: "p.41–42"
            ),
            SettingSpec(
                key: "Video Bitrate",
                section: "Video Settings",
                title: "Video Bitrate",
                kind: .options([
                    SettingOption(raw: 0, label: "Low"),
                    SettingOption(raw: 1, label: "Normal"),
                    SettingOption(raw: 2, label: "High"),
                    SettingOption(raw: 3, label: "Maximum"),
                ]),
                summary: "Data rate, trading recording time against image quality.",
                manual: """
                    A high bitrate improves the quality and smoothness of the video, \
                    especially when recording fast motion or high contrast scenes, but \
                    it decreases the amount of recording time available on the memory \
                    card. A low bitrate saves space and records for longer.
                    """,
                manualRef: "p.42"
            ),
            SettingSpec(
                key: "Dewarp Front Cam",
                section: "Video Settings",
                title: "Dewarp Front Cam",
                kind: .options(offOn),
                summary: "Straightens the barrel distortion of the wide front lens.",
                manual: """
                    Exported by the firmware but not described in manual V26.01.09. \
                    From the value list it is a straightforward Off/On correction for \
                    the front camera's wide-angle distortion; verify its effect on the \
                    camera before relying on it.
                    """
            ),
            SettingSpec(
                key: "Loop Recording",
                section: "Video Settings",
                title: "Loop Recording",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "1 Minute"),
                    SettingOption(raw: 2, label: "2 Minutes"),
                    SettingOption(raw: 3, label: "3 Minutes"),
                    SettingOption(raw: 4, label: "5 Minutes"),
                    SettingOption(raw: 5, label: "10 Minutes"),
                ]),
                summary: "Length of each clip before the camera starts a new file.",
                manual: """
                    Recording begins automatically after powering on with a microSD \
                    card in the device. Footage is split into clips of this length, and \
                    the oldest footage is replaced once the card is full. Shorter clips \
                    mean less data lost if a single file is corrupted; longer clips mean \
                    fewer files to manage.
                    """,
                manualRef: "p.42"
            ),
            SettingSpec(
                key: "Record Audio",
                section: "Video Settings",
                title: "Record Audio",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "On"),
                    SettingOption(raw: 2, label: "Only On while Parking"),
                ]),
                summary: "Cabin microphone.",
                manual: """
                    Turns the microphone on and off. This can also be changed during \
                    recording by pressing the microphone button on the camera, or from \
                    the Bluetooth remote if a button is mapped to it.
                    """,
                manualRef: "p.43"
            ),
            SettingSpec(
                key: "G-sensor",
                section: "Video Settings",
                title: "G-sensor",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "Low", note: "manual's recommendation"),
                    SettingOption(raw: 2, label: "Medium"),
                    SettingOption(raw: 3, label: "High"),
                ]),
                summary: "Impact detection while driving — locks the clip against overwrite.",
                manual: """
                    The G-sensor measures shock forces and locks the video recorded at \
                    that moment, moving it to DCIM\\Movie\\RO where loop recording will \
                    not overwrite it. The settings from low to high determine how much \
                    force is needed to lock the file. The manual recommends Low: a higher \
                    setting needs a harder hit, and Off means nothing is ever locked \
                    automatically.
                    """,
                manualRef: "p.43"
            ),
            SettingSpec(
                key: "Time-lapse Recording",
                section: "Video Settings",
                title: "Time-lapse Recording",
                kind: .options([
                    SettingOption(raw: 0, label: "Off", note: "default"),
                    SettingOption(raw: 1, label: "Timelapse 1 fps"),
                    SettingOption(raw: 2, label: "Timelapse 2 fps"),
                    SettingOption(raw: 3, label: "Timelapse 3 fps"),
                    SettingOption(raw: 4, label: "Timelapse 5 fps"),
                    SettingOption(raw: 5, label: "Timelapse 10 fps"),
                ]),
                summary: "Timelapse while driving — separate from the parking timelapse modes.",
                manual: """
                    Records video from frames captured at fixed intervals, to conserve \
                    memory and reduce the time it takes to review footage. Default is Off. \
                    This is the driving-mode timelapse; parking timelapse is set \
                    separately under Parking Recording.
                    """,
                manualRef: "p.44"
            ),
            SettingSpec(
                key: "Interior Cam Fisheye Mode",
                section: "Video Settings",
                title: "Interior Cam Fisheye Mode",
                kind: .options(offOn),
                summary: "Keeps the cabin camera's circular fisheye view instead of a corrected one.",
                manual: """
                    Enables or disables the fisheye view for interior camera recording. \
                    Only available on the fisheye cabin camera edition.
                    """,
                manualRef: "p.44",
                requires: "Infrared fisheye cabin camera"
            ),
            SettingSpec(
                key: "IR LED",
                section: "Video Settings",
                title: "IR LED",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "On", note: "always on, video is B&W"),
                    SettingOption(raw: 2, label: "Auto"),
                ]),
                summary: "Infrared illuminators on the cabin camera.",
                manual: """
                    On means the IR lights are always on, so the video is black and \
                    white. Auto lets the camera decide when to switch the infrared lights \
                    on based on the light level. Off keeps them all off. Only available on \
                    the fisheye cabin camera edition.
                    """,
                manualRef: "p.44",
                requires: "Infrared fisheye cabin camera"
            ),
            SettingSpec(
                key: "Interior Camera",
                section: "Video Settings",
                title: "Interior Camera",
                kind: .options(cameraAvailability),
                summary: "When the cabin camera records.",
                manual: """
                    Enables or disables the fisheye cabin camera, either entirely or only \
                    under driving or parking mode. Only available on the fisheye cabin \
                    camera edition.
                    """,
                manualRef: "p.57",
                requires: "Infrared fisheye cabin camera"
            ),
            SettingSpec(
                key: "Rear Camera",
                section: "Video Settings",
                title: "Rear Camera",
                kind: .options(cameraAvailability),
                summary: "When the rear camera records.",
                manual: """
                    Enables or disables the rear camera, either entirely or only under \
                    driving or parking mode. The equivalent Front Tele Camera setting \
                    appears instead on the telephoto edition.
                    """,
                manualRef: "p.57"
            ),
            SettingSpec(
                key: "Multiplex Video",
                section: "Video Settings",
                title: "Multiplex Video",
                kind: .options([
                    SettingOption(raw: 0, label: "Off", note: "one file per camera"),
                    SettingOption(raw: 1, label: "Front + Interior"),
                    SettingOption(raw: 2, label: "Front + Rear"),
                    SettingOption(raw: 3, label: "Front + Interior + Rear"),
                ]),
                summary: "Composites several channels into one picture-in-picture file.",
                manual: """
                    Chooses which channels are combined into a single multiplexed \
                    recording. With it Off, each camera writes its own file, distinguished \
                    by the suffix in the filename: F front, R rear, I interior, T telephoto. \
                    Multiplexed files are easier to review but you lose the full resolution \
                    of the secondary channels.

                    The option names change per edition: the telephoto edition offers \
                    Front + Telephoto, and the dual-waterproof edition offers Exterior \
                    Cam 1 and 2.
                    """,
                manualRef: "p.58"
            ),
            SettingSpec(
                key: "Live Video Source",
                section: "Video Settings",
                title: "Live Video Source",
                kind: .options([
                    SettingOption(raw: 8,  label: "Front Camera"),
                    SettingOption(raw: 9,  label: "Interior Camera"),
                    SettingOption(raw: 10, label: "Rear Camera"),
                    SettingOption(raw: 12, label: "Rear Overlaid"),
                    SettingOption(raw: 13, label: "Front Overlaid"),
                    SettingOption(raw: 14, label: "All Camera"),
                ]),
                summary: "Which camera the LCD and app preview show.",
                manual: """
                    Selects the picture shown on the camera screen and in the VIOFO app \
                    live view. This affects the preview only, not what is recorded. It can \
                    also be cycled with a single press of the Wi-Fi button while recording.
                    """,
                manualRef: "p.59"
            ),
            SettingSpec(
                key: "Privacy Mode",
                section: "Video Settings",
                title: "Privacy Mode",
                kind: .options(offOn),
                summary: "Keeps only the last handful of clips on the card.",
                manual: """
                    When privacy mode is on, the dashcam keeps only the most recent 2 \
                    normally-recorded files on a single-channel camera, 4 on a dual-channel \
                    camera, or 6 on a 3-channel camera. Loop recording is also forced to \
                    1-minute clips while it is enabled.
                    """,
                manualRef: "p.59"
            ),
        ]
    )
}
