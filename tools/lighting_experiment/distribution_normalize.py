#!/usr/bin/env python3
"""Preserve authored face styles in staged bakes, including compiler-pruned data."""
import json
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.lighting_experiment.distribution_bake import OUT
from tools.lighting_experiment.preserve_layout import preserve
from tools.lighting_experiment.bake import sha, verify
from tools.makkon.theme import lumps


def main():
    report = json.loads((OUT/'bake.json').read_text())
    catalog = json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())
    assert {r['id'] for r in report['maps']} == {r['id'] for r in catalog if r.get('distribution', 'base') == 'base'}
    for row in report['maps']:
        original = (OUT/'original'/(row['id']+'.bsp')).read_bytes()
        assert sha(original) == row['original_sha256']
        row.setdefault('compiler_bakes', row['bakes'].copy())
        for variant in ['off', 'low']:
            path = OUT/variant/(row['id']+'.bsp')
            raw = OUT/('raw-'+variant)/path.name
            raw.parent.mkdir(exist_ok=True)
            if not raw.exists():
                assert sha(path.read_bytes()) == row['compiler_bakes'][variant]['sha256']
                raw.write_bytes(path.read_bytes())
            assert sha(raw.read_bytes()) == row['compiler_bakes'][variant]['sha256']
            data, layout = preserve(original, raw.read_bytes())
            checks = verify(original, data)
            assert len(data) < 25_000_000
            path.write_bytes(data)
            row['bakes'][variant] = {'sha256': sha(data), 'bytes': len(data), **checks, **layout}
        before, bx = lumps((OUT/'off'/path.name).read_bytes())
        after, ax = lumps((OUT/'low'/path.name).read_bytes())
        assert all(before[i] == after[i] for i in range(15) if i != 8)
        assert len(before[8]) == len(after[8])
        row['ao_pair_preserves_topology_styles_allocation'] = True
        row['rgb_changed_bytes'] = sum(a != b for a, b in zip(dict(bx)[b'RGBLIGHTING'.ljust(24,b'\0')], dict(ax)[b'RGBLIGHTING'.ljust(24,b'\0')]))
        assert row['rgb_changed_bytes'] > 0, row['id']+': no AO difference'
        print(row['id'], 'PASS', row['rgb_changed_bytes'], 'RGB bytes changed', flush=True)
    report['layout_policy'] = 'Original face/style order; retain authored samples for styles pruned by compiler. Repack sample offsets only, with identical off/low allocation.'
    (OUT/'bake.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
