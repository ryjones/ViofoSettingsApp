# Reading and writing camera settings over Wi-Fi

The app currently works on `viofo_config.ini` from the memory card. This document
describes the other route — talking to the camera directly over its Wi-Fi access
point — and answers the question that route exists to solve: **can the current
configuration be exported and downloaded over HTTP for editing?**

**Short answer: reading, yes. Writing back as a file, no — but writing settings
one at a time, yes.**

Derived from the camera's own `cardv` binary (see the firmware project's
`cardv-re.md`) — including, in §5, the complete HTTP command dispatch table read
straight out of the firmware — and **verified against a real A329S** running
`VIOFO_A329S_V2.2_260815`, the same build the firmware analysis was done on.
Sections marked *verified* were observed; anything still inferred says so.

VIOFO's own app database was the earlier source for command names and is still used
for the option labels, but it is no longer what the command set is derived from.

---

## 1. Connecting

The camera runs an access point and answers on a fixed address:

```
http://192.168.1.254
```

Every request is a query string on the root path:

```
http://192.168.1.254/?custom=1&cmd=<number>[&par=<integer>][&str=<text>]
```

That form appears verbatim in both halves. `cardv` builds its replies from
`"custom=1&cmd=%d&par="` and `"custom=1&cmd=%d&str="` at `0x700018` / `0x700db0`,
and the iOS app contains `http://192.168.1.254` and `?custom=1&cmd=4001`.
Responses are XML — `cardv` assembles them with literal `<Item>`, `</LIST>`,
`</MenuList>` and `<CHK>%02X%02X</CHK>` fragments.

`par=` carries an integer value, `str=` a string. This is Novatek's stock camera
API; VIOFO have extended it with their own command numbers.

### macOS specifics

Two entries are needed in the app bundle, and `build-app.sh` now writes both:

* `NSLocalNetworkUsageDescription` — macOS 15 gates local-network access behind a
  user prompt, and a process without this key fails silently.
* An `NSAppTransportSecurity` exception for `192.168.1.254`, because the camera
  speaks plain HTTP.

Joining the camera's network also removes your normal route to the internet, so
expect the app to be offline while it is talking to the camera.

---

## 2. Reading the current configuration

### `cmd=3014` — every setting and its current value

`CMD_QUERY_CUR_STATUS`, described in VIOFO's own database as *"query the state of
each setting"*. This is the bulk read, and it is the closest thing to
"download the extant config".

It is confirmed on the firmware side: the handler `XML_GetMenuItem` at
`0x44a960` walks an array of 16-byte records — `{u32 id; u32 pad; char *text}`,
terminated by `-1` — emitting one `<Item>` per entry inside a `<MenuList>`, and
finishes by calling the reply builder with the constant `3014`
(`mov w0, #0xbc6` at `0x44ab60`).

```sh
curl 'http://192.168.1.254/?custom=1&cmd=3014'
```

**Verified.** On a live A329S this returns 93 command/value pairs. The reply is a
flat stream rather than nested elements — `<Cmd>` and `<Status>` alternate at the
same level, and only settings carrying a string get their own `<Function>`
wrapper:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<Function>
<Cmd>2003</Cmd>
<Status>5</Status>
<Cmd>2004</Cmd>
<Status>1</Status>
<Function>
<Cmd>2005</Cmd>
<Status>0</Status>
<String>6,6,6</String>
</Function><Cmd>2006</Cmd>
...
```

So a parser must walk the token stream in order, not rely on element nesting.
71 of the 93 commands appear in VIOFO's own A329S menu table; the other 22 are not
described there, but all 93 are accounted for in the firmware's own dispatch table
(§5), which is where the names in this document now come from.

### `cmd=9352` is a toggle, not a trigger — verified

(`cmd=9353`, *Import Settings*, is the same shape and is covered in §5.)

`CMD_EXPORT_SETTINGS` reads like "export the settings now". **It is not.** It is
the on/off switch behind *System Settings ▸ Export Settings*, and it takes a
`par`:

```sh
curl 'http://192.168.1.254/?custom=1&cmd=9352&par=0'   # turns the feature OFF
```

Probing it with `par=0` during a live session silently disabled config export on
the camera, which only surfaced when a full `cmd=3014` diff against the baseline
showed `9352: 1 -> 0`. It was restored with `par=1`. **Sending a bare `par=0` to
an unidentified command is not a read — it is a write of the value zero.**

`cmd=9352` does not write the file. Its handler
`WiFiCmd_OnExeSetExportSetting` at `0x4434b0` is two instructions of substance —
`set_setting(0xe6, value)` and `return 1`. It flips a preference and nothing
else, which is why `par=1`, `par=0` and no `par` at all all returned
`<Status>0</Status>` and left the card listing's timestamp alone.

The write happens when you **ask the camera to export**, on the device. The
writer `MenuConfig_SaveCfgFile` (`0x436c00`) is reached two ways:

| via | behaviour |
| --- | --- |
| `0x456290`, tail call at `0x45631c` | the export routine — stamps `VIOFO_A329S_V2.2_260815` into the file, then writes it. Called from 11 sites in the menu code. |
| `MenuConfig_CheckFile` (`0x436ec0`) | `access(path, F_OK)` first: **overwrites only if the file already exists**, otherwise logs `config file %s is not exists` and returns −1. |

`MenuConfig_SaveCfgFile` itself early-returns unless `get_setting(0xe6)` is set,
so Export Settings being On is *necessary but not sufficient* — something still
has to request the export.

Two HTTP commands do request one, and both are in the dispatch table:

| cmd | handler | what it does |
| --- | --- | --- |
| **3021** | `0x441ee0` | `bl` the export routine, `return 1`. Nothing else. This is "export settings to card". |
| **8230** | `0x442320` | prints `system_reboot`, exports, `msleep(200)`, then **reboots**. |

**But 3021 does not reliably produce a file.** The export routine guards twice
before it writes:

```
0x4562a4   if *global_a == 1  -> apply default settings instead   (0x455a20)
0x4562b8   if *global_b == 2  -> printf("Viofo test : %d, not to save menu")
```

Tried against a live camera with `9352 = 1` (On): `cmd=3021` returned
`<Status>0</Status>` and no file appeared, at the card root or under `Config/`.
Stopping recording first with `cmd=2001&par=0` — leaving `cmd=2016` reporting 0
— did not change that. The `<Status>0</Status>` is the dispatcher acknowledging
the command, not the writer reporting success, so a caller cannot tell the
difference.

That first guard is worth knowing about: the branch it takes is a run of
`set_setting` calls (`0x1a` ← 33, `0x20` ← 0, `0x21` ← 0, `0x22` ← 1 …) — a
**defaults reset**, not an export. Whatever `global_a` is, `cmd=3021` writes
defaults when it is 1. Settings were diffed before and after every call made
here and none changed, so it was not taken in these tests, but the branch exists.

`cmd=8230` is refused by this app: rebooting the camera is not something it has
a reason to do.

**Not written at boot.** Verified directly: with `9352 = 1` (On), after a power
cycle the card root holds only `DCIM` — no `viofo_config.ini`, and no `Config/`
directory (`GET /Config/` → 404). A boot regenerated nothing.

> An earlier revision of this document claimed the file was a boot-time
> snapshot, reasoning from `MenuConfig_CheckFile` being called on an
> initialisation path. That was wrong on both halves: the check path only
> overwrites a file that is already there, and the routine that actually creates
> it (`0x456290`) sits immediately after `Load_MenuInfo` at `0x456110` — adjacent
> to the boot code, not part of it.

**Consequence:** `/viofo_config.ini` is a snapshot of whenever the last export
was requested, it cannot be reliably requested over the network, and the camera
never reads it back. It is not a transport. Use a JSON profile taken from
`cmd=3014` instead — see §5.7.

### Downloading it — verified

The camera serves the card over the same HTTP port, and the exported config sits
at the **root**, not under `Config/`:

```sh
curl -O http://192.168.1.254/viofo_config.ini      # 200, 9378 bytes
curl http://192.168.1.254/Config/viofo_config.ini  # 404
```

So yes: an export already on the card can be downloaded over HTTP with a single
GET, no card removal. The copy fetched this way was byte-for-byte identical in
values to one exported earlier by pulling the card.

Two caveats, both seen since. The GET only works if an export exists — on a
later session the same URL returned 404 and the root listing held only `DCIM`.
And the served path does not match the firmware's: `cardv` has exactly one
config path string, `/mnt/sd/Config/viofo_config.ini`, yet the file was served
from the HTTP **root** while `GET /Config/` 404s. Whether the httpd rewrites the
path or something else moves the file is unresolved.

`GET /` is a file browser listing the card root:

```html
<a href="/viofo_config.ini"><b>viofo_config.ini</b></a>  9.16 KB  2026/08/30 12:21:30
<a href="/format.txt"><b>format.txt</b></a>              0 B
<a href="/DCIM"><b>DCIM</b></a>                          folder
```

It also carries two `multipart/form-data` upload forms — `fileupload1` posting to
`/`, and `fileupload2` posting to `/?custom=1` — which is how firmware images get
onto the card. Note that each row also offers `?del=1`, which **deletes the
file**; do not script against those URLs casually.

### `cmd=9222` / `9223` — enter and leave settings mode

`CMD_SETTING_ENTER` and `CMD_SETTING_EXIT`. The app sends these around a
settings session; the camera stops recording while the app is in its menus.
Expect to need `9222` before reads or writes land reliably, and `9223` after.

---

## 3. Writing — verified

There is **no bulk import**. The camera never reads `viofo_config.ini`, and
uploading an edited one does nothing.

Writing individual settings works, and was confirmed end to end on a live
camera:

```sh
curl 'http://192.168.1.254/?custom=1&cmd=8214&par=1'   # Beep Sound -> On
# -> <Function><Cmd>8214</Cmd><Status>0</Status></Function>
curl 'http://192.168.1.254/?custom=1&cmd=3014' | grep -A1 '<Cmd>8214</Cmd>'
# -> <Cmd>8214</Cmd><Status>1</Status>
```

`<Status>0</Status>` in the reply means the command was accepted; the new value
shows up in the next `cmd=3014` read immediately. Restoring is symmetric.

**`cmd=9222` / `9223` are not required.** The `cmd=3014` reads and the `cmd=9352`
write above were both performed outside settings mode and behaved identically.
Entering settings mode stops recording, so an app that only reads and writes
settings has no reason to.

### The API is the interface; the ini is not

Since every setting can be read with `cmd=3014` and written with
`cmd=<n>&par=<v>`, there is no reason for a tool to route through the file. Read
and write the API directly. That also sidesteps the encoding differences in §6
entirely — those only matter to something trying to replay a file.

---

## 4. Implementing a client

`ViofoConfig/Sources/ViofoConfig/Model/Camera/` implements this, and the parts
that bit are worth stating plainly.

**The catalogue is generated, not hand-maintained.** `camera-commands.json` holds
the 93 settings — every dispatch-table row with a non-zero setting id, which is
exactly what `cmd=3014` reports. Rebuild it with `make catalog`, which merges
`api-map.json` from the firmware project with the option labels already in the
tree. Those labels are the one half that cannot be regenerated, because they come
from VIOFO's app database and it is not redistributed here; the generator harvests
only `CMD_*` names out of the old file for that reason.

The other 77 commands are actions and getters and are deliberately *not* in the
catalogue, so the settings UI cannot offer them.

**Do not borrow option lists from `firmware-schema.json`.** It has real option
labels for many of these settings, and they are keyed to the *ini* value, not the
API value — `Resolution` is `26` in the file and `"2,7"` over the wire. Wiring
those into a picker would write plausible, wrong values. The 22 settings VIOFO
does not describe therefore have no options and are shown read-only.

**Parse `cmd=3014` in document order.** It is a token stream, not a tree. Walk
`<Cmd>`, `<Status>` and `<String>` in sequence, remembering the last `<Cmd>`
seen. A `<String>` supersedes the `<Status>` for the same command.

**Do not parse values as integers.** Several arrive as comma-separated lists —
`8222` is `"2,7"`, `8220` is `"6,6,6"`. Keep them as strings and only convert
where a command is known to be scalar.

**Command numbers are not unique per setting.** Four of the 87 carry several
settings at once, which is why they answer with a list:

| cmd | settings it carries |
|-----|---------------------|
| 8220 | `CMD_SET_EXPOSURE_FRONT`, `_INTERIOR`, `_REAR` |
| 9224 | `CMD_NORMAL_LED_FRONT`, `CMD_NORMAL_RECORDING_LED_CONTROL` |
| 9226 | `CMD_PARKING_LED_FRONT`, `CMD_PARKING_RECORDING_LED_CONTROL` |
| 9316 | `CMD_BAK_SDCARD_TO_SSD`, `CMD_DELETE_SSD_FILE` |

The firmware table shows the same collision from the other direction — two command
numbers can carry one setting. `3028` and `8202` both hold setting `0x11`
(*Live Video Source*), and `2004` and `9318` both hold `0x1c` (HDR). So neither
command number nor setting id is a unique key for the other.

A dictionary keyed on command number therefore needs a merge rule, not
`uniquingKeysWith` omitted — building one naively traps at runtime, which is how
this was found.

**Refuse the destructive commands outright.** `3010` formats the card, `3011`
resets to factory, `9317` formats the SSD, and `9316` appears under both a
backup name and a delete name, so its parameter decides whether it destroys
data. The client refuses all four before a URL is even built rather than
characterising them by experiment.

**Write, then read back.** A write returns `<Status>0</Status>` on acceptance;
re-reading `cmd=3014` confirms the value actually took. The client shows the
camera's answer, not the requested value.

## 5. The A329S command set

Earlier revisions of this document built this table from a SQLite database inside
VIOFO's iOS app. That source describes 87 command numbers, while a live camera
answers `cmd=3014` with 93 — so 22 were undocumented, and nothing said what the
other 77 commands the camera accepts actually were.

The table below is taken from the firmware instead, where it is not a guess.

### Where it comes from

`cardv` keeps every command it accepts in one array in `.data`. `XML_QueryCmd` —
the handler behind `cmd=3002` — walks it with a 24-byte stride and stops on a zero
command number, which fixes the record layout:

```c
struct cmd_entry {          // 24 bytes, base 0x11103d8, 170 entries
    u32   cmd;              // the number in ?custom=1&cmd=N   (0 terminates)
    u32   wifi_cmd_id;      // 0x140200xx, posted to the WiFiCmd task
    void *handler;          // served on the HTTP thread, or NULL
    u32   flag_wait;        // FLG_ID_WIFICMD bits to block on, or 0
    u32   setting_id;       // the firmware setting id, or 0
};
```

The firmware project regenerates it:

```sh
CARDV=re/cardv python3 tools/re/dump_api_table.py --json api-map.json
```

and `api-map.json` there is the machine-readable form of everything below. The
derivation is written up in that project's `cardv-re.md` §5.

Command numbers, setting ids and blocking flags in the tables below are read directly
out of the binary and are exact. **Handler names are not** — `cardv` is stripped, so
they are recovered from the `__func__` literals it keeps, and 96 of the 170 resolve.
A blank handler column means no name was recovered, not that there is no handler.

### Three things the table settles

**1. `setting_id` is the ini↔HTTP bridge.** The fifth field is the same setting id
that `viofo_config.ini` is keyed on. The mapping §7 warns against deriving by name
matching is simply *in the binary*: `8222` carries setting `0x1a`, and `0x1a` is
`Resolution`. 66 of the ini's 81 keys resolve this way; the rest are text fields and
times with no command of their own.

**2. `cmd=3014` reports exactly the commands with a non-zero `setting_id`** — 93 of
the 170. Checked against a real capture in both directions, the two sets are
identical with no exceptions. So the reply is not an arbitrary subset: it is every
row of this table that is a setting.

**3. `flag_wait` marks the asynchronous commands.** A non-zero value means the
dispatcher blocks on those event-flag bits before it replies, so the HTTP response is
delayed until the operation finishes. `0x10` is shared by `3010` (format card) and
`9317` (format SSD); `0x80` is `3011` (factory reset).

### Settings — the 93 that `cmd=3014` returns

`setting id` is the firmware id, also the key into `firmware-schema.json`. `ini key`
is the name in `viofo_config.ini`, blank where the setting is not exported. `VIOFO key`
is the name from their app database, blank for the 22 it does not describe.

| cmd | setting id | ini key | VIOFO key | firmware handler | blocks |
|-----|-----------|---------|-----------|------------------|--------|
| 2001 | `0x18` |  |  | `WiFiCmd_OnExeMovieRec` | 0x4 |
| 2002 | `0x19` |  |  | `WiFiCmd_OnExeSetMovieRecSize` |  |
| 2003 | `0x22` | `Loop Recording` | `CMD_SET_LOOP_REC` | `WiFiCmd_OnExeCyclicRec` |  |
| 2004 | `0x1c` |  | `CMD_SET_HDR` | `WiFiCmd_OnExeMovieWDR` | 0x1 |
| 2005 | `0x05` |  |  |  |  |
| 2006 | `0x23` |  |  | `WiFiCmd_OnExeSetMotionDet` |  |
| 2007 | `0x24` | `Record Audio` | `CMD_MOVIE_AUDIO_SWITCH` | `WiFiCmd_OnExeSetMovieAudio` |  |
| 2008 | `0xb2` | `Date Stamp` | `CMD_WATERMARK_SWITCH_DATE` | `WiFiCmd_OnExeSetMovieDateImprint` |  |
| 2011 | `0x95` | `G-sensor` | `CMD_SET_G_SENSOR` | `WiFiCmd_OnExeSetMovieGSesnorSensitivity` |  |
| 2012 | `0x86` |  |  | `WiFiCmd_OnExeSetAutoRecording` |  |
| 2016 | `0x18` |  |  | `XML_GetMovieRecStatus` |  |
| 2020 | `0x2e` |  |  |  |  |
| 2021 | `0x2f` |  |  |  |  |
| 2022 | `0x30` |  |  |  |  |
| 2023 | `0x28` |  |  |  |  |
| 2024 | `0x31` |  |  |  |  |
| 3007 | `0x37` |  |  |  |  |
| 3008 | `0x39` |  | `CMD_SET_LANGUAGE` |  |  |
| 3009 | `0x3b` |  |  | `WiFiCmd_OnExeTV` |  |
| 3028 | `0x11` | `Live Video Source` |  |  |  |
| 3033 | `0x80` |  |  |  |  |
| 8053 | `0x71` | `Voice Notification Volume` | `CMD_SOUND_VOLUME` | `WiFiCmd_OnExeSetBeepVolume` |  |
| 8200 | `0xa2` |  | `CMD_SET_BITRATE` | `WiFiCmd_OnExeSetVideoBitrate` |  |
| 8201 | `0xa9` | `Wi-Fi Frequency` | `CMD_WIFI_FREQUENCY` |  |  |
| 8202 | `0x11` | `Live Video Source` | `CMD_CHANGE_VIDEO_SOURCE` |  |  |
| 8203 | `0x27` | `IR LED` | `CMD_IR_LED` |  |  |
| 8204 | `0x96` | `Parking G-sensor` | `CMD_PARKING_G_SENSOR` | `WiFiCmd_OnExeParkGsensorSens` |  |
| 8205 | `0x97` | `Parking Mode` | `CMD_PARKING_MODE` | `WiFiCmd_OnExeParkingMode` |  |
| 8206 | `0x26` | `Time-lapse Recording` | `CMD_TIME_LAPSE_RECORDING` |  |  |
| 8207 | `0x98` | `Parking Motion Detection` | `CMD_PARKING_MOTION_DETECTION` |  |  |
| 8208 | `0x92` | `GPS` | `CMD_GPS_SWITCH` |  |  |
| 8209 | `0x93` | `Speed Units` | `CMD_SPEED_UNIT` |  |  |
| 8210 | `0x94` |  | `CMD_WATERMARK_SWITCH_GPS` |  |  |
| 8211 | `0x3f` |  | `CMD_SET_DATE_FORMAT` | `WiFiCmd_OnExeSetDateFormat` |  |
| 8212 | `0x91` | `Time Zone` | `CMD_TIME_ZONE` | `WiFiCmd_OnExeSetZone` |  |
| 8213 | `0xa7` | `Brand Model Stamp` | `CMD_WATERMARK_SWITCH_MODEL` | `WiFiCmd_OnExeCameraModelStamp` |  |
| 8214 | `0x38` | `Beep Sound` | `CMD_BEEP_SOUND` | `WiFiCmd_OnExeBeep` |  |
| 8215 | `0x3a` | `Frequency` | `CMD_FREQUENCY` | `WiFiCmd_OnExeFrequency` |  |
| 8216 | `0x28` |  |  | `WiFiCmd_OnExeSensorRotate` |  |
| 8217 | `0xad` |  |  | `WiFiCmd_OnExeFlipMirror` |  |
| 8220 | `0x05` |  | `CMD_SET_EXPOSURE_FRONT` | `WifiCmdExe_CheckArgsType` |  |
| 8222 | `0x1a` | `Resolution` | `CMD_RECORD_RESOLUTION` | `WifiCmdExe_CheckArgsType` |  |
| 8223 | `0xa8` | `Boot Delay` | `CMD_BOOT_DELAY` | `WiFiCmd_OnExeSetBootDelay` |  |
| 8224 | `0xaa` |  |  | `WiFiCmd_OnExeSetSensor1Rotate` |  |
| 8226 | `0xab` | `Rear Image Rotate` | `CMD_IMAGE_REAR_ROTATION` | `WiFiCmd_OnExeSetSensor2Rotate` |  |
| 8225 | `0xac` | `Interior Image Rotate` | `CMD_IMAGE_INTERIOR_ROTATION` | `WiFiCmd_OnExeSetSensor3Rotate` |  |
| 8232 | `0x9a` | `Cut-off time` | `CMD_CAR_BATTERY_PROTECT_TIME_CLOSE` | `WiFiCmd_OnExeParkModeTimer` |  |
| 8233 | `0x99` | `Enter Parking Mode Timer` | `CMD_PARKING_DELAY` |  |  |
| 9220 | `0xae` | `Rear Image Mirror` | `CMD_IMAGE_REAR_MIRROR` | `WiFiCmd_OnExeSetSensor2Mirror` |  |
| 9219 | `0xaf` | `Interior Image Mirror` | `CMD_IMAGE_INTERIOR_MIRROR` | `WiFiCmd_OnExeSetSensor3Mirror` |  |
| 9221 | `0x9d` | `Voice Notification` | `CMD_VOICE_SWITCH` | `WiFiCmd_OnExeSetVoiceReport` |  |
| 8250 | `0x6d` | `Screen Saver` | `CMD_SCREEN_SAVER` | `WiFiCmd_OnExeSetAutoLcdOff` |  |
| 9224 | `0xb1` | `Front LED` | `CMD_NORMAL_LED_FRONT` | `WiFiCmd_OnExeSetLED` |  |
| 9226 | `0xb3` | `Front Parking LED` | `CMD_PARKING_LED_FRONT` | `WiFiCmd_OnExeSetParkingMonitorLED` |  |
| 9229 | `0xb9` | `Logo Stamp` | `CMD_WATERMARK_SWITCH_BRAND` | `WiFiCmd_OnExeSetWaterLogo` |  |
| 9230 | `0xb7` | `Custom Stamp` | `CMD_WATERMARK_CUSTOM_SWITCH` | `WiFiCmd_OnExeSetCustomStamp` |  |
| 9231 | `0xb8` | `License Plate Stamp` | `CMD_WATERMARK_PLATE_NUMBER_SWITCH` | `WiFiCmd_OnExeSetCarnumberStamp` |  |
| 9227 | `0x9f` | `Voice Control` | `CMD_AI_SPEECH_CONTROL` |  |  |
| 9225 | `0xc7` | `Parking GPS` | `CMD_PARKING_MODE_GPS` | `WiFiCmd_OnExeSetParkGps` |  |
| 9311 | `0xc6` | `Resolution Stamp` | `CMD_WATERMARK_SWITCH_HDR` | `WiFiCmd_OnExeSetHdrStamp` |  |
| 9312 | `0x9c` | `Format Reminder` | `CMD_FORMAT_REMIND` | `WiFiCmd_OnExeSetFormatRemind` |  |
| 9313 | `0xbf` | `Mic Button` | `CMD_BLUETOOTH_KEY_AUDIO_RECORD` | `WiFiCmd_OnExeSetBtKey1` |  |
| 9314 | `0xc0` | `Action Button` | `CMD_BLUETOOTH_KEY_ACTION` | `WiFiCmd_OnExeSetBtKey2` |  |
| 9321 | `0x41` | `Time Format` | `CMD_TIME_12_24__HOUR` | `WiFiCmd_OnExeSetHourFormat` |  |
| 9315 | `0xc3` | `Driving Recording Storage` | `CMD_SET_FILE_SAVE_LOCATION` | `WiFiCmd_OnExeSetStorageRec` | 0x1 |
| 9322 | `0xd2` | `Interior Camera` | `CMD_INNER_CAMERA_SWITCH` | `WiFiCmd_OnExeSetSensor2Switch` | 0x1 |
| 9347 | `0xe0` | `Rear Camera` | `CMD_REAR_CAMERA_SWITCH` | `WiFiCmd_OnExeSetSensor3Switch` | 0x1 |
| 9318 | `0x1c` |  | `CMD_HDR_FRONT` | `WiFiCmd_OnExeMovieWDR` | 0x1 |
| 9319 | `0xca` | `HDR Rear` | `CMD_HDR_REAR` | `WiFiCmd_OnExeSetHdrRear` | 0x1 |
| 9333 | `0xc9` | `HDR Interior` | `CMD_HDR_INTERIOR` | `WiFiCmd_OnExeSetHdrInterior` | 0x1 |
| 9320 | `0xcb` | `Parking HDR` | `CMD_PARKING_MODE_HDR` | `WiFiCmd_OnExeSetHdrParkMode` |  |
| 9323 | `0xa0` | `Daylight Saving` | `CMD_DST_SWITCH` | `WiFiCmd_OnExeSetDST` |  |
| 9329 | `0xd3` | `Rear LED` | `CMD_NORMAL_LED_REAR` | `WiFiCmd_OnExeSetRearLED` |  |
| 9330 | `0xce` | `Privacy Mode` | `CMD_PRIVACY_MODE_SWITCH` | `WiFiCmd_OnExeSetPrivacyMode` |  |
| 9331 | `0xcf` | `Stamp Text Color` | `CMD_HDR_TXT_COLOR` | `WiFiCmd_OnExeSetStampColor` |  |
| 9302 | `0xbd` |  |  |  |  |
| 9336 | `0xd4` | `Interior LED` | `CMD_SET_INTERIOR_LED` | `WiFiCmd_OnExeSetInteriorLED` |  |
| 9337 | `0xd5` | `Rear Parking LED` | `CMD_PARKING_LED_REAR` | `WiFiCmd_OnExeSetParkingRearLED` |  |
| 9338 | `0xd6` | `Interior Parking LED` | `CMD_PARKING_LED_INTERIOR` | `WiFiCmd_OnExeSetParkingInteriorLED` |  |
| 9339 | `0xd9` | `Interior Cam Fisheye Mode` | `CMD_CAR_CAMERA_INTERIOR_FISH_EYE` | `WiFiCmd_OnExeSetInteriorDewarpMode` | 0x1 |
| 9340 | `0xd7` | `Parking Recording Storage` | `CMD_PARKING_MODE_FILE_LOCATION` | `WiFiCmd_OnExeSetParkingStorage` |  |
| 9341 | `0xdd` | `Hybrid Parking mode` |  | `WiFiCmd_OnExeSetParkingHybirdMode` |  |
| 9342 | `0xde` | `Multiplex Video` | `CMD_VIDEO_MERGE` | `WiFiCmd_OnExeSetPipRecord` | 0x1 |
| 9343 | `0xdc` | `Cut-off Voltage` | `CMD_CAR_BATTERY_PROTECT_VOLTAGE_CLOSE` | `WiFiCmd_OnExeSetBatteryProtection` |  |
| 9356 | `0xe9` | `Cut-off BP100 Capacity` | `CMD_BP100_POWER_CUTOFF` | `WiFiCmd_OnExeSetBp100BatteryProtection` |  |
| 9348 | `0xe1` | `Vehicle Voltage Stamp` | `CMD_WATERMARK_CAR_VOLTAGE` | `WiFiCmd_OnExeSetVoltageStamp` |  |
| 9358 | `0xed` | `Battery pack Capacity Stamp` | `CMD_WATERMARK_BP100_STAMP` | `WiFiCmd_OnExeSetChargerStamp` |  |
| 9349 | `0xe3` | `Parking Impact Notification` | `CMD_PARKING_IMPACT_NOTIFICATION` | `WiFiCmd_OnExeSetParkImpactNotify` |  |
| 9362 | `0xec` | `Low Power Impact Recording` |  | `WiFiCmd_OnExeSetGspGeofenceStandby` |  |
| 9351 | `0xe4` | `Backup Impact Parking Videos` | `CMD_BAK_PARKING_FILE` | `WiFiCmd_OnExeSetParkBackupSSD` |  |
| 9352 | `0xe6` |  | `CMD_EXPORT_SETTINGS` | `WiFiCmd_OnExeSetExportSetting` |  |
| 9353 | `0xe7` |  |  | `WiFiCmd_OnExeSetImportSetting` |  |
| 9361 | `0xeb` | `Dewarp Front Cam` | `CMD_DEWARP_FRONT_CAM` | `WiFiCmd_OnExeSetDewarpFrontCam` | 0x1 |

### Non-settings — the other 77

These do not appear in `cmd=3014` because they are actions and getters, not stored
values.

| cmd | setting id | ini key | VIOFO key | firmware handler | blocks |
|-----|-----------|---------|-----------|------------------|--------|
| 1001 |  |  |  | `XML_GetPictureEnd` | 0x2 |
| 1003 |  |  |  |  |  |
| 2009 |  |  |  |  |  |
| 2013 |  |  |  |  |  |
| 2014 |  |  |  |  |  |
| 2017 |  |  |  | `WiFiCmd_OnExeTriggerMovieRawEnc` | 0x40 |
| 2018 |  |  |  | `XML_GetRawEncJpg` |  |
| 2019 |  |  |  |  |  |
| 2025 |  |  |  |  |  |
| 3001 |  |  |  | `WiFiCmd_OnExeModeChange` | 0x1 |
| 3002 |  |  |  | `XML_QueryCmd` |  |
| 3003 |  |  | `CMD_WIFI_SET_SSID` |  |  |
| 3004 |  |  | `CMD_WIFI_SET_PASSWORD` | `WiFiCmd_OnExeSetPassphrase` |  |
| 3005 |  |  | `CMD_SET_DATE` |  |  |
| 3006 |  |  |  |  |  |
| 3010 |  |  | `CMD_FORMAT_SD_CARD` |  | 0x10 |
| 3011 |  |  | `CMD_RESET_FACTORY` |  | 0x80 |
| 3012 |  |  | `CMD_SYSTEM_INFO` |  |  |
| 3013 |  |  |  |  | 0x20 |
| 3014 |  |  |  | `XML_QueryCmd_CurSts` |  |
| 3015 |  |  |  |  |  |
| 3016 |  |  |  |  |  |
| 3017 |  |  | `CMD_DISK_FREE_SPACE` |  |  |
| 3018 |  |  |  |  |  |
| 3019 |  |  |  |  |  |
| 3021 |  |  |  |  |  |
| 3022 |  |  |  |  |  |
| 3023 |  |  |  |  |  |
| 3024 |  |  |  |  |  |
| 3025 |  |  |  |  |  |
| 3026 |  |  |  |  |  |
| 3029 |  |  |  |  |  |
| 3030 |  |  |  |  |  |
| 3031 |  |  |  | `XML_GetMenuItem` |  |
| 3032 |  |  | `CMD_WIFI_SET_STA_SSID_PASSWORD` | `WiFiCmd_OnExeSendSSIDPassphrase` |  |
| 3034 |  |  |  | `XML_AutoTestCmdDone` |  |
| 3037 |  |  |  | `XML_GetCntModeStatus` |  |
| 3038 |  |  |  |  |  |
| 4001 |  |  |  | `XML_GetThumbnail` |  |
| 4002 |  |  |  | `XML_GetThumbnail` |  |
| 4005 |  |  |  | `XML_GetMovieFileInfo` |  |
| 4003 |  |  |  | `System_LockOrUnlockOneFile` |  |
| 4004 |  |  |  |  |  |
| 5001 |  |  |  | `XML_UploadFile` |  |
| 8003 |  |  |  |  |  |
| 8004 |  |  |  |  |  |
| 8058 |  |  |  |  |  |
| 8218 |  |  |  |  |  |
| 8219 |  |  | `CMD_WATERMARK_CUSTOM` |  |  |
| 8230 |  |  |  |  |  |
| 8231 |  |  |  |  |  |
| 8228 |  |  | `CMD_GET_PLATE_NUMBER` |  |  |
| 8229 |  |  |  |  |  |
| 8234 |  |  |  | `XML_SetParkModeRange` |  |
| 9222 |  |  |  |  |  |
| 9223 |  |  |  |  |  |
| 8260 |  |  |  | `XML_Get_Sensor_Status` |  |
| 8251 |  |  | `CMD_SET_HDR_TIME` |  |  |
| 8252 |  |  |  |  |  |
| 8006 |  |  |  | `XML_GetAiSpeechActiveInfo` |  |
| 8007 |  |  |  | `WiFiCmd_OnExeSetAiSpeechActiveInfo` | 0x100 |
| 9228 |  |  | `CMD_GET_AI_SPEECH_CONTENT` |  |  |
| 9310 |  |  |  |  |  |
| 9316 |  |  | `CMD_BAK_SDCARD_TO_SSD` | `XML_StorageManage_Process` |  |
| 9317 |  |  | `CMD_FORMAT_SSD` | `WiFiCmd_OnExeFormatSSD` | 0x10 |
| 9326 |  |  | `CMD_GET_SSD_FREE_SPACE` |  |  |
| 9327 |  |  |  |  |  |
| 9332 |  |  |  |  |  |
| 9328 |  |  |  |  |  |
| 9344 |  |  |  |  |  |
| 9345 |  |  |  |  |  |
| 9346 |  |  |  |  |  |
| 9357 |  |  |  |  |  |
| 9359 |  |  |  | `WiFiCmd_OnChangeBP100Mac` |  |
| 9350 |  |  | `CMD_PARKING_GEOFENCING` |  |  |
| 9360 |  |  |  | `XML_FileListUser_Set` |  |
| 9364 |  |  |  |  |  |

### Ones to be careful with

Recovered from string literals inside each handler:

| cmd | what it does |
|-----|--------------|
| 3010 | format the SD card |
| 3011 | factory reset |
| 3015 | `XML_DefaultFormat` |
| 3026 | **firmware update** — fetches `http://%s%s` into `A:\FWA329S.bin` |
| 3025 | OTA version check against `http://115.29.201.46:8020/download/filedesc.xml` |
| 4003 | delete one file |
| 5001 | file upload |
| 8230 | `system_reboot` |
| 8231 | quit the app |
| 9316 | SD↔SSD backup / SSD delete |
| 9317 | format the SSD |
| 9327 | change current storage, restarts capture |

And ones that are safe and useful: `3002` lists every command the camera supports,
`3012` is the firmware version, `3029` returns the SSID and passphrase in clear,
`8058` is a GPS fix with satellites and lat/lon/alt/speed, `8003` is the MAC address,
`2019` gives the live-view URLs (`rtsp://…/xxx.mov` and `http://…:8192`).

### `9352` and `9353` are toggles, not triggers

Both compile to a single `set_setting(id, par)` — `0xe6` for *Export Settings*,
`0xe7` for *Import Settings*:

```
443500  WiFiCmd_OnExeSetImportSetting
443510      mov  w0, #0xe7
443514      bl   4515c0             ; set_setting(id, par)
```

The export flag has a real consumer: `MenuConfig_SaveCfgFile` reads
`get_setting(0xe6)` and returns immediately when it is zero, so **`viofo_config.ini`
is only written while Export Settings is on.** That is exactly what went wrong when
`9352&par=0` was probed as if it were a read.

`0xe7` has no consumer at all in `V2.2_260815` — the only reads are a range-clamp and
the reset-to-defaults path. `cmd=9353` therefore stores a flag and imports nothing.
It is still a write to a persisted flag, so treat it as dangerous rather than as a
way to trigger an import.

## 6. What is not yet established

* ~~The mapping from ini key to command number~~ — resolved: it is the `setting_id`
  field of the dispatch table, §5.
* ~~The download URL for the exported file~~ — resolved: `GET /viofo_config.ini`.
* ~~The 22 commands present in `cmd=3014` but absent from VIOFO's table~~ — resolved;
  they are ordinary rows of the same table, listed in §5.
* **Authentication.** `cardv` contains an `Nvt_AuthGen` step and a
  `<CHK>%02X%02X</CHK>` field; whether either is ever required is untested. Nothing
  observed so far has needed it.
* **The value encodings.** Knowing that `8222` and `Resolution` are the same setting
  does *not* mean they use the same numbering — see below. A per-setting value table
  is still the missing piece for anything that wants to replay an ini over HTTP.
* **The `par` values `cmd=3031` accepts.** It reaches `XML_GetMenuItem`, which
  serialises a menu the caller supplies; a bare call answers `<Status>-21</Status>`.
  If some `par` enumerates menus, that is the route to on-screen labels.

### The encodings still differ, and the map does not fix that

With the setting id known, the two interfaces can be compared directly, and they
disagree on the value even where they agree on the setting:

| setting | id | in the ini | over HTTP |
|---|---|---|---|
| `Resolution` | `0x1a` | `26` | cmd 8222 = `2,7` — a packed front/rear pair |
| `Time Zone` | `0x91` | `6` | cmd 8212 = `28` |
| `Live Video Source` | `0x11` | `8` | cmd 8202 = `0` |
| EV front/interior/rear | `0x05` | three keys, `6` each | cmd 8220 = `6,6,6` |

So the earlier conclusion stands unchanged: **an ini cannot be replayed over HTTP by
substituting command numbers**, because the values need translating too and the
relationship is per-setting rather than a shift. What the map removes is the need to
guess *which* setting you are translating.

## 7. Do not derive the key→command mapping by matching names

**This section is history, not advice.** The mapping is now known exactly, from the
`setting_id` field in §5. It is kept because the way the shortcut failed is worth
knowing before reaching for a similar one on another device.

It is tempting to build the ini-key → command-number table automatically, by
scoring firmware key names against `CMD_KEY` names and comparing option lists.
That was tried. Against 81 ini settings and 92 A329S commands it produced 15
exact agreements, 13 strong, 30 plausible and 23 misses — and, more to the
point, it produced **confident wrong answers**:

| ini key | matcher said | actually |
|---|---|---|
| `Mic Button` | `9314 CMD_BLUETOOTH_KEY_ACTION` | `9313 CMD_BLUETOOTH_KEY_AUDIO_RECORD` (setting `0xbf`) |
| `Wi-Fi` | `2008 CMD_WATERMARK_SWITCH_DATE` | a Wi-Fi command |
| `Daylight Saving` | `2008 CMD_WATERMARK_SWITCH_DATE` | a clock command |

`Mic Button` and `Action Button` are adjacent Bluetooth key bindings whose names
differ by one token, so the matcher collapsed them onto the same command. A
mapping like that does not fail loudly — it quietly writes the wrong setting on
someone's camera. Names are not evidence.

### The empirical route — attempted, and what it showed

Both halves were captured from a live camera at the same moment: `GET
/viofo_config.ini` for the 81 settings by key name, and `cmd=3014` for the 93
settings by command number. Joining them purely on value gives:

| outcome | count |
|---|---|
| uniquely resolved | **0** |
| ambiguous — value collides with other commands | 69 |
| no command holds that value | 12 |

Zero. Almost every setting is `0` or `1`, so a single snapshot constrains almost
nothing. Splitting the 69 requires perturbation: change one setting, re-read
both, and see which pair moved together.

### The 12 non-matches are the more useful result

They are not missing settings — they are settings the two interfaces **encode
differently**:

| setting | in the ini | over HTTP |
|---|---|---|
| `Resolution` | `26` | cmd 8222 = `2,7` — a packed front/rear pair |
| `EV Front` / `EV Interior` / `EV Rear` | three keys, `6` each | cmd 8220 = `6,6,6` — one command, all three channels |
| `Time Zone` | `6` | cmd 8212 = `28` |
| `Live Video Source` | `8` | cmd 8202 = `0` |
| `Video Bitrate` | `3` | cmd 8200 = `2` |

(The remaining ones are the empty text fields and the two `hh:mm:ss` times.)

This matters more than the key mapping. Even a perfect key → command table would
not let you replay an ini over HTTP, because the *values* need translating too,
and the relationship is not a shift — it is per-setting. Anything that pushes ini
values straight at command numbers will write plausible-looking wrong settings.

So the remaining work is a per-setting value table, built by perturbation, not a
one-line join. Until it exists, the heuristic table is a research aid and is
deliberately not committed.


## 5.7 Settings as JSON, over HTTP only

`cmd=3014` already returns every setting with its current value, and every one
of those commands takes a write as `?custom=1&cmd=<n>&par=<v>`. That is a
complete round trip that never touches the card:

```sh
ViofoConfig --camera --export profile.json   # 93 settings, 88 writable
$EDITOR profile.json                         # change "value" fields
ViofoConfig --camera --plan  profile.json    # what would be written
ViofoConfig --camera --apply profile.json    # write it, reading each one back
```

Each entry carries the command number, the firmware setting id, the
`viofo_config.ini` key where there is one, the raw `value`, and a decoded
`label` for reading. **`value` is what gets written**; `label` is ignored on
apply, and an edit that puts a label there (`"On"` rather than `"1"`) is
reported and skipped rather than sent.

Five of the 93 are exported read-only:

| cmd | why |
| --- | --- |
| 2005, 8220, 8222 | multi-channel — they answer `6,6,6` / `2,7` for front, interior and rear at once, and a single `par=` cannot express that |
| 9352, 9353 | Export and Import Settings; writable only with `--allow-caution` |

`--apply` re-derives those refusals from the command number rather than
trusting the `writable` flag in the file, so hand-editing the flag does not
unlock a destructive command. Every write is read back, and the exit status is
non-zero if any did not take.

Verified end to end against a live A329S: export, edit `9321` (Time Format)
`0 -> 1`, apply, read back `1`, re-apply the original profile, read back `0`,
and a full `cmd=3014` diff against the session baseline showing no other
setting moved.