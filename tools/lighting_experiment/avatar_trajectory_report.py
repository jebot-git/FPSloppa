#!/usr/bin/env python3
"""Collect avatar-only lighting measurements and assemble review screenshots."""
import json
from pathlib import Path
from statistics import mean
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/avatar-trajectory'


def main():
    report = json.loads((OUT / 'report.json').read_text())
    summary = {}
    parity = []
    for name in ['sample_d', 'sample_f', 'sample_g', 'placeholder']:
        original = Image.open(OUT/f'{name}-original.png').tobytes()
        baseline = Image.open(OUT/f'{name}-baseline.png').tobytes()
        blocked = Image.open(OUT/f'{name}-blocked.png').tobytes()
        assert original == baseline == blocked, (name, 'off/blocked image parity')
        parity.append({'model': name, 'off_and_blocked_byte_identical': True})
        rows = [r for r in report['records'] if r.get('model') == name and 'gpu_ms' in r]
        timing = {count: mean(r['gpu_ms']['median'] for r in rows if r['emitters'] == count)
                  for count in [0, 1, 4]}
        draws = {r['draws']['median'] for r in rows}
        assert len(draws) == 1, (name, 'draw calls changed', draws)
        summary[name] = {'gpu_ms': timing, 'extra_1_ms': timing[1]-timing[0],
                         'extra_4_ms': timing[4]-timing[0], 'draws': list(draws)[0]}
    report['summary'] = summary
    report['full_image_parity'] = parity
    report['date'] = '2026-09-19'
    report['scope'] = 'Private shader prototypes; three MToon VRMs and opaque placeholder; no game integration.'
    (OUT / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    (ROOT / 'docs/validation/avatar-trajectory.json').write_text(json.dumps(report, indent=2) + '\n')
    font = ImageFont.truetype('/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf', 18)
    sheet = Image.new('RGB', (1200, 1360), '#111820');draw = ImageDraw.Draw(sheet)
    draw.text((12, 10), 'Avatar trail illumination - no realtime light nodes', font=font, fill='white')
    for row, name in enumerate(['sample_d', 'sample_f', 'sample_g', 'placeholder']):
        for col, (variant, label) in enumerate([('baseline', 'Baseline'), ('warm', 'Warm trail'), ('cool', 'Cool trail'), ('blocked', 'Blocked by wall')]):
            x, y = col*300, 42+row*328
            draw.text((x+8, y), f'{name} | {label}', font=font, fill='white')
            sheet.paste(Image.open(OUT/f'{name}-{variant}.png').convert('RGB').resize((300, 300), Image.Resampling.LANCZOS), (x, y+26))
    sheet.save(OUT/'comparison.jpg', quality=95)
    pair = Image.new('RGB', (1200, 640), '#111820');draw = ImageDraw.Draw(pair)
    for col, (variant, label) in enumerate([('baseline', 'DM6: baseline'), ('lit', 'DM6: avatar receiver enabled')]):
        draw.text((col*600+12, 10), label, font=font, fill='white')
        pair.paste(Image.open(OUT/f'dm6-{variant}.png').convert('RGB').resize((600,600),Image.Resampling.LANCZOS),(col*600,40))
    pair.save(OUT/'dm6-comparison.jpg',quality=95)
    print(json.dumps({'checks': len(report['checks']), 'failures': report['failures'], 'summary': summary},indent=2))


if __name__ == '__main__':
    main()
