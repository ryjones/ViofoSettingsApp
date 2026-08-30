import Foundation

extension Schema {

    static let stamp = SectionSpec(
        name: "Stamp",
        blurb: "Information burned into the recorded picture. Stamps are part of the video frame, so they survive copying but cannot be removed later.",
        settings: [
            SettingSpec(
                key: "Date Stamp", section: "Stamp", title: "Date Stamp", kind: .options(offOn),
                summary: "Date and time in the frame.",
                manual: "Imprints the current date and time on the recorded video. Useful as evidence, since it is baked into the picture rather than stored only in metadata.",
                manualRef: "p.43"
            ),
            SettingSpec(
                key: "GPS Speed Stamp", section: "Stamp", title: "GPS Speed Stamp", kind: .options(offOn),
                summary: "Vehicle speed in the frame.",
                manual: "Imprints the GPS-derived speed, in the unit chosen by Speed Units. Requires GPS to be on and a fix to be acquired.",
                manualRef: "p.43",
                requires: "GPS enabled"
            ),
            SettingSpec(
                key: "GPS Coordinates Stamp", section: "Stamp", title: "GPS Coordinates Stamp", kind: .options(offOn),
                summary: "Latitude and longitude in the frame.",
                manual: "Imprints the current coordinates. Requires GPS. Consider that anyone you hand a clip to can read your exact position from it.",
                manualRef: "p.43",
                requires: "GPS enabled"
            ),
            SettingSpec(
                key: "Custom Stamp", section: "Stamp", title: "Custom Stamp", kind: .options(offOn),
                summary: "Shows the Custom Text Stamp string.",
                manual: "Turns on the free-text stamp. The text itself is set by Custom Text Stamp — with that left empty, enabling this prints nothing.",
                manualRef: "p.43"
            ),
            SettingSpec(
                key: "License Plate Stamp", section: "Stamp", title: "License Plate Stamp", kind: .options(offOn),
                summary: "Shows the License Plate Number string.",
                manual: "Imprints the car number set in License Plate Number, which identifies which vehicle a clip came from.",
                manualRef: "p.43, 59"
            ),
            SettingSpec(
                key: "Logo Stamp", section: "Stamp", title: "Logo Stamp", kind: .options(offOn),
                summary: "VIOFO logo in the frame.",
                manual: "Imprints the VIOFO logo on the recorded video.",
                manualRef: "p.43"
            ),
            SettingSpec(
                key: "Brand Model Stamp", section: "Stamp", title: "Brand Model Stamp", kind: .options(offOn),
                summary: "Camera model in the frame.",
                manual: "Imprints the camera brand and model, which documents what equipment produced the footage.",
                manualRef: "p.43"
            ),
            SettingSpec(
                key: "Resolution Stamp", section: "Stamp", title: "Resolution Stamp", kind: .options(offOn),
                summary: "Recording resolution in the frame.",
                manual: "Imprints the resolution the clip was recorded at.",
                manualRef: "p.43"
            ),
            SettingSpec(
                key: "Vehicle Voltage Stamp", section: "Stamp", title: "Vehicle Voltage Stamp", kind: .options(offOn),
                summary: "Battery voltage in the frame.",
                manual: """
                    Imprints the vehicle's battery voltage. The manual is explicit that \
                    the dashcam must be powered by the VIOFO HK6 hardwire cable for a \
                    voltage value to be displayed — on any other power source there is \
                    nothing to read.
                    """,
                manualRef: "p.43",
                requires: "VIOFO HK6 hardwire cable"
            ),
            SettingSpec(
                key: "Battery pack Capacity Stamp", section: "Stamp", title: "Battery pack Capacity Stamp", kind: .options(offOn),
                summary: "External battery state of charge in the frame.",
                manual: """
                    Exported by the firmware but not described in manual V26.01.09. It is \
                    the battery-pack counterpart to the vehicle voltage stamp, printing the \
                    remaining capacity of a VIOFO battery pack such as the BP100. Without \
                    such a pack connected there is nothing to display.
                    """,
                requires: "VIOFO battery pack"
            ),
            SettingSpec(
                key: "Stamp Text Color", section: "Stamp", title: "Stamp Text Color",
                kind: .options([
                    SettingOption(raw: 0, label: "White"),
                    SettingOption(raw: 1, label: "Yellow"),
                    SettingOption(raw: 2, label: "Cyan"),
                    SettingOption(raw: 3, label: "Golden"),
                ]),
                summary: "Colour of every stamp.",
                manual: "You can change the stamp text colour in the video file to white, yellow, cyan or golden. Pick whichever stays legible against the road scenes you actually record.",
                manualRef: "p.43"
            ),
            SettingSpec(
                key: "Custom Text Stamp", section: "Stamp", title: "Custom Text Stamp",
                kind: .text(maxLength: 11),
                summary: "Free text, maximum 11 characters.",
                manual: "Imprints custom text on the recorded video — a driver name, fleet number or contact. Only shown when Custom Stamp is On. Maximum length 11 characters.",
                manualRef: "p.59"
            ),
            SettingSpec(
                key: "License Plate Number", section: "Stamp", title: "License Plate Number",
                kind: .text(maxLength: 11),
                summary: "Plate text, maximum 11 characters.",
                manual: "Imprints the car number on the recorded video. Only shown when License Plate Stamp is On. Maximum length 11 characters.",
                manualRef: "p.59"
            ),
        ]
    )

    static let imageRotateMirror = SectionSpec(
        name: "Image Rotate & Mirror",
        blurb: "Geometry fixes for secondary cameras — rotate for an upside-down mount, mirror for a rear view that should read like a mirror.",
        settings: [
            SettingSpec(
                key: "Interior Image Rotate", section: "Image Rotate & Mirror", title: "Interior Image Rotate", kind: .options(offOn),
                summary: "Turns the cabin image 180°.",
                manual: "Rotates the infrared fisheye cabin camera image, for a camera mounted upside-down.",
                manualRef: "p.58"
            ),
            SettingSpec(
                key: "Interior Image Mirror", section: "Image Rotate & Mirror", title: "Interior Image Mirror", kind: .options(offOn),
                summary: "Flips the cabin image left to right.",
                manual: "Mirrors the infrared fisheye cabin camera image.",
                manualRef: "p.58"
            ),
            SettingSpec(
                key: "Rear Image Rotate", section: "Image Rotate & Mirror", title: "Rear Image Rotate", kind: .options(offOn),
                summary: "Turns the rear image 180°.",
                manual: "Rotates the rear camera image, for a camera mounted upside-down on the rear glass.",
                manualRef: "p.58"
            ),
            SettingSpec(
                key: "Rear Image Mirror", section: "Image Rotate & Mirror", title: "Rear Image Mirror", kind: .options(offOn),
                summary: "Flips the rear image left to right.",
                manual: "Mirrors the rear camera image, so the footage reads the way a rear-view mirror does.",
                manualRef: "p.58"
            ),
        ]
    )

    static let timeZones: [SettingOption] = [
        SettingOption(raw: 1,  label: "GMT-12"),
        SettingOption(raw: 2,  label: "GMT-11"),
        SettingOption(raw: 3,  label: "GMT-10", note: "Hawaii"),
        SettingOption(raw: 4,  label: "GMT-9",  note: "Alaska"),
        SettingOption(raw: 5,  label: "GMT-8",  note: "US Pacific"),
        SettingOption(raw: 6,  label: "GMT-7",  note: "US Mountain"),
        SettingOption(raw: 7,  label: "GMT-6",  note: "US Central"),
        SettingOption(raw: 8,  label: "GMT-5",  note: "US Eastern"),
        SettingOption(raw: 10, label: "GMT-4"),
        SettingOption(raw: 11, label: "GMT-3:30"),
        SettingOption(raw: 12, label: "GMT-3"),
        SettingOption(raw: 13, label: "GMT-2:30"),
        SettingOption(raw: 14, label: "GMT-2"),
        SettingOption(raw: 15, label: "GMT-1"),
        SettingOption(raw: 16, label: "GMT+0",  note: "UK, Portugal"),
        SettingOption(raw: 17, label: "GMT+1",  note: "Central Europe"),
        SettingOption(raw: 18, label: "GMT+2"),
        SettingOption(raw: 19, label: "GMT+3"),
        SettingOption(raw: 20, label: "GMT+3:30"),
        SettingOption(raw: 21, label: "GMT+4"),
        SettingOption(raw: 22, label: "GMT+4:30"),
        SettingOption(raw: 23, label: "GMT+5"),
        SettingOption(raw: 24, label: "GMT+5:30", note: "India"),
        SettingOption(raw: 26, label: "GMT+6"),
        SettingOption(raw: 27, label: "GMT+6:30"),
        SettingOption(raw: 28, label: "GMT+7"),
        SettingOption(raw: 29, label: "GMT+8"),
        SettingOption(raw: 30, label: "GMT+9"),
        SettingOption(raw: 31, label: "GMT+9:30"),
        SettingOption(raw: 32, label: "GMT+10"),
        SettingOption(raw: 33, label: "GMT+10:30"),
        SettingOption(raw: 34, label: "GMT+11"),
        SettingOption(raw: 35, label: "GMT+12"),
        SettingOption(raw: 37, label: "GMT+13"),
    ]

    static let systemSettings = SectionSpec(
        name: "System Settings",
        blurb: "The camera itself: radio, clock, storage, feedback and the display.",
        settings: [
            SettingSpec(
                key: "Wi-Fi", section: "System Settings", title: "Wi-Fi", kind: .options(offOn),
                summary: "The camera's own access point, used by the VIOFO app.",
                manual: """
                    Turns Wi-Fi on or off. Holding the Wi-Fi button on the camera for 3 to \
                    5 seconds also toggles it. When Wi-Fi is on, the SSID and password \
                    appear on the camera's LCD; connect the phone to that network, then \
                    tap Connect New Device in the VIOFO app. Range is about 10 m.
                    """,
                manualRef: "p.35, 60"
            ),
            SettingSpec(
                key: "Wi-Fi Frequency", section: "System Settings", title: "Wi-Fi Frequency",
                kind: .options([
                    SettingOption(raw: 1, label: "2.4 GHz"),
                    SettingOption(raw: 2, label: "5 GHz", note: "recommended"),
                ]),
                summary: "Band for the camera's access point.",
                manual: """
                    The manual recommends 5 GHz, which is much faster for pulling 4K clips \
                    off the camera. 2.4 GHz has longer range and better compatibility with \
                    older phones, at a fraction of the throughput.
                    """,
                manualRef: "p.60"
            ),
            SettingSpec(
                key: "Time Zone", section: "System Settings", title: "Time Zone",
                kind: .options(timeZones),
                summary: "Offset applied to GPS time for the clock and date stamp.",
                manual: """
                    Sets the current time zone used to calibrate the date and time from \
                    GPS. The manual notes that the time zone must be adjusted manually for \
                    daylight saving everywhere except the United States, where the \
                    Daylight Saving setting handles it.

                    Set the standard-time offset for your zone, not the summer one — with \
                    Daylight Saving on, the camera adds the hour itself.
                    """,
                manualRef: "p.59, 61"
            ),
            SettingSpec(
                key: "Time Format", section: "System Settings", title: "Time Format",
                kind: .options([
                    SettingOption(raw: 0, label: "24H"),
                    SettingOption(raw: 1, label: "12H"),
                ]),
                summary: "Clock format on screen and in the date stamp.",
                manual: "Sets the system time format.",
                manualRef: "p.61"
            ),
            SettingSpec(
                key: "Daylight Saving", section: "System Settings", title: "Daylight Saving",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "On", note: "United States rules"),
                ]),
                summary: "Automatic US summer-time adjustment.",
                manual: """
                    Off / United States — the camera only knows US daylight saving rules. \
                    Outside the US, leave this off and shift the Time Zone by hand twice a \
                    year, or accept a one-hour offset in the stamps.
                    """,
                manualRef: "p.61"
            ),
            SettingSpec(
                key: "Boot Delay", section: "System Settings", title: "Boot Delay",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "5 Seconds"),
                    SettingOption(raw: 2, label: "10 Seconds"),
                ]),
                summary: "Pause between power arriving and the camera booting.",
                manual: """
                    The camera waits this long before starting up when power is applied. \
                    A delay keeps the camera from booting during the voltage dip of engine \
                    cranking, which is easier on the electronics in some vehicles.
                    """,
                manualRef: "p.61"
            ),
            SettingSpec(
                key: "Driving Recording Storage", section: "System Settings", title: "Driving Recording Storage",
                kind: .options([
                    SettingOption(raw: 0, label: "SD"),
                    SettingOption(raw: 1, label: "SSD"),
                ]),
                summary: "Where normal driving clips and photos are written.",
                manual: """
                    Chooses whether videos and photos are stored on the microSD card or an \
                    external SSD. The SSD is connected with a VIOFO Type-C SSD cable and \
                    offers far more capacity and endurance; the card remains the fallback \
                    and is the only destination the low-power parking modes can use.
                    """,
                manualRef: "p.62"
            ),
            SettingSpec(
                key: "Beep Sound", section: "System Settings", title: "Beep Sound",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "Only Keytone"),
                    SettingOption(raw: 2, label: "Only Boot Sound"),
                    SettingOption(raw: 3, label: "All"),
                ]),
                summary: "Button and startup sounds.",
                manual: "Enables or disables the button and startup sounds. This is also one of the two channels through which parking impact notifications reach you.",
                manualRef: "p.62"
            ),
            SettingSpec(
                key: "Voice Notification", section: "System Settings", title: "Voice Notification",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "On"),
                    SettingOption(raw: 2, label: "Only Critical Alerts"),
                ]),
                summary: "Spoken announcements from the camera.",
                manual: """
                    Turns spoken notifications on or off, or limits them to critical \
                    alerts. With Only Critical Alerts the camera announces just the things \
                    that mean it has stopped protecting you:

                    • "An impact was detected during parking recording."
                    • "Memory card error, please format the card."
                    • "Memory card format failed."
                    • "Please insert a memory card."

                    That middle ground is the safest choice if you find the full \
                    announcements intrusive but still want to hear about a dead card.
                    """,
                manualRef: "p.62"
            ),
            SettingSpec(
                key: "Voice Notification Volume", section: "System Settings", title: "Voice Notification Volume",
                kind: .options([
                    SettingOption(raw: 0, label: "Low"),
                    SettingOption(raw: 1, label: "Medium"),
                    SettingOption(raw: 2, label: "High"),
                ]),
                summary: "Loudness of the spoken notifications.",
                manual: "Adjusts the volume of the voice notification. Has no effect while Voice Notification is Off.",
                manualRef: "p.62"
            ),
            SettingSpec(
                key: "Voice Control", section: "System Settings", title: "Voice Control",
                kind: .options(offOn),
                summary: "Hands-free spoken commands.",
                manual: """
                    When on, you can control the camera by speaking: Take Photo, Video \
                    Start, Turn On/Off Audio, Turn On/Off Screen, Turn On/Off Wi-Fi, Show \
                    Front Camera, Show Rear Camera, Show Both Cameras, Lock The Video.

                    The command language has to match the camera's system language among \
                    English, Chinese, Russian and Japanese; for every other system \
                    language, English is the only language that triggers voice control.
                    """,
                manualRef: "p.62–63"
            ),
            SettingSpec(
                key: "GPS", section: "System Settings", title: "GPS", kind: .options(offOn),
                summary: "Position and speed logging.",
                manual: """
                    Turns the GPS logger on or off. The GPS module adds location data to \
                    the recorded videos. Disabled, the camera no longer measures speed or \
                    position, and no longer synchronises the time and date — so the clock \
                    will drift and the date stamp with it. Use VIOFO Player on a computer \
                    to see position and speed alongside the video.
                    """,
                manualRef: "p.63"
            ),
            SettingSpec(
                key: "Speed Units", section: "System Settings", title: "Speed Units",
                kind: .options([
                    SettingOption(raw: 0, label: "MPH"),
                    SettingOption(raw: 1, label: "km/h"),
                ]),
                summary: "Unit for the speed display and speed stamp.",
                manual: "Kilometres per hour and miles per hour are available for the speed units shown on screen and burned into the video.",
                manualRef: "p.63"
            ),
            SettingSpec(
                key: "Screen Saver", section: "System Settings", title: "Screen Saver",
                kind: .options([
                    SettingOption(raw: 2, label: "3 Seconds"),
                    SettingOption(raw: 3, label: "15 Seconds"),
                    SettingOption(raw: 4, label: "30 Seconds"),
                    SettingOption(raw: 5, label: "1 Minute", note: "default"),
                    SettingOption(raw: 6, label: "3 Minutes"),
                ]),
                summary: "Idle time before the LCD goes black.",
                manual: """
                    The screen goes black after this interval while recording; the camera \
                    keeps recording regardless. A short interval is less distracting at \
                    night. There is no permanently-on option in this list.
                    """,
                manualRef: "p.63"
            ),
            SettingSpec(
                key: "Frequency", section: "System Settings", title: "Frequency",
                kind: .options([
                    SettingOption(raw: 0, label: "50 Hz", note: "Europe, Asia, Australia"),
                    SettingOption(raw: 1, label: "60 Hz", note: "North America"),
                ]),
                summary: "Anti-flicker frequency, matched to the local mains supply.",
                manual: """
                    Set this to minimise flickering and banding in the recorded video, \
                    which comes from artificial lighting running at the local mains \
                    frequency. Match your region: 60 Hz in North America, 50 Hz across most \
                    of Europe, Asia and Australia. A mismatch shows up as rolling bands \
                    under street and tunnel lighting.
                    """,
                manualRef: "p.63"
            ),
            SettingSpec(
                key: "Format Reminder", section: "System Settings", title: "Format Reminder",
                kind: .options([
                    SettingOption(raw: 0, label: "Off"),
                    SettingOption(raw: 1, label: "15 Days"),
                    SettingOption(raw: 2, label: "30 Days"),
                    SettingOption(raw: 3, label: "60 Days"),
                ]),
                summary: "Periodic prompt to reformat the card.",
                manual: """
                    Sets a regular reminder to format the memory card. The manual suggests \
                    formatting periodically to keep the card performing well — flash cards \
                    in a dashcam are rewritten constantly, and a stale filesystem is a \
                    common cause of dropped or corrupt clips. Formatting erases everything, \
                    so back up anything you care about first.
                    """,
                manualRef: "p.64"
            ),
        ]
    )

    static let bluetoothButtons = SectionSpec(
        name: "Bluetooth Button Function",
        blurb: "The optional Bluetooth remote mounts on the dashboard so you can act without looking away from the road. Note that the codes mean different things on each button.",
        settings: [
            SettingSpec(
                key: "Mic Button", section: "Bluetooth Button Function", title: "Mic Button",
                kind: .options(bluetoothOptions(primary: "Turn On / Off Microphone",
                                                secondary: "Turn On / Off WiFi")),
                summary: "Action for the remote's microphone button.",
                manual: """
                    Assigns a function to the Mic button on the Bluetooth remote control. \
                    Watch the numbering: on this button code 2 is the microphone toggle and \
                    code 4 is Wi-Fi, while on the Action button those two are swapped. The \
                    same number in the file does not mean the same action.

                    Pair the remote by powering on the camera and holding the remote's \
                    video lock button for 3 seconds; the remote's LED turns blue when paired.
                    """,
                manualRef: "p.40, 60",
                requires: "Bluetooth remote control"
            ),
            SettingSpec(
                key: "Action Button", section: "Bluetooth Button Function", title: "Action Button",
                kind: .options(bluetoothOptions(primary: "Turn On / Off WiFi",
                                                secondary: "Turn On / Off Microphone")),
                summary: "Action for the remote's action button.",
                manual: """
                    Assigns a function to the Action button on the Bluetooth remote \
                    control. On this button code 2 is Wi-Fi and code 4 is the microphone — \
                    the reverse of the Mic button.
                    """,
                manualRef: "p.40, 60",
                requires: "Bluetooth remote control"
            ),
        ]
    )

    static let frontLEDOptions: [SettingOption] = [
        SettingOption(raw: 0, label: "All Off"),
        SettingOption(raw: 1, label: "All On"),
        SettingOption(raw: 2, label: "Power LED Only"),
    ]

    static let led = SectionSpec(
        name: "LED",
        blurb: "Status lights while driving. The front unit has five (power, recording, GPS, microphone, Wi-Fi); the other cameras have one each.",
        settings: [
            SettingSpec(
                key: "Front LED", section: "LED", title: "Front LED",
                kind: .options(frontLEDOptions),
                summary: "Status lights on the main unit.",
                manual: """
                    All Off, All On, or Power LED Only. The front unit's LEDs report \
                    recording, GPS, microphone and Wi-Fi state. Power LED Only keeps a \
                    single confirmation that the camera is alive without the rest of the \
                    light show reflecting in the windscreen at night.
                    """,
                manualRef: "p.61"
            ),
            SettingSpec(
                key: "Rear LED", section: "LED", title: "Rear LED", kind: .options(offOn),
                summary: "Status light on the rear camera.",
                manual: "Enables or disables the rear camera's LED indicator.",
                manualRef: "p.61"
            ),
            SettingSpec(
                key: "Interior LED", section: "LED", title: "Interior LED", kind: .options(offOn),
                summary: "Status light on the cabin camera.",
                manual: "Enables or disables the interior camera's LED indicator. Separate from the infrared illuminators, which are controlled by IR LED.",
                manualRef: "p.61"
            ),
        ]
    )

    static let parkingModeLED = SectionSpec(
        name: "Parking Mode LED",
        blurb: "The same lights, set independently for parking mode — where they are the visible sign that the car is being watched.",
        settings: [
            SettingSpec(
                key: "Front Parking LED", section: "Parking Mode LED", title: "Front Parking LED",
                kind: .options(frontLEDOptions),
                summary: "Main unit lights while parked.",
                manual: """
                    Enables or disables the LED lights under parking mode. There is a real \
                    trade-off: lit LEDs advertise that the car is recording, which deters \
                    some people and attracts the attention of others. Off draws marginally \
                    less power and keeps the camera inconspicuous.
                    """,
                manualRef: "p.61"
            ),
            SettingSpec(
                key: "Rear Parking LED", section: "Parking Mode LED", title: "Rear Parking LED", kind: .options(offOn),
                summary: "Rear camera light while parked.",
                manual: "Enables or disables the rear camera LED under parking mode.",
                manualRef: "p.61"
            ),
            SettingSpec(
                key: "Interior Parking LED", section: "Parking Mode LED", title: "Interior Parking LED", kind: .options(offOn),
                summary: "Cabin camera light while parked.",
                manual: "Enables or disables the interior camera LED under parking mode.",
                manualRef: "p.61"
            ),
        ]
    )

    static let wifiStationMode = SectionSpec(
        name: "Wi-Fi Station Mode",
        blurb: "Instead of hosting its own access point, the camera joins an existing network — a phone hotspot, or home Wi-Fi in the garage.",
        settings: [
            SettingSpec(
                key: "STA mode SSID", section: "Wi-Fi Station Mode", title: "STA mode SSID",
                kind: .text(maxLength: 20),
                summary: "Network the camera joins, maximum 20 characters.",
                manual: """
                    Station mode is the reverse of the camera's normal behaviour: rather \
                    than the phone joining the camera's access point, the camera joins the \
                    network named here. A Bluetooth remote button can be mapped to Wi-Fi \
                    Station Mode to switch into it. Maximum 20 characters.
                    """,
                manualRef: "p.60"
            ),
            SettingSpec(
                key: "STA mode password", section: "Wi-Fi Station Mode", title: "STA mode password",
                kind: .text(maxLength: 20),
                summary: "Password for that network, maximum 20 characters.",
                manual: """
                    The password for the station-mode network. It is stored in clear text \
                    in this file, as it is on the card — worth remembering before sharing \
                    an exported config with anyone.
                    """,
                manualRef: "p.60"
            ),
        ]
    )
}
