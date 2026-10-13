from pathlib import Path
import csv,json,shutil,hashlib
from collections import Counter
from PIL import Image
import numpy as np
root=Path('.');src=Path('test-results/tracer-pool-compare');dst=Path('docs/validation/voxel-battle/ranger-no-ai-shoot/tracer-pool');dst.mkdir(parents=True,exist_ok=True)
reports={};checks={}
for label in ['baseline','pooled']:
 p=src/label;r=json.loads((p/'result.json').read_text());n=json.loads((p/'no-ai.json').read_text());prof=json.loads((p/'profile.json').read_text())['scopes'];rows=list(csv.DictReader((p/'frames.csv').open()))
 assert len(rows)==r['performance']['samples'] and 119<=r['wall_seconds']<=122
 assert n['ai_work_calls']==n['ai_tick_samples']==n['navigation_polygons']==0 and len(n['shots_by_actor'])==32 and min(n['shots_by_actor'].values())>30
 assert n['deaths']==0 and r['avatar_prepass']['enabled'] and not r['springs']
 assert all(n['shots_per_30_sim_seconds'][str(i)]>0 for i in range(4))
 assert prof['impact_effects']['calls']==n['shots']
 for key in ['frame_ms','viewport_gpu_ms','render_cpu_ms','draw_calls','primitives']:
  vals=sorted(float(row[key]) for row in rows)
  for quant,idx in [('p50',len(vals)//2),('p95',int(len(vals)*.95)),('p99',int(len(vals)*.99))]:assert abs(vals[idx]-r['performance'][key][quant])<1e-6
 left=np.array(Image.open(p/'left.png').convert('RGB'));right=np.array(Image.open(p/'right.png').convert('RGB'))
 assert left.shape==right.shape==(2376,2160,3) and left.std()>1 and not np.array_equal(left,right)
 target=dst/label;target.mkdir(exist_ok=True)
 for f in p.iterdir():
  if f.is_file():shutil.copy2(f,target/f.name)
 shutil.copy2('/tmp/fpsloppa-tracer-'+label+'.log',target/'render.log')
 checks[label]={'wall_seconds':r['wall_seconds'],'simulation_seconds':r['simulation_seconds'],'frame_samples':len(rows),'csv_percentiles_verified':True,'zero_ai_nav':True,'shots':n['shots'],'reloads':n['reloads'],'all_32_shooting':True,'distinct_nonempty_2160x2376_eye_images':True}
 reports[label]={'run':r,'no_ai':n,'scopes':prof}
base=reports['baseline'];pool=reports['pooled']
for key in ['assignments','teams','camera_position','fov','per_eye_size','ipd_m','seed','gpu','engine','springs']:assert base['run'][key]==pool['run'][key],key
assert base['no_ai']['formation']==pool['no_ai']['formation']
meta=json.loads((src/'pooled/pool.json').read_text());assert meta['invariants_ok'] and meta['fallbacks']==0 and meta['capacity']==64 and meta['emissions']==pool['no_ai']['shots']
assert pool['scopes'].get('tracer_material_assign',{}).get('calls',0)==0 and pool['scopes'].get('tracer_material_create',{}).get('calls',0)==0
assert pool['scopes']['pooled_tracer_emit']['calls']==meta['emissions']
checks['matched_settings_verified']=True;checks['pool']=meta
paths=['tools/vrm_to_mdl/profile_pooled_impacts.gd','tools/vrm_to_mdl/profile/pooled_arena.gd','tools/vrm_to_mdl/profile/pooled_visuals.gd','tools/vrm_to_mdl/test_tracer_pool.gd','tools/vrm_to_mdl/profile_impacts.gd','tools/vrm_to_mdl/profile/impact_arena.gd','tools/vrm_to_mdl/profile/impact_visuals.gd','tools/vrm_to_mdl/profile_no_ai.gd','tools/vrm_to_mdl/profile/no_ai_arena.gd','tools/vrm_to_mdl/profile/arena.gd','tools/vrm_to_mdl/profile/cs_combat.gd','tools/vrm_to_mdl/profile/trace.gd','tools/vrm_to_mdl/no_ai_shoot.gd','tools/vrm_to_mdl/no_ai_slots.gd','tools/vrm_to_mdl/ranger_match.gd','tools/vrm_to_mdl/match_compare.gd','tools/voxel_battle/run.gd','tools/voxel_battle/performance.gd','deathmatch/experimental/visuals.gd']
for path in paths:
 target=dst/'scripts'/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
(dst/'source-sha256.json').write_text(json.dumps({p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths},indent=2)+'\n')
(dst/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
shutil.copy2('/tmp/fpsloppa-tracer-check.log',dst/'geometry-check.log');shutil.copy2('test-results/ranger-match/input-models.json',dst/'input-models.json')
comparison={}
for k in ['frame_ms','viewport_gpu_ms','render_cpu_ms','draw_calls','primitives']:
 a=base['run']['performance'][k];b=pool['run']['performance'][k];comparison[k]={'baseline':a,'pooled':b,'median_reduction_percent':100*(1-b['p50']/a['p50'])}
for k in ['impact_effects','impact_visuals','avatar_movement_collision','cs_weapon_input']:
 a=base['scopes'][k];b=pool['scopes'][k];comparison[k]={'baseline':a,'pooled':b,'mean_call_reduction_percent':100*(1-b['mean_call_ms']/a['mean_call_ms'])}
comparison['physics_ms']={'baseline':base['run']['physics_ms'],'pooled':pool['run']['physics_ms']}
comparison['pool']=meta
(dst/'comparison.json').write_text(json.dumps(comparison,indent=2)+'\n')
print(json.dumps({'checks':checks,'comparison':comparison},indent=2))
