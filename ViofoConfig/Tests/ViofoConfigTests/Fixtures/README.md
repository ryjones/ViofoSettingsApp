# Test fixtures

`viofo_config.ini` is a real export from an A329S, kept byte-faithful to what the
camera writes so the parser is tested against genuine output rather than something
hand-written. One value is altered: the license plate is the placeholder
`EXAMPLE`. `Custom Text Stamp`, `STA mode SSID` and `STA mode password` were
already empty in the export and are left that way.

`ConfigDocumentTests.testFixtureCarriesNoRealPlate` fails if the plate is ever
anything else, which catches a live export being dropped in here by accident.
