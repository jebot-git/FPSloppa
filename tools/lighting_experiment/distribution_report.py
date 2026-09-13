#!/usr/bin/env python3
"""Check every AO comparison and summarize the current distribution sweep."""
import collections
import json
from pathlib import Path
from statistics import median
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2]/'test-results/lighting-ao-distribution'


def main():
    run = json.loads((OUT/'mobile/render.json').read_text())
    bakes = json.loads((OUT/'bake.json').read_text())
    assert not run['failures']
    assert len(run['records']) == len(bakes['maps'])*16
    groups = collections.defaultdict(list)
    for row in run['records']:
        groups[row['map'], row['view'], row['contrast']].append(row)
    pairs, images = [], []
    for (name, view, contrast), rows in groups.items():
        assert len(rows) == 4
        for key in ['draws', 'texture_bytes']:
            assert len({r[key]['median'] for r in rows}) == 1, (name, key)
        times = [median(r['gpu_ms']['median'] for r in rows if r['ao'] == flag) for flag in [False, True]]
        pairs.append({'id': name, 'view': view, 'contrast': contrast, 'gpu_delta_ms': times[1]-times[0]})
        stem = f'{name}-{view}-'+('contrast' if contrast else 'classic')
        off, low, restored = [np.asarray(Image.open(OUT/'mobile'/f'{stem}-{mode}.png').convert('RGB'), dtype=np.float32)[::2, ::2]/255 for mode in ['off','low','restored']]
        stable = np.max(np.abs(off-restored), axis=2) < .004
        assert stable.mean() > .5, name+': insufficient stable image area'
        delta = (off-low) @ np.array([.2126, .7152, .0722])
        images.append({'id': name, 'view': view, 'contrast': contrast, 'stable_fraction': float(stable.mean()),
                       'mean_darkening': float(delta[stable].mean()), 'darkened_fraction': float((delta[stable] > .01).mean())})
    for row in bakes['maps']:
        assert max(r['mean_darkening'] for r in images if r['id'] == row['id']) > .00001, row['id']+': no visible AO'
    report = {'groups': len(groups), 'measured_frames': run['measured_frames'], 'gpu': run['gpu'],
              'renderer': run['renderer'], 'failures': run['failures'], 'extra_draws': 0,
              'extra_texture_memory_in_paired_test': 0,
              'median_gpu_delta_ms': median(r['gpu_delta_ms'] for r in pairs),
              'gpu_delta_range_ms': [min(r['gpu_delta_ms'] for r in pairs), max(r['gpu_delta_ms'] for r in pairs)],
              'pairs': pairs, 'image_metrics': images}
    (OUT/'render-summary.json').write_text(json.dumps(report, indent=2)+'\n')
    print('PASS', len(bakes['maps']), 'maps;', run['measured_frames'], 'frames; median delta', report['median_gpu_delta_ms'], 'ms')


if __name__ == '__main__':
    main()
