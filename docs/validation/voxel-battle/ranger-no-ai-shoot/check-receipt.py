from pathlib import Path
import json, csv, hashlib, shutil, collections
from PIL import Image
import numpy as np
root=Path('/home/blux/Documents/FPSloppa/.worktrees/cq-voxelspace')
src=root/'test-results/ranger-no-ai-shoot'
dst=root/'docs/validation/voxel-battle/ranger-no-ai-shoot'
r=json.loads((src/'result.json').read_text()); n=json.loads((src/'no-ai.json').read_text())
rows=list(csv.DictReader((src/'frames.csv').open()))
assert len(rows)==r['performance']['samples']
for key in ['frame_ms','viewport_gpu_ms','render_cpu_ms','draw_calls','primitives']:
    vals=sorted(float(row[key]) for row in rows)
    for q, idx in [('p50',len(vals)//2),('p95',int(len(vals)*.95)),('p99',int(len(vals)*.99))]:
        assert abs(vals[idx]-r['performance'][key][q])<1e-6,(key,q)
assert r['teams']==[16,16] and len(r['assignments'])==32
assert r['avatar_prepass']['enabled'] and not r['springs'] and not r['avatar_prepass']['springs_enabled']
assert n['avatars']==32 and n['deaths']==0 and min(n['shots_by_actor'].values())>30
assert n['ai_work_calls']==n['ai_tick_samples']==n['navigation_polygons']==0
assert n['both_eye_visible_avatars']['p50']==32
assert all(n['animation_frame_observations'][a]>0 for a in ['idle','walk','run'])
assert all(n['shots_per_30_sim_seconds'].get(str(i),0)>0 for i in range(4))
assert 119<=r['wall_seconds']<=122
left=np.array(Image.open(src/'left.png').convert('RGB'));right=np.array(Image.open(src/'right.png').convert('RGB'))
assert left.shape==right.shape==(2376,2160,3) and left.std()>1 and not np.array_equal(left,right)
for name in ['result.json','no-ai.json','frames.csv','left.png','right.png','preview.png']:
    shutil.copy2(src/name,dst/name)
shutil.copy2('/tmp/fpsloppa-ranger-no-ai-shoot-fixed.log',dst/'render.log')
shutil.copy2(root/'test-results/ranger-match/input-models.json',dst/'input-models.json')
paths=['tools/vrm_to_mdl/no_ai_shoot.gd','tools/vrm_to_mdl/no_ai_arena.gd','tools/vrm_to_mdl/no_ai_slots.gd','tools/vrm_to_mdl/ranger_match.gd','tools/vrm_to_mdl/match_compare.gd','tools/voxel_battle/run.gd','tools/voxel_battle/performance.gd','tools/voxel_battle/arena.gd','tools/voxel_battle/avatar_prepass.gd','tools/voxel_battle/cs_combat.gd','tools/voxel_battle/cs_rules.gd']
hashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths}
for p in paths:
    target=dst/'scripts'/p;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/p,target)
(dst/'source-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
checks={'teams':r['teams'],'models':dict(collections.Counter(a['model'] for a in r['assignments'])),'wall_seconds':r['wall_seconds'],'simulation_seconds':r['simulation_seconds'],'csv_percentiles_verified':True,'frame_samples':len(rows),'all_32_fired_beyond_first_magazine':True,'minimum_shots_per_actor':min(n['shots_by_actor'].values()),'shots_per_30_sim_seconds':n['shots_per_30_sim_seconds'],'zero_ai_and_navigation':True,'eye_resolution':[2160,2376],'distinct_eye_images':True,'mean_absolute_eye_pixel_difference':float(np.abs(left.astype(float)-right.astype(float)).mean()),'prepass':True,'springs_enabled':False}
(dst/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
print(json.dumps({'checks':checks,'frame_ms':r['performance']['frame_ms'],'gpu_ms':r['performance']['viewport_gpu_ms'],'render_cpu_ms':r['performance']['render_cpu_ms'],'physics_ms':r['physics_ms'],'shots':n['shots'],'reloads':n['reloads']},indent=2))
