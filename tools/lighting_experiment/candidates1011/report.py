"""Archive the closed 10/11 evaluation. Does not run or integrate either effect."""
from pathlib import Path
import hashlib,importlib.util,json
from statistics import median
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'test-results/candidates1011'
def read(name):return json.loads((OUT/name).read_text())
def main():
 render=read('render.json');fixtures=read('fixtures.json');assert not render['failures'] and not fixtures['failures']
 summary=[];errors=[]
 for r in render['records']:
  prefix=f"{r['map']}-{r['view']}-";folder=OUT/r['mode'];a=np.asarray(Image.open(folder/(prefix+'baseline.png')),dtype=float);b=np.asarray(Image.open(folder/(prefix+r['variant']+'.png')),dtype=float)
  error=float(np.abs(a-b).mean());errors.append({'map':r['map'],'view':r['view'],'mode':r['mode'],'variant':r['variant'],'mae_255':error})
  if r['variant'] in ['flat','restored']:assert error<.001
 for map_id in ['tf_vesper','tf_pressureworks']:
  base={r['view']:r for r in render['records'] if r['map']==map_id and r['mode']=='contrast' and r['variant']=='baseline'}
  for variant in ['reflection','directional','combined']:
   rows=[r for r in render['records'] if r['map']==map_id and r['mode']=='contrast' and r['variant']==variant]
   summary.append({'map':map_id,'variant':variant,'added_texture_mib':median((r['texture_bytes']['median']-base[r['view']]['texture_bytes']['median'])/2**20 for r in rows),'paired_gpu_median_delta_ms':median(r['gpu_ms']['median']-base[r['view']]['gpu_ms']['median'] for r in rows),'resources':rows[0]['resources']})
 snapshot=read('production-before.json');changed=[]
 for name,sha in snapshot.items():
  p=ROOT/name;now=hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
  if now!=sha:changed.append({'path':name,'before':sha,'after':now})
 # Concurrent AS-map work is recorded, never reverted or attributed to these prototypes.
 critical=['deathmatch/maps/baked_light.gd','deathmatch/maps/baked_light.gdshader','deathmatch/maps/atmosphere.gd','deathmatch/assets/base_manifest.json','maps/tf_vesper.bsp','maps/tf_pressureworks.bsp']
 assert all(not any(c['path']==name for c in changed) for name in critical)
 report={'status':'closed_without_integration','decision':'User reviewed the visual differences and declined further implementation; remaining recommendations 12–14 will not be explored.','render':render,'fixtures':fixtures,'draw_audit':read('draws.json'),'bakes':read('bake.json'),'probes':read('probes.json'),'materials':read('materials.json'),'summary':summary,'pixel_errors':errors,'snapshot':{'tracked_files':len(snapshot),'changed_by_other_work_during_test':changed,'tested_bsp_shader_atmosphere_and_base_manifest_unchanged':True},'limitations':['Two-map static scene evaluation, not a Quest/OpenXR or gameplay benchmark.','Normal companions are experimental height interpretations of painted colour, not source-supplied PBR assets.','Direct fraction is an estimate from a separate direct-only bake; one averaged direction cannot represent all incoming light.','LDR offline cubemaps with ordinary mips and approximate box projection; no HDR/GGX prefilter or moving actors.','Both completed renderer and fixture retain the common one-ObjectDB shutdown warning.']}
 (ROOT/'docs/validation/candidates1011.json').write_text(json.dumps(report,indent=2)+'\n')
 spec=importlib.util.spec_from_file_location('helpers',ROOT/'tools/lighting_experiment/candidates789/compare.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h);h.OUT=OUT
 rows=[]
 for map_id,view,label in [('tf_vesper','nave','Vesper nave'),('tf_vesper','floor','Vesper floor'),('tf_pressureworks','floor','Pressureworks floor'),('tf_pressureworks','metal','Pressureworks metal')]:
  rows.append((label,[Image.open(OUT/'contrast'/f'{map_id}-{view}-{v}.png') for v in ['baseline','reflection','directional','combined']]))
 h.sheet('comparison.png','10 / Static reflections and 11 / directional normals','Closed without integration after visual review. Contrast, current skyboxes, no fog. Equal resizing; no image enhancement.',rows,['Baseline','10: reflections','11: directional normals','Combined'],(400,250))
 print(json.dumps({'status':report['status'],'measured_frames':render['measured_frames'],'summary':summary},indent=2))
if __name__=='__main__':main()
