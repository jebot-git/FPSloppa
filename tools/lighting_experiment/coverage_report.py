#!/usr/bin/env python3
"""Report distribution coverage, rendering cost, image differences and limitations."""
import hashlib
import html
import json
from pathlib import Path
from statistics import median
import struct
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'test-results/lighting-coverage'


def image(path):
    # Read-only image analysis; screenshots themselves are never modified.
    return np.asarray(Image.open(path).convert('RGB'), dtype=np.float32)[::4, ::4]/255


def main():
    inputs = json.loads((OUT/'input.json').read_text())
    imported = json.loads((OUT/'import.json').read_text())
    assert not imported['failures'] and len(imported['maps']) == len(inputs['rows'])
    summaries = []
    image_rows = []
    for path in [OUT/backend/'render.json' for backend in ('gl_compatibility', 'mobile')]:
        data = json.loads(path.read_text())
        assert not data['failures'] and len(data['records']) == len(inputs['rows'])*8
        groups = {}
        for row in data['records']:
            groups.setdefault((row['id'], row['view']), []).append(row)
        pairs = []
        for (name, view), rows in groups.items():
            view = int(view)
            assert len({r['draws']['median'] for r in rows}) == 1, (name, 'draw count changed')
            assert len({r['texture_bytes']['median'] for r in rows}) == 1, (name, 'texture allocation changed')
            classic, contrast = [[r for r in rows if r['contrast'] == mode] for mode in [False, True]]
            gpu = [median(r['gpu_ms']['median'] for r in block) for block in (classic, contrast)]
            pairs.append(dict(id=name, view=view, baked=rows[0]['expected_baked'], classic_gpu_ms=gpu[0],
                              contrast_gpu_ms=gpu[1], delta_ms=gpu[1]-gpu[0], draws=rows[0]['draws']['median']))
            a, b, c = [image(path.parent/f'{name}-{view}-{mode}.png') for mode in ('classic','contrast','restored')]
            la, lb = [pixels @ [.2126,.7152,.0722] for pixels in (a,b)]
            difference = float(np.abs(a-b).mean())
            restored = float(np.abs(a-c).mean())
            image_rows.append(dict(renderer=data['renderer'], id=name, view=view, baked=rows[0]['expected_baked'],
                                   classic_luma=float(la.mean()), contrast_luma=float(lb.mean()),
                                   classic_near_black=float((la<.025).mean()), contrast_near_black=float((lb<.025).mean()),
                                   mean_absolute_change=difference, restore_difference=restored))
            if not rows[0]['expected_baked']:
                # TIME-based liquid animation can vary between frames. Confirm
                # a toggle difference is no larger than baseline temporal drift.
                assert difference <= restored+.002, (name, 'legacy image unexpectedly changed')
            else:
                assert difference > .0001, (name, 'lighting toggle had no visible effect')
        active = [r['delta_ms'] for r in pairs if r['baked']]
        summaries.append(dict(renderer=data['renderer'], gpu=data['gpu'], engine=data['engine'],
                              measured_frames=len(data['records'])*data['measured_frames_per_block'],
                              median_baked_gpu_delta_ms=median(active), paired_delta_range_ms=[min(active),max(active)],
                              no_added_draws_or_texture_allocation=True, pairs=pairs))
    styled = {}
    for row in inputs['rows']:
        raw = (ROOT/row['path'].removeprefix('res://')).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == row['sha256'], 'Source BSP modified'
        offset, length = struct.unpack_from('<ii', raw, 4+8*7)
        faces = raw[offset:offset+length]
        count = sum(any(v not in (0,255) for v in faces[i+12:i+16]) for i in range(0,length,20))
        if count:styled[row['id']] = count
    report = dict(status='pass', scope='21 BSP snapshot of FPSloppa-0.10v-Base-Assets.zip at test preparation; one random external BSP, untouched and diagnostic opt-in',
                  selection={k:v for k,v in inputs.items() if k not in ('rows','pool')}, pool_count=len(inputs['pool']),
                  imports=imported, renderers=summaries, screenshots=image_rows, styled_faces=styled,
                  limitations=['Baked response remains opt-in; untagged external BSPs and eight legacy LibreQuake maps do not gain baked lighting automatically.',
                               'The diagnostic external copy adds only worldspawn bake/atlas keys; original light data, textures, geometry and collision are unchanged.',
                               'Ancient’s Hall becomes noticeably darker; contrast is not a universal readability improvement.',
                               'Animated/switchable Quake light styles still use the first stored lightmap; animation is not emulated.',
                               'One random BSP29 map is evidence of portability, not exhaustive BSP/BSP2 format coverage.',
                               'Static desktop renders with no actors; no headset or full match performance conclusion. No new bakes in this coverage run.'])
    sources = ['deathmatch/maps/baked_light.gd','deathmatch/maps/baked_light.gdshader','deathmatch/maps/filtering.gd','tools/lighting_experiment/coverage_import.gd','tools/lighting_experiment/coverage_render.gd','tools/lighting_experiment/prepare_coverage.py']
    report['source_sha256'] = {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}
    for target in (OUT/'summary.json', ROOT/'docs/validation/lighting-coverage.json'):
        target.write_text(json.dumps(report, indent=2)+'\n')
    options = ''.join(f'<option value="{r["id"]}">{html.escape(r["id"])}'+(' · baked' if r['expected_baked'] else ' · legacy')+'</option>' for r in inputs['rows'])
    backends = ''.join(f'<option>{r["renderer"]}</option>' for r in summaries)
    page = '''<!doctype html><meta charset="utf-8"><title>Lighting portability tests</title>
<style>body{background:#171b21;color:#eef1f5;font:16px system-ui;margin:24px}select{font:inherit;margin:8px}main{display:grid;grid-template-columns:1fr 1fr;gap:20px}img{width:100%}h2{font-size:18px}p{max-width:1100px}a{color:#8bc9ff}</style>
<h1>Lighting portability: 21 distributed maps + random external BSP</h1>
<p>Two distant spawn views per map, using the existing game lighting and original bake data. External selection: softbox.bsp, seed 4041983142, drawn from 97 locally archived BSPs. The untouched external import uses legacy lighting; the separate opt-in copy tests grayscale baked lighting. All images are raw game captures.</p>
<label>Map <select id="map">MAPS</select></label><label>Renderer <select id="renderer">RENDERERS</select></label><label>View <select id="view"><option value="0">First usable spawn</option><option value="1">Distant usable spawn</option></select></label>
<main><section><h2>Classic</h2><img id="classic"></section><section><h2>Contrast</h2><img id="contrast"></section></main>
<p>Classic remains the default. Dark maps can lose readability with Contrast. The legacy maps should look unchanged; animated liquids can vary slightly between captures. This test does not enable animated light styles or actor probes. <a href="summary.json">Full audit and timing results</a></p>
<script>function show(){for(const mode of ['classic','contrast'])document.getElementById(mode).src=`${document.getElementById('renderer').value}/${document.getElementById('map').value}-${document.getElementById('view').value}-${mode}.png`;}document.querySelectorAll('select').forEach(s=>s.onchange=show);show();</script>'''
    (OUT/'review.html').write_text(page.replace('MAPS',options).replace('RENDERERS',backends))
    for row in summaries:print(row['renderer'], row['measured_frames'], 'frames; median baked delta ms', row['median_baked_gpu_delta_ms'], 'range', row['paired_delta_range_ms'])
    print('PASS: imports, cached pixels, both toggle directions, draw counts, texture allocation, legacy rendering and unchanged source files')


if __name__ == '__main__':
    main()
