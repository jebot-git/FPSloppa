#!/usr/bin/env python3
"""Summarize the paired static-rendering trial and produce a review contact sheet."""
from pathlib import Path
import json
import statistics
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/static-rendering'

def main():
    folder=OUT/'mobile'
    rendered=json.loads((folder/'render.json').read_text())
    assert not rendered['failures']
    groups={}
    for row in rendered['records']:groups.setdefault((row['map'],row['view']),[]).append(row)
    summary={}
    for variant in ['curve','mips','bake','combined']:
        gpu=[];gpu_p95=[];draws=[];memory=[];pixels=[]
        for (name,view),rows in groups.items():
            before=[r for r in rows if r['variant'] in ['baseline','restored']]
            after=[r for r in rows if r['variant']==variant]
            assert len(before)==2 and after
            gpu.append(statistics.mean(r['gpu_ms']['median'] for r in after)-statistics.mean(r['gpu_ms']['median'] for r in before))
            gpu_p95.append(statistics.mean(r['gpu_ms']['p95'] for r in after)-statistics.mean(r['gpu_ms']['p95'] for r in before))
            draws.append(after[0]['draws']['median']-before[0]['draws']['median'])
            memory.append(after[0]['texture_bytes']['median']-before[0]['texture_bytes']['median'])
            a=np.asarray(Image.open(folder/f'{name}-{view}-baseline.png').convert('RGB'),dtype=float)/255
            b=np.asarray(Image.open(folder/f'{name}-{view}-{variant}.png').convert('RGB'),dtype=float)/255
            pixels.append(float(np.abs(b-a).mean()))
        summary[variant]={'median_paired_gpu_delta_ms':statistics.median(gpu),'gpu_delta_range_ms':[min(gpu),max(gpu)],
            'median_paired_gpu_p95_delta_ms':statistics.median(gpu_p95),'gpu_p95_delta_range_ms':[min(gpu_p95),max(gpu_p95)],
            'draw_delta_range':[min(draws),max(draws)],'texture_allocation_delta_range':[min(memory),max(memory)],
            'mean_abs_rgb_delta':statistics.mean(pixels)}
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    views=[('tf_pressureworks','turbine'),('tf_pressureworks','flag'),('tf_vesper','nave'),('tf_vesper','sanctuary'),('qsrc_dm2','spawn0'),('ctf_deepvault','spawn0')]
    canvas=Image.new('RGB',(1280,180*len(views)),(12,12,12));draw=ImageDraw.Draw(canvas)
    for y,(name,view) in enumerate(views):
        for x,variant in enumerate(['baseline','curve','bake','combined']):
            image=Image.open(folder/f'{name}-{view}-{variant}.png').convert('RGB');image.thumbnail((320,160))
            canvas.paste(image,(x*320,y*180));draw.text((x*320+4,y*180+162),f'{name} {view} {variant}',fill='white')
    canvas.save(folder/'review.jpg')
    receipt=ROOT/'docs/validation/static-rendering.json'
    if receipt.exists():
        proof=json.loads(receipt.read_text());proof['summary']=summary;proof['measured_frames']=rendered['measured_frames']
        proof['render_failures']=rendered['failures']
        cache_log=(OUT/'cache.log').read_text()
        result=next(line for line in cache_log.splitlines() if line.startswith('STATIC_CACHE_RESULT '))
        proof['active_cache_validation']=json.loads(result.removeprefix('STATIC_CACHE_RESULT '))
        assert proof['active_cache_validation']['failures']==[]
        proof['unit_tests']={'colour_mips':'"failures":[]' in (OUT/'unit.log').read_text(),
            'lighting_profile':'LIGHTING_PROFILE_RESULT []' in (OUT/'profile.log').read_text(),
            'preferences':'CLIENT_PREFERENCES_RESULT []' in (OUT/'preferences.log').read_text()}
        assert all(proof['unit_tests'].values())
        receipt.write_text(json.dumps(proof,indent=2)+'\n')
    print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
