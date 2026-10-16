#!/usr/bin/env python3
"""Conservative, reproducible GDScript port inventory; static references are not runtime traces."""
import argparse
import collections
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
ENTRIES = ['deathmatch/entry.tscn', 'tools/voxel_battle/class_arena.tscn']
REF = re.compile(r'res://[A-Za-z0-9_./-]+\.(?:gd|tscn|tres)\b')
DIAGNOSTIC = re.compile(r'^(?:test|validate|benchmark|profile|preview|compare|evaluate|smoke|bake|stereo|render|capture)(?:_|\.)|(?:_test|_suite)(?:_|\.)')
UI = {'deathmatch/interface.gd', 'deathmatch/entry.gd', 'deathmatch/avatars/picker.gd',
      'deathmatch/conquest/classes/loadout_menu.gd', 'deathmatch/vr/calibration_preview.gd',
      'deathmatch/vr/keyboard.gd', 'deathmatch/vr/turn_panel.gd'}
ADAPTERS = {'animation', 'audio', 'destruction', 'movement', 'runtime', 'world'}


def destination(path):
    """Policy is explicit and ordered; mixed files need extraction, not blind translation."""
    name = Path(path).name
    if '/tests/' in path or (path.startswith('tools/') and DIAGNOSTIC.search(name)):
        return 'retain_tooling', 'offline', 'Tests, captures, benchmarks or offline baking'
    if path in UI or path.startswith('deathmatch/ui/') or path in {
        'deathmatch/settings/panel.gd', 'deathmatch/settings/bindings_panel.gd'}:
        return 'retain_ui', 'UI', 'Retain layouts/signals; extract polling, I/O and gameplay decisions'
    if path in {'deathmatch/vr/aim_support.gd', 'deathmatch/vr/virtual_stock.gd',
                'deathmatch/vr/swim_strokes.gd', 'deathmatch/vr/throw_ballistics.gd'}:
        return 'native_adapter', 'P2', 'Native interaction state/trajectory queries; retained independent scripted reference and geometry metadata'
    if path == 'tools/voxel_battle/weather_schedule.gd':
        return 'native_adapter', 'P4', 'Native deterministic weather/lightning sampling; retained independent reference'
    if path == 'deathmatch/avatars/ut_format.gd':
        return 'native_adapter', 'P6', 'Native bounded UTAV reader/inspector; keep scripted parser as an explicit test oracle'
    if path.startswith('deathmatch/native/'):
        if Path(path).stem in ADAPTERS:
            return 'native_adapter', 'P6', 'Existing native selector; replace optional production fallback with required capability checks'
        return 'native_port', 'P1', 'Native session/protocol/presentation; split legacy host branch from active client'
    if path.startswith('deathmatch/network/'):
        return 'native_port', 'P1', 'Move active session/interpolation bridges into native client state; quarantine legacy transport'
    if path.startswith('deathmatch/launcher/'):
        return 'native_port', 'P5', 'Native verified update/storage/process services; retain launcher view layout'
    if path.startswith('deathmatch/vr/') or path.startswith('deathmatch/haptics/'):
        return 'native_port', 'P2', 'FPSPose plus native interaction/input services; keep OpenXR engine integration'
    if path.startswith('deathmatch/avatars/'):
        return 'native_port', 'P3', 'FPSAvatar for lifecycle/LOD/equipment; native bounded import/cache service'
    if path.startswith(('tools/voxel_battle/', 'tools/streamed_heightfield/')):
        return 'native_port', 'P4', 'FPSWorld/FPSDestruction plus native environment scheduling; inspect reachability'
    if path.startswith(('deathmatch/audio/', 'deathmatch/voice/')):
        return 'native_port', 'P3', 'FPSAudio with native voice/cue/routing state; keep native engine audio devices'
    if path.startswith(('deathmatch/server/', 'deathmatch/bot_ai/', 'deathmatch/modes/')) or path in {
        'deathmatch/bots.gd', 'deathmatch/lag_compensation.gd', 'deathmatch/hit_detection.gd'}:
        return 'legacy_review', 'P6', 'CQ standalone authority already owns simulation; extract any shared client code before retirement'
    if path.startswith('deathmatch/'):
        return 'native_port', 'P3', 'Native client entity/gameplay/presentation services; separate retained UI where mixed'
    return 'retain_tooling', 'offline_review', 'Outside selected runtime roots; review dynamic resource loads before excluding'


def inventory():
    scripts = sorted(p for base in ('deathmatch', 'tools') for p in (ROOT / base).rglob('*.gd'))
    pending = list(ENTRIES)
    reached = set()
    while pending:
        path = pending.pop()
        if path in reached:
            continue
        file = ROOT / path
        if not file.is_file():
            continue
        reached.add(path)
        pending.extend(ref[6:] for ref in REF.findall(file.read_text(errors='replace')))
    rows = []
    for file in scripts:
        path = file.relative_to(ROOT).as_posix()
        source = file.read_text(errors='replace')
        action, phase, reason = destination(path)
        rows.append(dict(path=path, action=action, phase=phase, reason=reason,
                         lines=len(source.splitlines()), static_reference_reachable=path in reached,
                         callbacks=re.findall(r'^func\s+(_(?:process|physics_process|input|unhandled_input))\s*\(', source, re.M),
                         references=sorted(set(ref[6:] for ref in REF.findall(source)))))
    return dict(schema=1, entrypoints=ENTRIES,
                limitations='Static union of literal resource references, including inherited legacy branches. Dynamic loads may be missed; reachability is not execution, lines are not CPU cost. Classification is a migration recommendation, not completion status.',
                summary=dict(collections.Counter(r['action'] for r in rows)), scripts=rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/native-port-inventory.json')
    args = parser.parse_args()
    result = inventory()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(scripts=len(result['scripts']), actions=result['summary'], output=str(args.output))))


if __name__ == '__main__':
    main()
