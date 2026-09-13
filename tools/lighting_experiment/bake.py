#!/usr/bin/env python3
"""Relight isolated copies of the two TF arenas; never replace shipping assets."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.makkon.theme import lumps

FLAGS = ['-threads', '8', '-extra4', '-bspxlit', '-dirt', '1',
         '-dirtdepth', '64', '-dirtscale', '0.65', '-minlight_dirt', '1',
         '-minlight', '24', '-sunlight_penumbra', '4', '-bounce', '1',
         '-bouncecolorscale', '0.25']


def sha(data):
    return hashlib.sha256(data).hexdigest()


def verify(original, candidate):
    before, bx = lumps(original)
    after, ax = lumps(candidate)
    # Lighting compilation may repack face light offsets and entity text only.
    for i in range(15):
        if i not in (0, 7, 8):
            assert before[i] == after[i], f'Non-lighting lump {i} changed'
    assert len(before[7]) == len(after[7])
    for i in range(0, len(before[7]), 20):
        assert before[7][i:i+16] == after[7][i:i+16], 'Face topology/styles changed'
    def entities(data):
        import re
        return [dict(re.findall(rb'"([^"\n]*)"\s*"([^"\n]*)"', entity))
                for entity in re.findall(rb'\{([^{}]*)\}', data)]
    assert entities(before[0]) == entities(after[0]), 'Gameplay entities changed'
    assert before[8] != after[8], 'No change to lighting'
    rgb = next(data for key, data in ax if key.rstrip(b'\0') == b'RGBLIGHTING')
    assert len(rgb) == 3 * len(after[8])
    for key, data in bx:
        if key.rstrip(b'\0') not in (b'RGBLIGHTING', b'LIGHTINGDIR'):
            assert (key, data) in ax, f'Non-lighting BSPX {key!r} changed'
    return {'geometry_vis_collision_textures_entities_unchanged': True,
            'faces': len(after[7]) // 20, 'light_bytes': len(after[8]),
            'rgb_bytes': len(rgb)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--light', type=Path, required=True, help='ericw-tools v0.18 light executable')
    parser.add_argument('--output', type=Path, default=ROOT/'test-results/lighting')
    args = parser.parse_args()
    out = args.output.resolve()
    assert out != ROOT/'maps' and ROOT/'maps' not in out.parents
    out.mkdir(parents=True, exist_ok=True)
    report = {'compiler': str(args.light), 'compiler_sha256': sha(args.light.read_bytes()),
              'flags': FLAGS, 'maps': []}
    for name in ('tf_pressureworks', 'tf_vesper'):
        source = ROOT/'maps'/f'{name}.bsp'
        original = source.read_bytes()
        baseline = out/f'{name}-baseline.bsp'
        candidate = out/f'{name}-candidate.bsp'
        assert source.resolve() not in (baseline.resolve(), candidate.resolve())
        shutil.copyfile(source, baseline)
        shutil.copyfile(source, candidate)
        start = time.monotonic()
        with (out/f'{name}-bake.log').open('w') as log:
            subprocess.run([str(args.light.resolve()), *FLAGS, str(candidate)],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        elapsed = time.monotonic() - start
        data = candidate.read_bytes()
        result = verify(original, data)
        assert source.read_bytes() == original, 'Shipping BSP modified'
        report['maps'].append(dict(map=name, baseline_sha256=sha(original),
                                  candidate_sha256=sha(data), seconds=elapsed,
                                  baseline_bytes=len(original), candidate_bytes=len(data), **result))
        print(json.dumps(report['maps'][-1]), flush=True)
    (out/'bake.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
