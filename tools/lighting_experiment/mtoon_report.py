#!/usr/bin/env python3
"""Collect real-avatar tests and the independently failing depth-pass control."""
import hashlib
import json
from pathlib import Path
from statistics import median

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'test-results/lighting-coverage'


def read(path):
    return json.loads((OUT/path).read_text())


def main():
    backends = ['mobile', 'gl_compatibility']
    runs = [read(f'mtoon-{backend}/result.json') for backend in backends]
    probes = [read(f'shimmer-{backend}/probe.json') for backend in backends]
    control = read('shimmer-gl_compatibility-prepass-on/probe.json')
    for run, probe in zip(runs, probes):
        assert len(run['records']) == 9 and not run['failures']
        assert len(probe['records']) == 3 and not probe['failures']
        assert probe['depth_prepass'] is False
    assert control['depth_prepass'] is True and len(control['failures']) == 3
    for row in control['records']:
        assert row['translation_comparisons'][0]['changed_fraction'] > .03
    performance = []
    for state in ('on', 'off'):
        data = read(f'gl_compatibility-prepass-{state}/render.json')
        assert not data['failures'] and len(data['records']) == 24
        performance.append(data)
    pairs = []
    for before in performance[0]['records']:
        after, = [r for r in performance[1]['records'] if
                  (r['id'], r['view'], r['pass']) == (before['id'], before['view'], before['pass'])]
        assert before['camera'] == after['camera'] and before['look'] == after['look']
        pairs.append({'map': before['id'], 'view': before['view'], 'pass': before['pass'],
                      'enabled_gpu_ms': before['gpu_ms']['median'], 'disabled_gpu_ms': after['gpu_ms']['median'],
                      'delta_ms': after['gpu_ms']['median']-before['gpu_ms']['median'],
                      'enabled_draws': before['draws']['median'], 'disabled_draws': after['draws']['median']})
    timing = {'pairs': pairs, 'median_delta_ms': median(r['delta_ms'] for r in pairs),
              'range_ms': [min(r['delta_ms'] for r in pairs), max(r['delta_ms'] for r in pairs)],
              'scope': 'Sequential current-source runs on three large maps; uncapped 1280x800 4xMSAA. GPU clocks and other system load uncontrolled.'}
    emission = {}
    for backend in backends:
        lines = (OUT/f'emission-{backend}.log').read_text().splitlines()
        result, = [json.loads(line.split('AVATAR_EMISSION_RESULT ', 1)[1]) for line in lines if line.startswith('AVATAR_EMISSION_RESULT ')]
        assert not result['failures']
        emission[backend] = result
    sources = ['project.godot', 'deathmatch/avatars/lighting.gd',
               'addons/Godot-MToon-Shader/mtoon_common.gdshaderinc',
               'tools/lighting_experiment/mtoon.gd', 'tools/lighting_experiment/shimmer.gd']
    report = {'status': 'pass', 'date': '2026-09-12', 'map_avatar_backend_combinations': 18,
              'maps': ['as_frigate (RGB)', 'tf_vesper (experimental RGB rebake)', 'softbox (grayscale diagnostic opt-in)'],
              'models': ['sample_d', 'sample_f', 'sample_g'], 'mtoon': runs, 'translation_regression': probes,
              'expected_failing_prepass_control': control, 'prepass_performance': timing, 'emission_regression': emission,
              'visual_review': 'Raw post-fix captures inspected: the reproduced OpenGL herringbone/speckled surface patches are absent. Average brightness alone was not sufficient to detect the original defect.',
              'limitations': ['One Linux Intel Arc A770 driver tested; no native Windows or Quest/Pico validation.',
                             'Small camera sweeps and static avatar poses; not a full animated multiplayer match.',
                             'Map contrast does not create light probes or change avatar illumination.',
                             'No pixel/color parity claimed between linear/HDR Mobile and sRGB Compatibility.'],
              'sha256': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources}}
    for target in (OUT/'mtoon-summary.json', ROOT/'docs/validation/lighting-mtoon.json'):
        target.write_text(json.dumps(report, indent=2)+'\n')
    page = '''<!doctype html><meta charset="utf-8"><title>MToon lighting and OpenGL regression</title>
<style>body{background:#171b21;color:#eef1f5;font:16px system-ui;margin:24px}select{font:inherit;margin:8px}main{display:grid;grid-template-columns:1fr 1fr;gap:20px}img{width:100%;max-width:800px}h2{font-size:18px}p{max-width:1100px}a{color:#8bc9ff}</style>
<h1>MToon: depth-prepass artifact and lighting coverage</h1>
<p>Raw 800×800 game captures. Click an image for full size. The original OpenGL patches occur with both lighting modes; switching the depth prepass off removes the reproduced defect. Mobile remains the default renderer.</p>
<label>Map <select id="map"><option>tf_vesper</option><option>as_frigate</option><option>external-optin</option></select></label>
<label>Avatar <select id="model"><option>sample_d</option><option>sample_f</option><option>sample_g</option></select></label>
<label>Lighting <select id="mode"><option>contrast</option><option>classic</option></select></label>
<label>View <select id="stage"><option>scene</option><option>dim</option><option>warm</option><option>cool</option><option>flash</option></select></label>
<main><section><h2>OpenGL before: depth prepass on</h2><a id="oldlink"><img id="old"></a></section><section><h2>OpenGL fixed: depth prepass off</h2><a id="fixedlink"><img id="fixed"></a></section>
<section><h2>Vulkan / Mobile</h2><a id="mobilelink"><img id="mobile"></a></section></main>
<p>Three avatars × RGB map, candidate TF bake and imported grayscale BSP × both renderers pass the numeric light-response checks. A separate translated-scene regression fails for all three avatars with the prepass enabled and passes with it disabled. <a href="mtoon-summary.json">Full results and performance</a> · <a href="review.html">Map coverage</a></p>
<script>function show(){const name=['map','model','mode','stage'].map(x=>document.getElementById(x).value).join('-')+'.png';for(const [id,folder] of [['old','mtoon-gl_compatibility-prepass-before'],['fixed','mtoon-gl_compatibility'],['mobile','mtoon-mobile']]){document.getElementById(id).src=folder+'/'+name;document.getElementById(id+'link').href=folder+'/'+name;}}document.querySelectorAll('select').forEach(x=>x.onchange=show);show();</script>'''
    (OUT/'mtoon-review.html').write_text(page)
    print('PASS: 18 map/avatar/backend combinations; 6 translation regressions; 3 expected negative controls')
    print('Prepass-off GPU median delta ms:', timing['median_delta_ms'], 'range:', timing['range_ms'])


if __name__ == '__main__':
    main()
