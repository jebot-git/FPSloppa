#!/usr/bin/env python3
"""Benchmark direct BSP relighting on isolated copies; never publish map assets."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.makkon.theme import lumps, repack

OUT = ROOT / 'test-results/import-light-bake'
FLAGS = ['-novisapprox', '-threads', '4', '-extra4', '-bspxlit',
         '-bounce', '1', '-bouncecolorscale', '0.25', '-dirt', '1',
         '-dirtdepth', '32', '-dirtscale', '0.5']


def verify(original, candidate):
    before, bx = lumps(original)
    after, ax = lumps(candidate)
    for i in range(15):
        if i not in (0, 7, 8):
            assert before[i] == after[i], f'Non-lighting lump {i} changed'
    assert len(before[7]) == len(after[7])
    for i in range(0, len(before[7]), 20):
        assert before[7][i:i+12] == after[7][i:i+12], 'Face topology changed'
    def entities(data):
        return [dict(re.findall(rb'"([^"\n]*)"\s*"([^"\n]*)"', entity))
                for entity in re.findall(rb'\{([^{}]*)\}', data)]
    assert entities(before[0]) == entities(after[0]), 'Gameplay entities changed'
    rgb = next(data for key, data in ax if key.rstrip(b'\0') == b'RGBLIGHTING')
    assert len(rgb) == 3 * len(after[8])
    for key, data in bx:
        if key.rstrip(b'\0') not in (b'RGBLIGHTING', b'LIGHTINGDIR'):
            assert (key, data) in ax, f'Non-lighting BSPX {key!r} changed'
    return {'geometry_vis_collision_textures_entities_unchanged': True,
            'face_style_records_changed': sum(before[7][i+12:i+16] != after[7][i+12:i+16]
                                              for i in range(0, len(before[7]), 20)),
            'faces': len(after[7]) // 20, 'light_bytes': len(after[8]), 'rgb_bytes': len(rgb)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--light', type=Path, required=True)
    parser.add_argument('maps', nargs='+', type=Path)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'compiler': str(args.light.resolve()),
              'compiler_sha256': hashlib.sha256(args.light.read_bytes()).hexdigest(),
              'flags': FLAGS, 'maps': []}
    for source in args.maps:
        assert OUT.resolve() not in source.resolve().parents, 'Inputs must be outside probe output'
        original = source.read_bytes()
        parts, extras = lumps(original)  # This diagnostic is deliberately BSP29-only.
        world, tail = parts[0].split(b'}', 1)
        world = re.sub(rb'"_fpsloppa_(?:bake|atlas)"\s*"[^"]*"\s*', b'', world)
        enabled = list(parts)
        enabled[0] = world + b'"_fpsloppa_bake" "1"\n"_fpsloppa_atlas" "4096"\n}' + tail
        native = repack(enabled, extras)
        check, check_extras = lumps(native)
        assert check[1:] == parts[1:] and check_extras == extras
        name = source.stem
        for variant, data in [('original', original), ('native', native), ('rebaked', native)]:
            (OUT / f'{name}-{variant}.bsp').write_bytes(data)
        candidate = OUT / f'{name}-rebaked.bsp'
        start = time.monotonic()
        with (OUT / f'{name}.log').open('w') as log:
            subprocess.run([str(args.light.resolve()), *FLAGS, str(candidate)],
                           stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
        seconds = time.monotonic() - start
        result = verify(native, candidate.read_bytes())
        assert source.read_bytes() == original
        row = dict(name=name, source=str(source), sha256=hashlib.sha256(original).hexdigest(),
                   source_bytes=len(original), output_bytes=candidate.stat().st_size,
                   light_entities=len(re.findall(rb'"classname"\s*"light[^\"]*"', parts[0])),
                   native_light_bytes=len(parts[8]), bake_seconds=seconds,
                   native_nonentity_lumps_unchanged=True, **result)
        report['maps'].append(row)
        print(json.dumps(row), flush=True)
        (OUT / 'bake.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
