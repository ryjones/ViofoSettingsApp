# VIOFO Settings

A macOS app that reads the configuration a VIOFO A329S dash cam writes to its
memory card, explains every setting in plain language from the official manual,
and points out where your settings quietly contradict each other.

## Why

An A329S has 81 settings spread across 11 sections, driven through a two-inch
screen and four buttons. The camera can export them all to a text file, but that
file is just codes:

```ini
# G-sensor, 0:Off; 1:Low; 2:Medium; 3:High
G-sensor=0
Resolution=14
Parking Mode=0
```

Knowing that `G-sensor=0` means impacts are never detected — so a collision won't
lock the clip and loop recording will overwrite it — means going back to the
manual. This app does that for you: every setting carries its explanation, the
manual page it came from, and the hardware it depends on.

More usefully, it reads *across* settings. The camera will happily let you enable
a rear camera while running a two-channel resolution that has no room for it, or
switch on a stamp whose text is empty, or mute every channel it has for telling
you the card has failed. Nothing is invalid, so nothing warns you.

> **This app does not write to the camera.** The manual (p.65) describes
> `viofo_config.ini` as a read-out you open to review the camera's current
> settings; it documents no way to load an edited file back. Treat a saved file as
> a record of what you intend to set, then make the change on the camera or in the
> VIOFO app.

## Getting the file off your camera

1. On the camera, turn on **System Settings ▸ Export Settings**.
2. Power down and remove the microSD card.
3. `viofo_config.ini` is in the root of the card.

The app scans mounted volumes for it at launch, so with the card in a reader it
usually just offers you the file.

## Build and run

Requires macOS 14 or later and a Swift 6 toolchain (Xcode 16+).

```sh
git clone https://github.com/ryjones/ViofoSettingsApp.git
cd ViofoSettingsApp/ViofoConfig
./build-app.sh          # produces ViofoConfig.app
open ViofoConfig.app
```

You can also open a file directly:

```sh
open -a "$PWD/ViofoConfig.app" --args /Volumes/CARD/viofo_config.ini
```

`swift run ViofoConfig` works for a quick launch without building the bundle.

## Using it

**Overview** describes what the camera actually does, in prose assembled from the
values rather than listed key by key:

> *While driving.* Clips are 1 minute long at maximum bitrate with audio. Impacts
> are not detected, so nothing is locked against being overwritten. Each camera
> writes its own file.
>
> *While parked.* Parking Mode is Off — once the engine stops the camera stops
> with it, and nothing in the Parking Recording section applies.

**Things to look at** lists the cross-setting findings, sorted by how much they
cost you. Each one names the settings involved and links straight to them.

**Settings** is every key grouped by its section, with a menu of the legal values,
a one-line summary, the manual's own explanation, the page reference, and a badge
for any hardware the setting needs — a stamp that only works with an HK6 hardwire
cable says so.

**Raw file** shows the file exactly as it will be written.

**Export Explanation** saves the whole configuration as a Markdown document.

## What it checks

Findings come in three kinds. A **gap** is protection you probably think you have
and don't:

- The G-sensor is off, so no clip is locked in a collision.
- Beeps and voice notifications are both off, so a card error, a failed format or
  a missing card passes in silence.

A **conflict** is two settings that disagree:

- A rear or interior camera is enabled but the chosen resolution is a two-channel
  mode with no room for it. The app suggests the modes that fit.
- The front channel is at 60fps while HDR is on — the manual says 4K 60fps is
  available only with HDR disabled.
- A stamp is switched on with no text behind it.
- Parking storage is set to SSD under a low-power parking mode, which the firmware
  overrides to the card.
- Geofencing is on but GPS is off, so the zones can never match.
- Daylight saving is on outside the US zones, though the camera only knows US rules.

A **note** is worth knowing but not wrong: a battery-protection measure with no
threshold set, an Auto HDR window no channel uses, Privacy Mode overriding your
loop length, a sensitivity above what the manual recommends for parking.

## Command line

The same binary explains a configuration without opening a window:

```sh
ViofoConfig --check  /Volumes/CARD/viofo_config.ini   # summary and findings
ViofoConfig --report /Volumes/CARD/viofo_config.ini   # full Markdown explanation
```

`--check` exits non-zero when the configuration leaves a gap, so it can be dropped
into a script.

## Editing and saving

Saving preserves the file exactly. Comments, key order, blank lines, spacing and
line endings all survive, and only the values you changed differ — the intent is
that a file this app has written is still a file the camera can read. Keys it
doesn't recognise, from newer firmware or another camera edition, pass through
untouched and are listed as a note rather than dropped.

## Compatibility

Built against the **A329S Series user manual V26.01.09** and an export from that
firmware: 81 keys across 11 sections. Five of them — `Dewarp Front Cam`,
`Cut-off BP100 Capacity`, `Backup Impact Parking Videos`, `Low Power Impact
Recording` and `Battery pack Capacity Stamp` — are written by the firmware but
absent from that manual revision. They are labelled as such in the app rather than
dressed up as documented, and their descriptions are inferred from their value
lists. Confirm those on the camera before relying on them.

Other A329S editions (telephoto, waterproof, dual-waterproof) rename some options;
where the manual documents the difference, the app says so.

## Development

```sh
cd ViofoConfig
swift build
swift test
```

The suite is self-contained — it runs against a real camera export checked in at
`Tests/ViofoConfigTests/Fixtures/viofo_config.ini`, sanitized so it carries no
license plate. See [`ViofoConfig/README.md`](ViofoConfig/README.md) for the source
layout and how to add a setting.

## License

Apache 2.0. See [LICENSE](LICENSE).

Setting explanations are drawn from VIOFO's A329S user manual. VIOFO and A329S are
trademarks of their respective owner; this project is not affiliated with VIOFO.
