#!/usr/bin/env python3
"""Controlled baked-AO comparison; all output stays in the test directory."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.lighting_experiment.bake import sha, verify
from tools.makkon.theme import lumps

OUT = ROOT/'test-results/lighting-ao'
COMMON = ['-threads', '8', '-extra4', '-bspxlit', '-bounce', '1',
          '-bouncecolorscale', '0.25', '-sunlight_penumbra', '4']
VARIANTS = {'off': ['-dirt', '0', '-minlight_dirt', '0'],
            'low': ['-dirt', '1', '-dirtdepth', '32', '-dirtscale', '0.5', '-minlight_dirt', '1']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--light', type=Path, required=True)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    compiler = args.light.resolve()
    report = {'compiler': str(compiler), 'compiler_sha256': sha(compiler.read_bytes()),
              'common_flags': COMMON, 'variants': VARIANTS, 'maps': []}
    sources = {name: ROOT/'maps'/f'{name}.bsp' for name in ['tf_pressureworks', 'tf_vesper']}
    sources['external-optin'] = ROOT/'test-results/lighting-coverage/external-optin.bsp'
    for name, source in sources.items():
        original = source.read_bytes()
        row = {'map': name, 'source': str(source.relative_to(ROOT)), 'source_sha256': sha(original), 'bakes': {}}
        for variant, flags in VARIANTS.items():
            path = OUT/f'{name}-{variant}.bsp'
            path.write_bytes(original)
            start = time.monotonic()
            with (OUT/f'{name}-{variant}.log').open('w') as log:
                subprocess.run([str(compiler), *COMMON, *flags, str(path)], stdout=log,
                               stderr=subprocess.STDOUT, check=True)
            data = path.read_bytes()
            try:
                validation = verify(original, data)
            except AssertionError as error:
                row['rejected'] = str(error)
                break
            row['bakes'][variant] = {'sha256': sha(data), 'seconds': time.monotonic()-start,
                                     'bytes': len(data), **validation}
        if 'rejected' in row:
            assert source.read_bytes() == original
            report['maps'].append(row)
            print(name, 'REJECTED:', row['rejected'], flush=True)
            continue
        before, bx = lumps((OUT/f'{name}-off.bsp').read_bytes())
        after, ax = lumps((OUT/f'{name}-low.bsp').read_bytes())
        # Parallel light compilation may reorder sample offsets. Face topology,
        # styles and lit/unlit classification must remain fixed; the renderer
        # independently checks the repacked atlas UVs before swapping textures.
        for offset in range(0, len(before[7]), 20):
            assert before[7][offset:offset+16] == after[7][offset:offset+16]
            assert (before[7][offset+16:offset+20] == b'\xff'*4) == (after[7][offset+16:offset+20] == b'\xff'*4)
        assert len(before[8]) == len(after[8]), 'AO changed light sample allocation'
        assert source.read_bytes() == original
        row['ao_only_changes_light_samples_and_offsets'] = all(before[i] == after[i] for i in range(15) if i not in (7, 8))
        assert row['ao_only_changes_light_samples_and_offsets']
        report['maps'].append(row)
        print(name, row['bakes'], flush=True)
    (OUT/'bake.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
