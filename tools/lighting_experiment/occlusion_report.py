#!/usr/bin/env python3
"""Publish measurements and visual comparisons for the BSP visibility prototype."""
import json
from pathlib import Path
from statistics import mean
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/trajectory-occlusion'


def main():
    report = json.loads((OUT / 'report.json').read_text())
    report['date'] = '2026-09-19'
    report['resolution'] = [1280, 720]
    report['msaa'] = 4
    report['scope'] = 'Isolated prototype; no production integration; desktop GPU only.'
    summary = {}
    for name in ['qsrc_dm6', 'tf_vesper']:
        rows = [r for r in report['records'] if r.get('map') == name and 'gpu_ms' in r]
        entries = []
        for count in [1, 4, 8]:
            baseline = [r for r in rows if r['segments'] == count and not r['occlusion']]
            enabled = [r for r in rows if r['segments'] == count and r['occlusion'] and r['local']]
            raw = mean(r['gpu_ms']['median'] for r in baseline)
            lit = mean(r['gpu_ms']['median'] for r in enabled)
            entries.append({'emitters': count, 'unoccluded_gpu_ms': raw, 'occluded_gpu_ms': lit,
                            'added_gpu_ms': lit - raw,
                            'script_update_ms': mean(r['update_ms']['median'] for r in enabled)})
        summary[name] = entries
    report['summary'] = summary
    report['visibility_queries'] = sum(r.get('queries', 0) for r in report['records'])
    (OUT / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    (ROOT / 'docs/validation/trajectory-occlusion.json').write_text(json.dumps(report, indent=2) + '\n')
    font = ImageFont.truetype('/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf', 19)
    sheet = Image.new('RGB', (1280, 1234), '#111820')
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 10), 'BSP visibility test - no realtime light nodes', font=font, fill='white')
    for row, (name, title) in enumerate([('wall', 'Wall / hidden floor'), ('thin-wall', '2 cm wall'), ('qsrc_dm6', 'Quake DM6')]):
        for col, (variant, label) in enumerate([('unoccluded', 'Before: distance only'), ('local', 'After: solid-space visibility')]):
            x, y = col * 640, 48 + row * 394
            draw.text((x + 12, y), f'{title} | {label}', font=font, fill='white')
            image = Image.open(OUT / f'{name}-{variant}.png').convert('RGB')
            sheet.paste(image.resize((640, 360), Image.Resampling.LANCZOS), (x, y + 28))
    sheet.save(OUT / 'comparison.jpg', quality=95)
    door = Image.new('RGB', (1280, 428), '#111820');draw = ImageDraw.Draw(door)
    for col, name in enumerate(['door-closed', 'door-open']):
        draw.text((col*640+12, 12), name+' | optimized BSP visibility', font=font, fill='white')
        door.paste(Image.open(OUT / f'{name}-local.png').resize((640, 360), Image.Resampling.LANCZOS), (col*640, 48))
    door.save(OUT / 'door-comparison.jpg', quality=95)
    print(json.dumps({'checks': len(report['checks']), 'rays': report['visibility_queries'],
                      'failures': report['failures'], 'summary': summary}, indent=2))


if __name__ == '__main__':
    main()
