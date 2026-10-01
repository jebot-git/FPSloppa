"""Record verified runtime counts and hashes after installing shared-part reductions."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'test-results/weapon-shared-reduction'
art=ROOT/'deathmatch/weapons/fidelity'
rows=json.loads((OUT/'runtime-counts.json').read_text())
audit=json.loads((OUT/'arsenal-audit.json').read_text())
manifest_path=art/'sources.json'
manifest=json.loads(manifest_path.read_text());models={m['key']:m for m in manifest['models']}
for row in rows:
 model=models[row['key']];model['triangles']=row['after']
 model['sha256']=hashlib.sha256((art/(row['key']+'.scn')).read_bytes()).hexdigest()
 optimization=model.setdefault('optimization',{})
 method='targeted Blender decimation with face-aware authored-normal transfer'
 if method not in optimization.get('method',''):optimization['method']=optimization.get('method','')+'; '+method
 optimization['normal_and_uv_values_preserved']=False
 optimization['unmodified_part_arrays_preserved']=True
 optimization['shared_part_reduction']={'before':row['before'],'after':row['after'],'parts':row['parts'],'existing_atlas_and_materials_preserved':True,'authored_normals_reprojected':True,'report':'test-results/weapon-shared-reduction/runtime-counts.json'}
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
groups={}
for row in rows:
 for part in row['parts']:
  name=part['name']; group=groups.setdefault(name,{'instances':0,'before':0,'after':0})
  group['instances']+=1;group['before']+=part['before'];group['after']+=part['after']
saved=sum(r['saved'] for r in rows);total=sum(r['triangles'] for r in audit)
summary={'models_changed':len(rows),'parts_changed':sum(len(r['parts']) for r in rows),'triangles_saved':saved,'arsenal_before':total+saved,'arsenal_after':total,'reduction_percent':100*saved/(total+saved),'shared_parts':groups,'remaining_over_10000':[{'key':r['key'],'triangles':r['triangles']} for r in audit if r['triangles']>10000]}
(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
