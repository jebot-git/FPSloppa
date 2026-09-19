#!/usr/bin/env python3
"""Summarize the real-renderer trajectory experiment and assemble its review images."""
import json
from pathlib import Path
import statistics
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/trajectory-light'
FONT = '/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf'


def main():
    report = json.loads((OUT / 'report.json').read_text())
    summary = {}
    for name in ['qsrc_dm6', 'tf_vesper']:
        rows = [r for r in report['records'] if r.get('map') == name and 'gpu_ms' in r]
        by_count = {count: statistics.mean(r['gpu_ms']['median'] for r in rows if r['segments'] == count)
                    for count in [-1, 0, 1, 4, 8]}
        summary[name] = {'gpu_ms_by_segments': by_count,
                         'gpu_delta_from_stock_ms': {c: v - by_count[-1] for c, v in by_count.items() if c >= 0},
                         'draw_call_medians': sorted({r['draws']['median'] for r in rows}),
                         'update_ms_median_range': [min(r['update_ms']['median'] for r in rows),
                                                    max(r['update_ms']['median'] for r in rows)]}
    report['summary'] = summary
    report['date'] = '2026-09-19'
    report['scope'] = 'Isolated prototype; no production shader changes; desktop Mobile/Vulkan only; no occlusion.'
    (OUT / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    (ROOT / 'docs/validation/trajectory-light.json').write_text(json.dumps(report, indent=2) + '\n')
    font = ImageFont.truetype(FONT, 19)
    sheet = Image.new('RGB', (1280, 840), '#111820')
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 10), 'Prototype: surface illumination without realtime light nodes', font=font, fill='white')
    for row, name in enumerate(['qsrc_dm6', 'tf_vesper']):
        for col, (variant, label) in enumerate([('emission-only', 'Emissive trail only'), ('trajectory', 'Trail + surface shader effect')]):
            x, y = col * 640, 48 + row * 394
            draw.text((x + 12, y), f'{name}  |  {label}', font=font, fill='white')
            source = Image.open(OUT / f'{name}-{variant}.png').convert('RGB')
            sheet.paste(source.resize((640, 360), Image.Resampling.LANCZOS), (x, y + 28))
    sheet.save(OUT / 'comparison.jpg', quality=94)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '30',
                    '-i', str(OUT / 'frames/%04d.png'), '-vf',
                    f"drawtext=fontfile={FONT}:text='Shader prototype - no realtime light nodes':x=20:y=20:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.7",
                    '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                    str(OUT / 'trajectory-demo.mp4')], check=True)
    print(json.dumps({'summary': summary, 'checks': len(report['checks']), 'failures': report['failures']}, indent=2))


if __name__ == '__main__':
    main()
