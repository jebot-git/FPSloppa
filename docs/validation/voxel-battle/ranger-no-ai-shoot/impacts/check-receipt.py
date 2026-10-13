from pathlib import Path
import csv,json,hashlib,shutil,re
src=Path('test-results/ranger-impact-final');dst=Path('docs/validation/voxel-battle/ranger-no-ai-shoot/impacts');dst.mkdir(parents=True,exist_ok=True)
r=json.loads((src/'result.json').read_text());n=json.loads((src/'no-ai.json').read_text());s=json.loads((src/'profile.json').read_text())['scopes'];rows=list(csv.DictReader((src/'frames.csv').open()))
assert len(rows)==r['performance']['samples'] and 59<=r['wall_seconds']<=62
assert n['ai_work_calls']==n['ai_tick_samples']==n['navigation_polygons']==0 and len(n['shots_by_actor'])==32 and min(n['shots_by_actor'].values())>30
assert n['deaths']==0 and r['avatar_prepass']['enabled'] and not r['springs']
assert s['impact_effects']['calls']==n['shots'] and s['tracer_material_assign']['calls']==n['shots']
for k in ['frame_ms','viewport_gpu_ms','render_cpu_ms']:
 vals=sorted(float(row[k]) for row in rows)
 for quant,idx in [('p50',len(vals)//2),('p95',int(len(vals)*.95))]:assert abs(vals[idx]-r['performance'][k][quant])<1e-6

def method(text,name):
 a=text.index('func '+name+'(');b=text.find('\nfunc ',a+1)
 return text[a:b if b>=0 else len(text)].split('\n@rpc')[0]
def clean(text):return re.sub(r'[\s;]','', '\n'.join(l.split('#')[0] for l in text.splitlines() if 'Trace.' not in l))
for path,orig,names in [('tools/vrm_to_mdl/profile/impact_visuals.gd','deathmatch/experimental/visuals.gd',['impacts','streak','shape']),('tools/vrm_to_mdl/profile/impact_arena.gd','deathmatch/arena.gd',['_impacts'])]:
 for name in names:assert clean(method(Path(path).read_text(),name))==clean(method(Path(orig).read_text(),name)),name
for f in src.iterdir():
 if f.is_file():shutil.copy2(f,dst/f.name)
shutil.copy2('/tmp/fpsloppa-impact-final.log',dst/'render.log')
paths=['tools/vrm_to_mdl/profile_impacts.gd','tools/vrm_to_mdl/profile_no_ai.gd','tools/vrm_to_mdl/no_ai_shoot.gd','tools/vrm_to_mdl/profile/impact_arena.gd','tools/vrm_to_mdl/profile/impact_visuals.gd','tools/vrm_to_mdl/profile/no_ai_arena.gd','tools/vrm_to_mdl/profile/arena.gd','tools/vrm_to_mdl/profile/cs_combat.gd','tools/vrm_to_mdl/profile/trace.gd','deathmatch/arena.gd','deathmatch/experimental/visuals.gd','deathmatch/audio/spatial.gd']
for path in paths:
 target=dst/'scripts'/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
(dst/'source-sha256.json').write_text(json.dumps({p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths},indent=2)+'\n')
(dst/'checks.json').write_text(json.dumps({'csv_count_and_percentiles_verified':True,'samples':len(rows),'avatars':32,'ai_calls':0,'navigation_polygons':0,'all_avatars_shooting':True,'impact_and_material_calls_equal_shots':True,'instrumented_logic_matches_original_without_timers':True,'wall_seconds':r['wall_seconds'],'shots':n['shots'],'reloads':n['reloads'],'prepass':True,'springs':False},indent=2)+'\n')
total=s['impact_effects']['total_ms']
keys=['tracer_material_assign','tracer_shadow_assign','tracer_material_create','tracer_mesh_build','tracer_node_create','tracer_mesh_assign','tracer_add_to_scene','tracer_transform_bookkeeping','impact_illumination','fx_particle_enqueue','impact_surface_ray','impact_audio']
print(json.dumps({'wall':r['wall_seconds'],'shots':n['shots'],'frames':len(rows),'impact_ms':total,'physics_ms':s['arena_physics']['total_ms'],'frame':r['performance']['frame_ms'],'breakdown':{k:{'impact_percent':s[k]['total_ms']/total*100,'per_call_ms':s[k]['mean_call_ms'],'frame_p95':s[k]['per_render_frame_ms']['p95'],'total_ms':s[k]['total_ms']} for k in keys},'fx_update':s['fx_render_update']},indent=2))
