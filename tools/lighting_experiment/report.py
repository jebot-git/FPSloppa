#!/usr/bin/env python3
"""Summarise paired timing blocks and create a local raw-screenshot comparison."""
import json
from pathlib import Path
from statistics import median

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'test-results/lighting'


def main():
    results = []
    for path in sorted(OUT.glob('*/profile.json')):
        profile = json.loads(path.read_text())
        groups = {}
        for row in profile['samples']:
            groups.setdefault((row['map'], row['bake'], row['view']), []).append(row)
        paired = []
        for (name, bake, view), rows in groups.items():
            assert len(rows) == 4 and sum(row['samples'] for row in rows) == 720
            assert len({row['draw_calls']['median'] for row in rows}) == 1
            assert len({row['texture_bytes'] for row in rows}) == 1
            a, b = [[r for r in rows if r['contrast'] == c] for c in (False, True)]
            gpu_a, gpu_b = [median(r['gpu_ms']['median'] for r in rs) for rs in (a, b)]
            paired.append(dict(map=name, bake=bake, view=view, classic_gpu_ms=gpu_a,
                               contrast_gpu_ms=gpu_b, delta_ms=gpu_b-gpu_a,
                               draw_calls=rows[0]['draw_calls']['median']))
        results.append(dict(renderer=profile['renderer'], gpu=profile['gpu'],
                            engine=profile['engine'], frames=sum(r['samples'] for r in profile['samples']),
                            median_paired_gpu_delta_ms=median(r['delta_ms'] for r in paired),
                            paired_delta_range_ms=[min(r['delta_ms'] for r in paired), max(r['delta_ms'] for r in paired)],
                            same_draw_counts_and_texture_memory=True,
                            max_setting_switch_ms=max(r['switch_ms'] for r in profile['samples']),
                            paired=paired))
    report = dict(experimental=True, default_enabled=False, baked_maps_promoted=False,
                  methodology='1280x800, 4x MSAA, vsync off; 45 warmup + 180 measured frames per block; classic/contrast/contrast/classic order; three views per map and bake; no actors; median of paired block medians. GPU clocks and OS scheduling are uncontrolled.',
                  limitations=['Desktop Intel Arc A770 only; no Android or headset measurements.',
                               'Static map microbenchmark, not multiplayer frame time.',
                               'Moving actors retain existing dynamic lighting; no baked probes implemented.',
                               'Existing static brush lightmaps do not change as lifts move.'],
                  bake=json.loads((OUT/'bake.json').read_text()), renderers=results)
    (OUT/'summary.json').write_text(json.dumps(report, indent=2)+'\n')
    target = ROOT/'docs/validation/lighting-experiment.json'
    target.write_text(json.dumps(report, indent=2)+'\n')
    options = ''.join(f'<option value="{r["renderer"]}">{r["renderer"]}</option>' for r in results)
    html = '''<!doctype html><meta charset="utf-8"><title>FPSloppa lighting experiment</title>
<style>body{background:#171b21;color:#edf0f4;font:16px system-ui;margin:24px}select{font:inherit;margin:8px}main{display:grid;grid-template-columns:1fr 1fr;gap:20px}img{width:100%}h2{font-size:18px}p{max-width:1000px}a{color:#87caff}</style>
<h1>FPSloppa lighting experiment</h1><p>Raw in-game screenshots at identical camera positions. Compare the shader independently from the rebake, or compare the combined change. No image enhancement. Shipping map files remain unchanged.</p>
<label>Renderer <select id="renderer">OPTIONS</select></label><label>View <select id="view">
<option value="tf_pressureworks|turbine">Pressureworks · turbine</option><option value="tf_pressureworks|hall">Pressureworks · hall</option><option value="tf_pressureworks|flag">Pressureworks · flag</option>
<option value="tf_vesper|nave">Vesper · nave</option><option value="tf_vesper|sanctuary">Vesper · sanctuary</option><option value="tf_vesper|lifts">Vesper · lifts</option></select></label>
<main><section><h2>Original bake · classic response</h2><img id="bc"></section><section><h2>Original bake · contrast response</h2><img id="be"></section><section><h2>AO / soft sun bake · classic response</h2><img id="cc"></section><section><h2>AO / soft sun bake · contrast response</h2><img id="ce"></section></main>
<p>Contrast is available in Settings → Graphics → Baked lighting. The rebakes are laboratory copies only. <a href="summary.json">Timing and geometry verification</a></p>
<script>function show(){const [m,v]=document.querySelector('#view').value.split('|'),r=document.querySelector('#renderer').value;for(const [id,b,s] of [['bc','baseline','classic'],['be','baseline','contrast'],['cc','candidate','classic'],['ce','candidate','contrast']])document.querySelector('#'+id).src=`${r}/${m}-${b}-${v}-${s}.png`;}document.querySelectorAll('select').forEach(s=>s.onchange=show);show();</script>'''.replace('OPTIONS', options)
    (OUT/'review.html').write_text(html)
    for item in results:
        print(item['renderer'], 'median paired GPU delta ms:', round(item['median_paired_gpu_delta_ms'], 4),
              'range:', item['paired_delta_range_ms'], 'frames:', item['frames'])


if __name__ == '__main__':
    main()
