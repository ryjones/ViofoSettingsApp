#!/usr/bin/env python3
"""Rebuild camera-commands.json from the firmware map plus VIOFO's option labels.

The command set, setting ids and ini keys come from api-map.json, which the
firmware project reads out of cardv's HTTP dispatch table -- see
docs/camera-http-api.md section 5. Only the option labels ("0=OFF; 1=ON") come
from VIOFO's app database, and those are carried over from the catalogue already
in the tree, because that database is not redistributed here.

Run from the repo root:

    tools/gen-camera-commands.py [path/to/api-map.json]

Merging rather than overwriting matters: this script is the only place the two
sources meet, and the labels are the half that cannot be regenerated.
"""
import json, os, re, sys

MAP = (sys.argv[1] if len(sys.argv) > 1
       else os.path.expanduser('~/W/ViofoFirmwareThingy/api-map.json'))
OUT = 'ViofoConfig/Sources/ViofoConfig/Resources/camera-commands.json'

if not os.path.exists(MAP):
    sys.exit(f"{MAP} not found -- regenerate it with tools/re/dump_api_table.py "
             f"in the firmware project, or pass its path as an argument.")

fw  = json.load(open(MAP))
old = json.load(open(OUT))
prev = {}
for c in old['commands']:
    prev.setdefault(c['cmd'], []).append(c)

def titlecase(s):
    return re.sub(r'(?<=[a-z0-9])(?=[A-Z])', ' ', s)

def title_for(r, keys):
    if r['ini_keys']:
        return r['ini_keys'][0]
    if keys:
        return ' '.join(w[:1] + w[1:].lower() for w in keys[0].replace('CMD_', '').split('_'))
    h = r['handler'] or ''
    for p in ('WiFiCmd_OnExeSet', 'WiFiCmd_OnExe', 'WifiCmd_', 'XML_Get', 'XML_'):
        if h.startswith(p):
            return titlecase(h[len(p):])
    return f"Setting 0x{r['setting_id']:02x}"

commands = []
for r in fw:
    if not r['setting_id']:
        continue                      # actions and getters, not settings; see api-map.json
    # Only VIOFO's own CMD_ names are harvested from the previous file. Anything
    # else there is a fallback this script synthesised on an earlier run, and
    # re-ingesting it would let those names decay -- WiFiCmd_OnExeMovieRec would
    # come back humanised as "Wificmd Onexemovierec". The previous catalogue had
    # already merged multiplexed commands into one entry with an aliases list, so
    # take both halves.
    keys = []
    for c in prev.get(r['cmd'], []):
        keys += [k for k in [c['key']] + c.get('aliases', []) if k.startswith('CMD_')]
    opts = next((c['options'] for c in prev.get(r['cmd'], []) if c.get('options')), None)
    e = {
        'cmd': r['cmd'],
        'key': keys[0] if keys else (r['handler'] or f"SETTING_{r['setting_id']:02X}"),
        'title': title_for(r, keys),
        'setting_id': r['setting_id'],
    }
    if len(keys) > 1: e['aliases'] = keys[1:]
    if r['ini_keys']: e['ini_keys'] = r['ini_keys']
    if r['section']:  e['section'] = r['section']
    if r['handler']:  e['handler'] = r['handler']
    if opts:          e['options'] = opts
    commands.append(e)

out = {
    'model': old['model'],
    'firmware_observed': old['firmware_observed'],
    'host': old['host'],
    'source': ("cardv's HTTP dispatch table at .data:0x11103d8, via "
               "tools/re/dump_api_table.py in the firmware project; option labels "
               "carried over from DASHCAM_MENU_INFO x CMD_MANAGER for "
               "DEVICE_MODEL='A329S' in VIOFO's iOS app. See docs/camera-http-api.md."),
    'destructive': old['destructive'],
    'caution': [9352, 9353],
    'commands': commands,
    'note': ("These are the settings: every command whose dispatch-table entry carries a "
             "non-zero setting id. That is exactly what cmd=3014 reports back — 93 of the "
             "170 commands the camera accepts. The other 77 are actions and getters and "
             "are listed in api-map.json in the firmware project, not here. Command "
             "numbers are not unique per setting, and neither are setting ids: 8220 "
             "carries front, interior and rear exposure at once and answers \"6,6,6\", "
             "while 3028 and 8202 are two commands for one setting (0x11)."),
    'destructive_note': old['destructive_note'],
    'caution_note': ("9352 and 9353 are Export Settings and Import Settings. Both are "
                     "toggles rather than triggers — a single set_setting() on ids 0xe6 "
                     "and 0xe7. 9352 gates the export: viofo_config.ini is written only "
                     "when you ask the camera to export, and only while 9352 is on, so "
                     "sending 9352&par=0 silently stops it exporting; that happened once "
                     "during this work. 0xe7 has no consumer at all in V2.2_260815, so "
                     "9353 stores a flag and imports nothing, but it is still a write to "
                     "persistent state. Neither is needed to read or write settings over "
                     "HTTP — use --camera --export/--apply instead."),
}
json.dump(out, open(OUT, 'w'), indent=1)
print(f"{len(commands)} settings written")
print("with option labels:", sum(1 for c in commands if c.get('options')))
print("named by VIOFO:", sum(1 for c in commands if c['key'].startswith('CMD_')))
print("named from firmware only:", sum(1 for c in commands if not c['key'].startswith('CMD_')))
