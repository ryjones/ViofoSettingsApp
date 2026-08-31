import Foundation

extension Schema {

    static let parkingRecording = SectionSpec(
        name: "Parking Recording",
        blurb: "What happens after the engine is off. Everything here depends on Parking Mode being enabled, and most of it on a hardwire kit or battery pack supplying power.",
        settings: [
            SettingSpec(
                key: "Vehicle Battery Protection",
                section: "Parking Recording",
                title: "Vehicle Battery Protection",
                kind: .options([
                    SettingOption(raw: 0, label: "Cut-off time"),
                    SettingOption(raw: 1, label: "Cut-off Voltage", note: "HK6 required"),
                    SettingOption(raw: 2, label: "Cut-off BP100 Capacity"),
                ]),
                summary: "Which of the three cut-off measures is armed.",
                manual: """
                    After entering parking mode, Vehicle Battery Protection optimises the \
                    use of battery power to achieve a longer period of protection before \
                    the hardwire kit's low-voltage protection is activated. This key \
                    selects which measure is used; the corresponding Cut-off setting below \
                    then sets the threshold.

                    If both cut-off time and voltage are Off, parking recording continues \
                    normally until the hardwire kit cuts the power.
                    """,
                manualRef: "p.45, 51–52"
            ),
            SettingSpec(
                key: "Cut-off time",
                section: "Parking Recording",
                title: "Cut-off time",
                kind: .options([
                    SettingOption(raw: 0,  label: "Off"),
                    SettingOption(raw: 1,  label: "30 Minutes"),
                    SettingOption(raw: 2,  label: "1 Hour"),
                    SettingOption(raw: 3,  label: "2 Hours"),
                    SettingOption(raw: 4,  label: "3 Hours"),
                    SettingOption(raw: 5,  label: "4 Hours"),
                    SettingOption(raw: 6,  label: "6 Hours"),
                    SettingOption(raw: 7,  label: "8 Hours"),
                    SettingOption(raw: 8,  label: "12 Hours"),
                    SettingOption(raw: 9,  label: "24 Hours"),
                    SettingOption(raw: 10, label: "48 Hours"),
                ]),
                summary: "How long parking recording runs before shutting down or downshifting.",
                manual: """
                    Sets the time at which the hardwire kit cuts power. Off means the \
                    camera keeps recording until the hardwire kit does so on its own. \
                    "30 Minutes" means the camera shuts down 30 minutes after entering \
                    parking mode.

                    In normal parking modes the camera stops recording and powers off \
                    until the vehicle is restarted. In hybrid parking mode this is instead \
                    the moment the camera switches to Low Power Impact Detection, which \
                    gives a much longer period of protection.
                    """,
                manualRef: "p.45, 51"
            ),
            SettingSpec(
                key: "Cut-off Voltage",
                section: "Parking Recording",
                title: "Cut-off Voltage",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "12.4V / 24.8V"),
                    SettingOption(raw: 2, label: "12.2V / 24.4V"),
                    SettingOption(raw: 3, label: "12.0V / 24.0V"),
                ]),
                summary: "Battery voltage floor at which parking recording stops or downshifts.",
                manual: """
                    Sets the voltage at which the hardwire kit cuts power, given for 12V \
                    and 24V vehicles. In normal parking modes, if the battery drops below \
                    this value the camera stops recording and powers off until the vehicle \
                    is restarted. In hybrid parking mode it switches to Low Power Impact \
                    Detection instead and keeps going until the kit's own protection trips.

                    A higher threshold protects the starting battery more aggressively; a \
                    lower one buys more surveillance time.
                    """,
                manualRef: "p.45, 52",
                requires: "VIOFO HK6 ACC hardwire kit"
            ),
            SettingSpec(
                key: "Cut-off BP100 Capacity",
                section: "Parking Recording",
                title: "Cut-off BP100 Capacity",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "5%"),
                    SettingOption(raw: 2, label: "8%"),
                    SettingOption(raw: 3, label: "10%"),
                    SettingOption(raw: 4, label: "15%"),
                ]),
                summary: "State-of-charge floor when running from a BP100 battery pack.",
                manual: """
                    Exported by the firmware but not described in manual V26.01.09. It is \
                    the battery-pack equivalent of the voltage cut-off: parking recording \
                    stops, or in hybrid mode downshifts, once the VIOFO BP100 external \
                    battery falls to the chosen state of charge. Select it with Vehicle \
                    Battery Protection = Cut-off BP100 Capacity.
                    """,
                requires: "VIOFO BP100 battery pack"
            ),
            SettingSpec(
                key: "Parking Mode",
                section: "Parking Recording",
                title: "Parking Mode",
                kind: .options([
                    SettingOption(raw: 0,  label: "Off"),
                    SettingOption(raw: 1,  label: "Hybrid Parking mode"),
                    SettingOption(raw: 2,  label: "Low Power Impact Detection"),
                    SettingOption(raw: 3,  label: "Low Bitrate Recording"),
                    SettingOption(raw: 4,  label: "Auto Event Detection"),
                    SettingOption(raw: 5,  label: "Timelapse 1fps (Night Vision)"),
                    SettingOption(raw: 6,  label: "Timelapse 1 fps"),
                    SettingOption(raw: 7,  label: "Timelapse 2 fps"),
                    SettingOption(raw: 8,  label: "Timelapse 3 fps"),
                    SettingOption(raw: 9,  label: "Timelapse 5 fps"),
                    SettingOption(raw: 10, label: "Timelapse 10 fps"),
                ]),
                summary: "How the camera records once the engine is off. The master switch for this whole section.",
                manual: """
                    Low Power Impact Detection keeps the camera in very low-power \
                    standby; on an impact it wakes in about 2 seconds and records for 1 \
                    minute, extended up to 3 minutes if movement or further impact \
                    continues.

                    Low Bitrate Recording records video and audio continuously at a low \
                    bitrate, maximising how much fits on the storage device.

                    Auto Event Detection starts recording when a moving object is \
                    detected and saves 15 seconds before and 30 seconds after the event.

                    Timelapse records without audio at 1/2/3/5/10 fps. The 1 fps mode \
                    additionally offers Night Vision, which gives a brighter, clearer \
                    picture in extreme low light at lower power consumption.

                    Hybrid Parking Recording combines two of the above: it starts in \
                    timelapse, low bitrate or event detection and switches to impact \
                    detection when the cut-off time or voltage is reached.

                    In hot weather the manual recommends timelapse; above 60°C inside the \
                    car it advises turning the dashcam off entirely to avoid recording \
                    errors or damage.
                    """,
                manualRef: "p.45–56",
                requires: "VIOFO HK4 / HK6 ACC hardwire kit (recommended)"
            ),
            SettingSpec(
                key: "Hybrid Parking mode",
                section: "Parking Recording",
                title: "Hybrid Parking mode",
                kind: .options([
                    SettingOption(raw: 0, label: "Low Bitrate → Impact"),
                    SettingOption(raw: 1, label: "Event Detection → Impact"),
                    SettingOption(raw: 2, label: "Timelapse 1fps (Night Vision) → Impact"),
                    SettingOption(raw: 3, label: "Timelapse 1 fps → Impact"),
                    SettingOption(raw: 4, label: "Timelapse 2 fps → Impact"),
                    SettingOption(raw: 5, label: "Timelapse 3 fps → Impact"),
                    SettingOption(raw: 6, label: "Timelapse 5 fps → Impact"),
                    SettingOption(raw: 7, label: "Timelapse 10 fps → Impact"),
                ]),
                summary: "Which pair of modes hybrid parking runs, first stage then fallback.",
                manual: """
                    Only used when Parking Mode is set to Hybrid. The camera records in \
                    the first mode until the cut-off time or cut-off voltage is reached, \
                    then drops into Low Power Impact Detection and continues until the \
                    hardwire kit's own low-voltage protection cuts power.

                    Example from the manual: with the cut-off time set to 30 minutes and \
                    Timelapse 1fps → Impact selected, the camera records timelapse for 30 \
                    minutes, then switches to impact detection.
                    """,
                manualRef: "p.46, 53–54"
            ),
            SettingSpec(
                key: "Enter Parking Mode Timer",
                section: "Parking Recording",
                title: "Enter Parking Mode Timer",
                kind: .options([
                    SettingOption(raw: 0, label: "Off", note: "enter immediately"),
                    SettingOption(raw: 1, label: "90 Seconds"),
                ]),
                summary: "Delay between engine-off and parking mode starting.",
                manual: """
                    Off means the camera enters parking mode as soon as the engine is off. \
                    90 Seconds delays the switch, which avoids the camera dropping into \
                    parking mode while you are still getting out of the car. Hardwire cable \
                    only — it has no effect when running from an external battery.
                    """,
                manualRef: "p.48, 55",
                requires: "Hardwire kit"
            ),
            SettingSpec(
                key: "Parking G-sensor",
                section: "Parking Recording",
                title: "Parking G-sensor",
                kind: [
                    SettingOption(raw: 1, label: "Low"),
                    SettingOption(raw: 2, label: "Medium"),
                    SettingOption(raw: 3, label: "High", note: "manual's recommendation"),
                ].asOptions,
                summary: "Impact sensitivity while parked.",
                manual: """
                    The G-sensor detects significant or sudden movement such as an impact \
                    or collision and triggers an event recording. The manual suggests High \
                    sensitivity for parking mode.

                    Detected impacts produce protected Event videos in DCIM\\Movie\\RO. \
                    Impacts within 3 minutes of entering or leaving parking mode are \
                    deliberately not recorded as events, to avoid false alerts from things \
                    like a door closing.
                    """,
                manualRef: "p.48–49, 55"
            ),
            SettingSpec(
                key: "Parking Motion Detection",
                section: "Parking Recording",
                title: "Parking Motion Detection",
                kind: [
                    SettingOption(raw: 1, label: "Low", note: "manual's recommendation"),
                    SettingOption(raw: 2, label: "Medium"),
                    SettingOption(raw: 3, label: "High"),
                ].asOptions,
                summary: "Motion sensitivity while parked.",
                manual: """
                    Adjusts the sensitivity of motion detection so that minor movement \
                    caused by wind or rain does not trigger a recording. The manual \
                    suggests Low sensitivity for parking mode.
                    """,
                manualRef: "p.49, 55"
            ),
            SettingSpec(
                key: "Parking GPS",
                section: "Parking Recording",
                title: "Parking GPS",
                kind: .options(offOn),
                summary: "GPS logging while parked.",
                manual: """
                    Turns the GPS logger on or off in parking mode. Turning GPS off \
                    reduces power consumption, resulting in longer battery life — worth \
                    doing, since a parked car is not moving anyway.
                    """,
                manualRef: "p.49, 55"
            ),
            SettingSpec(
                key: "Parking HDR",
                section: "Parking Recording",
                title: "Parking HDR",
                kind: .options(offOn),
                summary: "HDR processing while parked.",
                manual: "Turns HDR on or off in parking mode, independently of the driving-mode HDR settings.",
                manualRef: "p.49, 55"
            ),
            SettingSpec(
                key: "Parking Recording Storage",
                section: "Parking Recording",
                title: "Parking Recording Storage",
                kind: .options([
                    SettingOption(raw: 0, label: "SD"),
                    SettingOption(raw: 1, label: "SSD"),
                    SettingOption(raw: 2, label: "SSD → SD"),
                ]),
                summary: "Where parking clips are written.",
                manual: """
                    Saves parking recordings to the microSD card or an external SSD. Note \
                    the firmware's override: in Low Power Impact Detection and Hybrid \
                    Parking Recording modes, parking files are stored on the microSD card \
                    only, whatever this is set to — the SSD cannot be kept spun up in \
                    low-power standby.

                    Parking files land in DCIM\\Movie\\Parking, with a P in the filename.
                    """,
                manualRef: "p.49, 56"
            ),
            SettingSpec(
                key: "Geofencing",
                section: "Parking Recording",
                title: "Geofencing",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "Zone 1"),
                    SettingOption(raw: 2, label: "Zone 2"),
                    SettingOption(raw: 3, label: "Zone 1 + 2"),
                    SettingOption(raw: 4, label: "Zone 3"),
                    SettingOption(raw: 5, label: "Zone 1 + 3"),
                    SettingOption(raw: 6, label: "Zone 2 + 3"),
                    SettingOption(raw: 7, label: "Zone 1 + 2 + 3"),
                ]),
                summary: "Places where the camera powers off instead of entering parking mode.",
                manual: """
                    Defines up to three areas on the map where parking surveillance is not \
                    required, such as a private garage. When the vehicle enters a \
                    designated zone the dash cam powers off completely instead of entering \
                    parking mode, conserving the vehicle's battery. Outside the zones, or \
                    if the GPS signal is weak or lost, it enters parking mode as usual.

                    The zones themselves are drawn in the VIOFO app; this key only selects \
                    which are active. It needs GPS enabled to work.
                    """,
                manualRef: "p.50"
            ),
            SettingSpec(
                key: "Parking Impact Notification",
                section: "Parking Recording",
                title: "Parking Impact Notification",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "On", note: "default"),
                ]),
                summary: "Tells you at startup that something hit the car while it was parked.",
                manual: """
                    When enabled, the dash cam notifies you on the screen at startup if an \
                    impact was detected while the vehicle was parked. You also get an \
                    audible beep and a voice prompt, if the beep sound and voice \
                    notification settings are themselves enabled. Default: On.
                    """,
                manualRef: "p.50"
            ),
            SettingSpec(
                key: "Backup Impact Parking Videos",
                section: "Parking Recording",
                title: "Backup Impact Parking Videos",
                kind: .options(offOn),
                summary: "Copies parking impact events to the secondary storage device.",
                manual: """
                    Exported by the firmware but not described in manual V26.01.09. The \
                    name and its position beside the storage settings indicate it \
                    duplicates impact-triggered parking clips onto the other storage \
                    device, so an event survives the card being overwritten or failing. \
                    Confirm the behaviour on the camera before depending on it.
                    """
            ),
            SettingSpec(
                key: "Low Power Impact Recording",
                section: "Parking Recording",
                title: "Low Power Impact Recording",
                kind: .options(offOn),
                summary: "Impact wake-up recording during low-power standby.",
                manual: """
                    Exported by the firmware but not described in manual V26.01.09. It \
                    relates to the Low Power Impact Detection behaviour described on p.47: \
                    the camera sits in deep standby, wakes in about 2 seconds on an impact, \
                    records for 1 minute and extends to 3 minutes if movement continues. \
                    Confirm the behaviour on the camera before depending on it.
                    """
            ),
        ]
    )

    static let hdr = SectionSpec(
        name: "HDR",
        blurb: "Multi-exposure high dynamic range, set per camera, plus the night window used by the Auto HDR Timer.",
        settings: [
            SettingSpec(
                key: "HDR Front", section: "HDR", title: "HDR Front",
                kind: .options(hdrModes),
                summary: "HDR for the front camera.",
                manual: """
                    The multi-exposure HDR technique automatically balances the lighting \
                    in over-bright and over-dark areas to avoid over-exposure. HDR can be \
                    set for each camera separately; the default is On.

                    Two constraints: 4K 60fps is only available with HDR disabled, and \
                    when the front camera is set to Auto HDR Timer the other cameras \
                    follow the front camera's timer and cannot be scheduled individually.
                    """,
                manualRef: "p.42"
            ),
            SettingSpec(
                key: "HDR Rear", section: "HDR", title: "HDR Rear",
                kind: .options(hdrModes),
                summary: "HDR for the rear camera.",
                manual: "As HDR Front, applied to the rear channel. When the front camera is set to Auto HDR Timer, this follows the front camera's schedule.",
                manualRef: "p.42"
            ),
            SettingSpec(
                key: "HDR Interior", section: "HDR", title: "HDR Interior",
                kind: .options(hdrModes),
                summary: "HDR for the interior camera.",
                manual: "As HDR Front, applied to the cabin channel. When the front camera is set to Auto HDR Timer, this follows the front camera's schedule.",
                manualRef: "p.42"
            ),
            SettingSpec(
                key: "Auto HDR Timer Start", section: "HDR", title: "Auto HDR Timer Start",
                kind: .time,
                summary: "Start of the window in which Auto HDR turns HDR on.",
                manual: """
                    24-hour hh:mm:ss. Only has an effect on channels set to Auto HDR \
                    Timer. Typically set to dusk so HDR engages for night driving.
                    """,
                manualRef: "p.42"
            ),
            SettingSpec(
                key: "Auto HDR Timer Stop", section: "HDR", title: "Auto HDR Timer Stop",
                kind: .time,
                summary: "End of the Auto HDR window.",
                manual: "24-hour hh:mm:ss. Only has an effect on channels set to Auto HDR Timer. Typically set to sunrise.",
                manualRef: "p.42"
            ),
        ]
    )

    static let exposureValue = SectionSpec(
        name: "Exposure Value",
        blurb: "Per-camera exposure compensation, +2.0 to -2.0 EV.",
        settings: ["Front", "Interior", "Rear"].map { camera in
            SettingSpec(
                key: "EV \(camera)",
                section: "Exposure Value",
                title: "EV \(camera)",
                kind: .options(exposureValues),
                summary: "Exposure compensation for the \(camera.lowercased()) camera.",
                manual: """
                    Adjusting the EV properly can create better footage under different \
                    light sources. It ranges from -2.0 to +2.0 and can be set for each \
                    camera separately; the default is 0.0.

                    Lower it if bright sky or a reflective hood is blowing out the \
                    picture; raise it if the shadowed part of the scene is too dark.
                    """,
                manualRef: "p.43"
            )
        }
    )
}

private extension Array where Element == SettingOption {
    var asOptions: ValueKind { .options(self) }
}
