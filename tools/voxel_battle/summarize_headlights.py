"""Archive an unchanged render comparison, raw timings and standalone HTML viewer."""
from pathlib import Path
import base64,csv,json,statistics,shutil
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'test-results/headlight-comparison'
DEST=ROOT/'docs/validation/voxel-battle/headlight-comparison-20261015'
DEST.mkdir(parents=True,exist_ok=True)
report=json.loads((SOURCE/'results.json').read_text())
frames=report.pop('frames')
assert len(frames)==4320
with (DEST/'frames.csv').open('w') as f:
 writer=csv.DictWriter(f,fieldnames=list(frames[0]),lineterminator='\n');writer.writeheader();writer.writerows(frames)
def stats(values):
 values=sorted(values)
 return dict(median=statistics.median(values),p95=values[int(len(values)*.95)],maximum=values[-1])
summaries={}
views=['factory','driver','driver_player','driver8','driver8_player','road']
for view in views:
 summaries[view]={}
 for mode in ['off','vertex','mixed']:
  rows=[r for r in frames if r['label'].startswith(view+':'+mode+':')]
  assert len(rows)==240 and all(r['gpu_ms']>0 for r in rows)
  summaries[view][mode]={k:stats([r[k] for r in rows]) for k in ['gpu_ms','wall_ms','render_cpu_ms','setup_cpu_ms','view_us']}
  summaries[view][mode]['renderer_cpu_total_ms']=stats([r['render_cpu_ms']+r['setup_cpu_ms'] for r in rows])
  summaries[view][mode]['draw_calls']=sorted(set(r['draw_calls'] for r in rows))
  summaries[view][mode]['triangles']=sorted(set(r['triangles'] for r in rows))
  summaries[view][mode]['repeats']={str(i):stats([r['gpu_ms'] for r in rows if r['label'].endswith(':'+str(i))]) for i in [0,1]}
 assert summaries[view]['vertex']['triangles']==summaries[view]['mixed']['triangles']
 assert summaries[view]['vertex']['draw_calls']==summaries[view]['mixed']['draw_calls']
 for mode in ['off','vertex','mixed']:shutil.copy2(SOURCE/f'{view}-{mode}.png',DEST/f'{view}-{mode}.png')
report['summaries']=summaries;report['captured_frames']=len(frames)
(DEST/'results.json').write_text(json.dumps(report,indent=2)+'\n')
images={f'{v}-{m}':'data:image/png;base64,'+base64.b64encode((DEST/f'{v}-{m}.png').read_bytes()).decode() for v in views for m in ['off','vertex','mixed']}
titles={'factory':'Factory exterior · 2 cones','driver':'Driver view · 2 cones','driver8':'Same driver view · 8-cone lighting stress','driver_player':'Driver + player · 2 cones','driver8_player':'Driver + player · 8 cones','road':'Open road · 2 cones'}
rows=''.join(f'<tr><td>{titles[v]}</td>'+''.join(f'<td>{summaries[v][m]["gpu_ms"]["median"]:.2f}</td>' for m in ['off','vertex','mixed'])+f'<td>+{summaries[v]["mixed"]["gpu_ms"]["median"]-summaries[v]["vertex"]["gpu_ms"]["median"]:.2f}</td></tr>' for v in views)
html='''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CQ headlight render comparison</title><style>
body{background:#10181c;color:#e6ecee;font:16px system-ui;margin:24px;max-width:1800px}h1{font-size:25px}p{max-width:1000px;line-height:1.5}button{font:inherit;padding:9px 14px;margin:4px;color:inherit;background:#23333b;border:1px solid #526771;border-radius:5px;cursor:pointer}button.active{background:#235851}.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:12px 0}img{width:100%;display:block;border:1px solid #43545c}figcaption{padding:8px 0;font-weight:600}table{border-collapse:collapse;margin:20px 0}th,td{padding:9px 14px;border-bottom:1px solid #43545c;text-align:right}th:first-child,td:first-child{text-align:left}details{max-width:850px;margin:15px 0}summary{cursor:pointer}small{color:#b4c4cb}@media(max-width:850px){.pair{grid-template-columns:1fr}body{margin:12px}}
</style><h1>CQ headlights: vertex-only versus mixed</h1>
<p>Original 1280 × 720 night renders, with identical cameras, lamp positions, beam strength and range. Vertex-only samples every supported receiver at vertices. Mixed retains vertex sampling on terrain and evaluates other supported receivers per pixel. Images have no exposure enhancement.</p>
<nav id="views"></nav><h2 id="title"></h2><div class="pair"><figure><figcaption id="vc"></figcaption><img id="vertex" alt="Vertex-only headlight render"></figure><figure><figcaption id="mc"></figcaption><img id="mixed" alt="Mixed headlight render"></figure></div>
<details><summary>Show headlights-off control</summary><img id="off" alt="Headlights off"></details>
<h2>GPU time in milliseconds · median</h2><table><thead><tr><th>Scene</th><th>Off</th><th>Vertex</th><th>Mixed</th><th>Mixed − vertex</th></tr></thead><tbody>TABLE</tbody></table>
<p>Measured on Intel N95 integrated graphics, Godot 4.7.2 Forward+, V-sync off. Each entry combines two 120-frame samples with reversed mode order; scene residency/LOD is frozen. Renderer CPU time is roughly unchanged. The 8-cone stress uses the exact same driver geometry and adds three lamp pairs without extra vehicle meshes.</p>
<small>The player views contain a frozen-pose UT99 Malcolm soldier. The render probe excludes shadows, normal-dependent headlight shading, network/controller work and populated gameplay simulation. GPU timing cannot be transferred to an unspecified GPU paired with an i7-12700. Raw samples and p95 results accompany this file.</small>
<script>const images=IMAGES,titles=TITLES,stats=STATS;
function show(v){document.getElementById('title').textContent=titles[v];for(const m of ['off','vertex','mixed'])document.getElementById(m).src=images[v+'-'+m];document.getElementById('vc').textContent='Vertex-only · '+stats[v].vertex.gpu_ms.median.toFixed(2)+' ms GPU';document.getElementById('mc').textContent='Mixed · '+stats[v].mixed.gpu_ms.median.toFixed(2)+' ms GPU';for(const b of document.querySelectorAll('button'))b.classList.toggle('active',b.dataset.view===v)}
for(const v of ['factory','driver','driver_player','driver8','driver8_player','road']){const b=document.createElement('button');b.textContent=titles[v];b.dataset.view=v;b.onclick=()=>show(v);document.getElementById('views').appendChild(b)}show('driver_player');</script>'''
html=html.replace('TABLE',rows).replace('IMAGES',json.dumps(images)).replace('TITLES',json.dumps(titles)).replace('STATS',json.dumps(summaries))
avatar_root=DEST/'avatar-shader'
if (avatar_root/'results.json').exists():
 avatar=json.loads((avatar_root/'results.json').read_text())['summaries']['32']
 figures=''
 for mode,title in [('pixel_bake','Reference · pixel baked lookup'),('vertex_bake','Optimized · vertex baked lookup')]:
  data=base64.b64encode((avatar_root/f'32-{mode}.png').read_bytes()).decode()
  figures+=f'<figure><figcaption>{title} · {avatar[mode]["gpu_ms"]["median"]:.3f} ms GPU</figcaption><img src="data:image/png;base64,{data}" alt="{title}"></figure>'
 extra='<h2>UT99 avatar shader optimisation</h2><p>Separate isolated 32-soldier render test. The optimized shader moves baked irradiance to vertices and retains per-pixel headlights. Maximum image difference: one 8-bit colour step. Frozen poses, same geometry and skin; these timings cannot be added to the full-map measurements.</p><div class="pair">'+figures+'</div>'
 html=html.replace('<small>',extra+'<small>',1)
(DEST/'comparison.html').write_text(html)
for view in views:
 v=summaries[view]['vertex']['gpu_ms']['median'];m=summaries[view]['mixed']['gpu_ms']['median']
 print(view,'vertex',round(v,3),'mixed',round(m,3),'delta',round(m-v,3),'percent',round((m/v-1)*100,1))
print(DEST/'comparison.html')
