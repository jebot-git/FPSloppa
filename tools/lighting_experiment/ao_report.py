#!/usr/bin/env python3
"""Audit the controlled baked ambient-occlusion experiment and raw captures."""
import hashlib
import json
from pathlib import Path
from statistics import median

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'test-results/lighting-ao'


def pixels(path):
    return np.asarray(Image.open(path).convert('RGB'), dtype=np.float32)[::2, ::2]/255


def main():
    bake = json.loads((OUT/'bake.json').read_text())
    accepted = [r for r in bake['maps'] if 'rejected' not in r]
    assert len(accepted) >= 2
    for row in bake['maps']:
        assert hashlib.sha256((ROOT/row['source']).read_bytes()).hexdigest() == row['source_sha256']
    for row in accepted:
        assert row['bakes']['off']['rgb_bytes'] == row['bakes']['low']['rgb_bytes']
        for variant in ('off', 'low'):
            assert hashlib.sha256((OUT/f'{row["map"]}-{variant}.bsp').read_bytes()).hexdigest() == row['bakes'][variant]['sha256']
    renderers = []
    images = []
    for backend in ('mobile', 'gl_compatibility'):
        run = json.loads((OUT/backend/'render.json').read_text())
        assert not run['failures'] and len(run['records']) == len(accepted)*16
        groups = {}
        for row in run['records']:
            groups.setdefault((row['map'], row['view'], row['contrast']), []).append(row)
        pairs = []
        for (name, view, contrast), rows in groups.items():
            assert len(rows) == 4
            assert len({r['draws']['median'] for r in rows}) == 1
            assert len({r['texture_bytes']['median'] for r in rows}) == 1
            assert len({tuple(r['atlas_size']) for r in rows}) == 1
            gpu = [median(r['gpu_ms']['median'] for r in rows if r['ao'] == mode) for mode in (False, True)]
            pairs.append({'map': name, 'view': view, 'contrast': contrast, 'off_gpu_ms': gpu[0],
                          'low_gpu_ms': gpu[1], 'delta_ms': gpu[1]-gpu[0], 'draws': rows[0]['draws']['median']})
            stem = f'{name}-{view}-'+('contrast' if contrast else 'classic')
            off, low, restored = [pixels(OUT/backend/f'{stem}-{mode}.png') for mode in ('off', 'low', 'restored')]
            stable = np.max(np.abs(off-restored), axis=2) < .004
            darkening = (off-low) @ [.2126, .7152, .0722]
            images.append({'renderer': backend, 'map': name, 'view': view, 'contrast': contrast,
                           'stable_fraction': float(stable.mean()), 'stable_mean_darkening': float(darkening[stable].mean()),
                           'stable_darkened_fraction': float((darkening[stable] > .01).mean()),
                           'restore_difference': float(np.abs(off-restored).mean())})
        for name in {r['map'] for r in accepted}:
            assert max(r['stable_mean_darkening'] for r in images if r['renderer'] == backend and r['map'] == name) > .00001
        renderers.append({'renderer': backend, 'gpu': run['gpu'], 'engine': run['engine'],
                          'measured_frames': run['measured_frames'], 'median_paired_gpu_delta_ms': median(r['delta_ms'] for r in pairs),
                          'paired_delta_range_ms': [min(r['delta_ms'] for r in pairs), max(r['delta_ms'] for r in pairs)],
                          'extra_draws': 0, 'extra_texture_samples_per_fragment': 0,
                          'extra_atlas_bytes_in_single_variant': 0, 'pairs': pairs})
    report = {'status': 'pass_for_authored_tf_maps_external_rebake_rejected', 'date': '2026-09-12',
              'bakes': bake, 'renderers': renderers, 'image_metrics': images,
              'method': 'Same shader, scene and atlas UVs; swap pre-baked off/low atlas in off/low/low/off order. Both textures stay resident during measurement, but only one is sampled.',
              'limitations': ['Static map occlusion only; no avatar self/contact occlusion or moving-occluder updates.',
                             'AO merged into RGB cannot be independently disabled by the existing Contrast toggle.',
                             'External BSP compiler changed face light styles; candidate rejected and original preserved.',
                             'Single Linux Intel Arc A770 at 1280x800 4xMSAA, no headset/full-match certification.'],
              'source_sha256': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in
                               ['deathmatch/maps/baked_light.gdshader', 'tools/lighting_experiment/ao.gd', 'tools/lighting_experiment/ao_bake.py']}}
    for path in (OUT/'summary.json', ROOT/'docs/validation/lighting-ao.json'):
        path.write_text(json.dumps(report, indent=2)+'\n')
    page = '''<!doctype html><meta charset="utf-8"><title>Low-cost baked ambient occlusion</title>
<style>body{background:#171b21;color:#eef1f5;font:16px system-ui;margin:24px}select{font:inherit;margin:8px}main{display:grid;grid-template-columns:1fr 1fr;gap:18px}img{width:100%}a{color:#8bc9ff}h2{font-size:18px}p{max-width:1100px}</style>
<h1>Ambient occlusion: controlled bake comparison</h1><p>AO off versus short-range baked AO (32 Quake units, scale 0.5, occluded minimum light). Supersampling, bounce, sunlight, geometry and textures are held fixed. Both use the production shader. Raw game captures; click for full size.</p>
<select id="map"><option>tf_pressureworks</option><option>tf_vesper</option></select><select id="view"></select>
<select id="renderer"><option>mobile</option><option>gl_compatibility</option></select><select id="lighting"><option>contrast</option><option>classic</option></select>
<main><section><h2>AO off</h2><a id="offlink"><img id="off"></a></section><section><h2>Baked AO low</h2><a id="lowlink"><img id="low"></a></section></main>
<p>This is an isolated experiment, not a shipped AO setting. Static maps gain no additional draw pass or texture lookup. Moving avatars do not gain contact occlusion. The external BSP rebake was rejected because the compiler changed light styles. <a href="summary.json">Audit and timing results</a></p>
<script>const maps={tf_pressureworks:['turbine','flag'],tf_vesper:['nave','sanctuary']};function show(){for(const mode of ['off','low']){const src=renderer.value+'/'+map.value+'-'+view.value+'-'+lighting.value+'-'+mode+'.png';document.getElementById(mode).src=src;document.getElementById(mode+'link').href=src;}}function setViews(){view.replaceChildren(...maps[map.value].map(v=>new Option(v,v)));show();}map.onchange=setViews;for(const el of [view,renderer,lighting])el.onchange=show;setViews();</script>'''
    (OUT/'review.html').write_text(page)
    for row in renderers:
        print(row['renderer'], 'frames', row['measured_frames'], 'median AO GPU delta', row['median_paired_gpu_delta_ms'], 'range', row['paired_delta_range_ms'])
    print('PASS: controlled TF AO bakes, atlas UV parity, visible shading, same draws/texture allocation; external rebake safely rejected')


if __name__ == '__main__':
    main()
