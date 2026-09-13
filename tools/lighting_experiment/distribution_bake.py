#!/usr/bin/env python3
"""Stage paired AO bakes for every base-distribution BSP, preserving originals."""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.lighting_experiment.ao_bake import COMMON, VARIANTS
from tools.lighting_experiment.bake import sha, verify
from tools.makkon.theme import lumps

OUT = ROOT/'test-results/lighting-ao-distribution'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--light', type=Path, required=True)
    args = parser.parse_args()
    compiler = args.light.resolve()
    rows = [r for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())
            if r.get('distribution', 'base') == 'base']
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'compiler': str(compiler), 'compiler_sha256': sha(compiler.read_bytes()),
              'common_flags': COMMON, 'variants': VARIANTS, 'maps': []}
    for row in rows:
        name = row['id']
        source = ROOT/row['path'].removeprefix('res://')
        original = source.read_bytes()
        baseline = OUT/'original'/source.name
        baseline.parent.mkdir(exist_ok=True)
        if baseline.exists():
            assert baseline.read_bytes() == original, 'Original snapshot differs: '+name
        else:
            baseline.write_bytes(original)
        result = {'id': name, 'source': str(source.relative_to(ROOT)),
                  'original_sha256': sha(original), 'bakes': {}}
        for variant, flags in VARIANTS.items():
            folder = OUT/variant
            folder.mkdir(exist_ok=True)
            path = folder/source.name
            shutil.copyfile(baseline, path)
            start = time.monotonic()
            with (folder/(name+'.log')).open('w') as log:
                subprocess.run([str(compiler), *COMMON, *flags, str(path)],
                               stdout=log, stderr=subprocess.STDOUT, check=True)
            candidate = path.read_bytes()
            try:
                checks = verify(original, candidate)
                before, _ = lumps(original)
                after, _ = lumps(candidate)
                for at in range(0, len(before[7]), 20):
                    assert (struct.unpack_from('<i', before[7], at+16)[0] < 0) == (struct.unpack_from('<i', after[7], at+16)[0] < 0), 'Lit/unlit face changed'
            except AssertionError as error:
                checks = {'rejected': str(error)}
            result['bakes'][variant] = {'sha256': sha(candidate),
                'seconds': time.monotonic()-start, 'bytes': len(candidate), **checks}
        off, _ = lumps((OUT/'off'/source.name).read_bytes())
        low, _ = lumps((OUT/'low'/source.name).read_bytes())
        result['ao_pair_preserves_topology_styles_allocation'] = (
            len(off[8]) == len(low[8]) and all(off[i] == low[i] for i in range(15) if i not in (7, 8))
            and len(off[7]) == len(low[7]) and all(off[7][i:i+16] == low[7][i:i+16]
            and (off[7][i+16:i+20] == b'\xff'*4) == (low[7][i+16:i+20] == b'\xff'*4)
            for i in range(0, len(off[7]), 20)))
        assert source.read_bytes() == original, 'Distribution changed while staging: '+name
        report['maps'].append(result)
        (OUT/'bake.json').write_text(json.dumps(report, indent=2)+'\n')
        print(name, 'pair', result['ao_pair_preserves_topology_styles_allocation'],
              {v: r.get('rejected', 'pass') for v, r in result['bakes'].items()}, flush=True)


if __name__ == '__main__':
    main()
