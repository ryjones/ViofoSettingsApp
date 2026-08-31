# Test fixtures

`viofo_config.ini` is a real export from an A329S, kept byte-faithful to what the
camera writes so the parser is tested against genuine output rather than something
hand-written. One value is altered: the license plate is the placeholder
`EXAMPLE`. `Custom Text Stamp`, `STA mode SSID` and `STA mode password` were
already empty in the export and are left that way.

`ConfigDocumentTests.testFixtureCarriesNoRealPlate` fails if the plate is ever
anything else, which catches a live export being dropped in here by accident.

## `firmware-schema.json`

Ground truth for the schema, extracted from the camera firmware rather than the
manual. It is generated from the settings descriptor table in `/usr/bin/cardv`
(`.data:0x110dc20`) — the same table the camera walks when it writes
`viofo_config.ini` — so it is authoritative about *what the file contains*:
which keys exist, which section each belongs to, the order they are written in,
whether a value is an integer code, quoted text or a time, the numeric codes each
setting accepts, and the documented length cap on text fields.

The manual remains the source for what a setting *means*; the two are checked
against each other by `FirmwareSchemaTests`.

Regenerate with the tooling in the firmware project
(<https://github.com/ryjones/ViofoFirmwareThingy>):

```sh
CARDV=re/cardv python3 tools/re/gen_schema_json.py > firmware-schema.json
```

Extracted from `VIOFO_A329S_V2.2_260815` (u-boot build tag `20260815`). A
different firmware release may add or renumber settings, in which case
regenerate and let the tests point at what moved.
