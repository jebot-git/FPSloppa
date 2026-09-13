"""Validate and summarize the isolated effect-lighting experiment."""
from pathlib import Path
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/effect-lighting'
data = json.loads((OUT / 'result.json').read_text())
assert data['renderer'] == 'mobile' and len(data['models']) == 8
assert len(data['records']) == 30
assert 'ERROR:' not in (OUT / 'render.log').read_text()
summary = []
for condition in ['dim', 'lit']:
    rows = [r for r in data['records'] if r['condition'] == condition]
    baseline = statistics.median(r['gpu_p50_ms'] for r in rows if r['effect_lights'] == 0)
    for count in [0, 2, 4, 8]:
        group = [r for r in rows if r['effect_lights'] == count]
        assert all(len(r['gpu_samples']) == 180 and min(r['gpu_samples']) > 0 for r in group)
        gpu = statistics.median(r['gpu_p50_ms'] for r in group)
        summary.append(dict(condition=condition, effects=count, gpu_p50_ms=gpu,
                            delta_from_condition_baseline_ms=gpu-baseline,
                            median_block_gpu_p95_ms=statistics.median(r['gpu_p95_ms'] for r in group),
                            draw_counts=sorted({r['draws'] for r in group}),
                            oversubscribed=condition == 'lit' and count == 8))
files = [OUT / 'result.json', OUT / 'render.log', *sorted(OUT.glob('*.png'))]
receipt = dict(complete=True, engine=data['engine'], gpu=data['gpu'], renderer=data['renderer'],
               size=data['size'], msaa=data['msaa'], measured_frames=5400,
               summary=summary, source_inputs=data['inputs'], models=data['models'],
               raw_files={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
               limitations=[data['limits'],
                            'Medians across three blocks, with two baseline samples per block. All raw samples retained.',
                            'The first dim baseline block was unusually slow (1.177 ms); other dim baselines were 0.422–0.423 ms. The aggregate median includes it.',
                            'No assertion that the oversubscribed 12-light case renders all 12 lights on each mesh.',
                            'This study adds diagnostic files only; game lighting behavior and defaults were not changed.',
                            'No standalone VR, Windows, thermal, animated-avatar, crowded BSP or full-match measurements.'])
(ROOT / 'docs/validation/effect-lighting-study.json').write_text(json.dumps(receipt, indent=2) + '\n')
for row in summary:
    print(row['condition'], row['effects'], round(row['gpu_p50_ms'], 3),
          'delta', round(row['delta_from_condition_baseline_ms'], 3), 'draws', row['draw_counts'])
