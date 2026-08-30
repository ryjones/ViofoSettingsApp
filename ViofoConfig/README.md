# ViofoConfig — package notes

The Swift package behind the app. For what the app is, how to install it and how
to use it, see the [repository README](../README.md).

## Build and test

```sh
swift build
swift test
./build-app.sh              # wraps the binary in ViofoConfig.app
```

`build-app.sh` exists because a bare SwiftPM binary has no bundle and AppKit
treats it as a background process; the script writes an `Info.plist` and ad-hoc
signs the result.

The test suite is self-contained. It runs against a real camera export at
`Tests/ViofoConfigTests/Fixtures/viofo_config.ini`, sanitized so it carries no
license plate, and covers byte-identical round-tripping, CRLF handling,
preservation of unrecognised keys, and the advisory rules.

## Layout

```
Sources/ViofoConfig/
  CLI.swift                  entry point: --check / --report, otherwise the app
  ViofoConfigApp.swift       scene, menu commands, launch-file handling
  Model/
    Setting.swift            SettingSpec / SettingOption / ValueKind
    Schema.swift             shared option lists, section order
    Schema+Video.swift       resolution table, [Video Settings]
    Schema+Parking.swift     [Parking Recording], [HDR], [Exposure Value]
    Schema+System.swift      [Stamp], [System Settings], [LED], Wi-Fi station
    ConfigDocument.swift     structure-preserving ini parser and writer
    Advisories.swift         cross-setting checks
    Digest.swift             prose summary and Markdown report
  Views/
    ContentView.swift        split view, sidebar, search, welcome screen
    SectionDetailView.swift  setting cards and controls
    OverviewView.swift       overview, advisories, raw file
    FileActions.swift        open/save panels, card discovery, recents
```

## Adding a setting

Add one `SettingSpec` to the relevant `Schema+*.swift`. The picker, search, prose
summary and Markdown report all derive from it — no view code to touch.

```swift
SettingSpec(
    key: "Parking HDR",              // exact key as the firmware writes it
    section: "Parking Recording",
    title: "Parking HDR",
    kind: .options(offOn),           // or .text(maxLength:) / .time
    summary: "HDR processing while parked.",
    manual: "Turns HDR on or off in parking mode…",
    manualRef: "p.49, 55",           // omit when the manual does not cover it,
    requires: nil                    // and the app labels it as undocumented
)
```

Cross-setting checks live in `Advisories.swift` as additions to
`AdvisoryEngine.evaluate`, each returning an `Advisory` with the keys it concerns
so the UI can link back to them.

## Design notes

`ConfigDocument` models the file as a list of lines — comment, blank, section,
key/value, or passthrough — rather than a dictionary. That is what lets a save
preserve the camera's own explanatory comments, key order and line endings, and
what lets keys from newer firmware survive a round trip untouched.

`SettingSpec.manualRef` being optional is deliberate: five keys in the current
firmware have no manual coverage, and the app says so rather than inventing an
explanation.
