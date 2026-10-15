"""Archive controlled UT99 baked-light shader timings and unchanged captures (requires Pillow)."""
from pathlib import Path
import csv,json,statistics,shutil
from PIL import Image,ImageChops,ImageStat
ROOT=Path(__file__).resolve().parents[2]
s=ROOT/'test-results/avatar-headlights';d=ROOT/'docs/validation/voxel-battle/headlight-comparison-20261015/avatar-shader';d.mkdir(parents=True,exist_ok=True)
r=json.loads((s/'results.json').read_text());frames=r.pop('frames');assert len(frames)==1440
with (d/'frames.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=list(frames[0]),lineterminator='\n');w.writeheader();w.writerows(frames)
r['summaries']={}
for n in [1,32]:
 r['summaries'][str(n)]={}
 for m in ['pixel_bake','vertex_bake']:
  a=[f for f in frames if f['label'].startswith(f'{n}:{m}:')];assert len(a)==360
  r['summaries'][str(n)][m]={k:{'median':statistics.median(f[k] for f in a),'p95':sorted(f[k] for f in a)[int(len(a)*.95)]} for k in ['gpu_ms','wall_ms','render_cpu_ms']}
  r['summaries'][str(n)][m]['triangles']=sorted(set(f['triangles'] for f in a));shutil.copy2(s/f'{n}-{m}.png',d/f'{n}-{m}.png')
 assert r['summaries'][str(n)]['pixel_bake']['triangles']==r['summaries'][str(n)]['vertex_bake']['triangles']
 a=Image.open(s/f'{n}-pixel_bake.png').convert('RGB');b=Image.open(s/f'{n}-vertex_bake.png').convert('RGB');diff=ImageChops.difference(a,b)
 r['summaries'][str(n)]['image_difference_8bit']={'mean_rgb':ImageStat.Stat(diff).mean,'maximum':max(hi for lo,hi in diff.getextrema())}
r['frames']=len(frames);(d/'results.json').write_text(json.dumps(r,indent=2)+'\n')

print(d)
