"""Confirm original attribute data and protected CS triangles survived simplification."""
import json,struct,numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parent;OUT=ROOT.parents[2]/'test-results/weapon-optimization'
def load(path):
 raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];return json.loads(raw[20:20+n]),raw[28+n:]
def array(doc,raw,i):
 a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];item=np.dtype(dtype).itemsize
 return np.ndarray((a['count'],width),dtype=dtype,buffer=raw,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*item),item))
rows=[]
for path in sorted((OUT/'before/refined').glob('*.glb')):
 if path.stem in ['tribes_2','tribes_5','tribes_7']:continue # Intentionally remodeled/barrel cross-section changes.
 a,ab=load(path);b,bb=load(ROOT/'refined'/path.name);fail=[];protected_count=0
 if a['nodes']!=b['nodes']:fail.append('node identity or transform changed')
 names={n['mesh']:n.get('name','') for n in a['nodes'] if 'mesh' in n}
 for mi,(ma,mb) in enumerate(zip(a['meshes'],b['meshes'])):
  for pa,pb in zip(ma['primitives'],mb['primitives']):
   for attr,idx in pa['attributes'].items():
    if not np.array_equal(array(a,ab,idx),array(b,bb,pb['attributes'][attr])):fail.append(names[mi]+' '+attr)
   if not path.stem.startswith('cs16'):continue
   positions=array(a,ab,pa['attributes']['POSITION']);old=array(a,ab,pa['indices']).reshape(-1,3);new={tuple(sorted(t)) for t in array(b,bb,pb['indices']).reshape(-1,3)}
   name=names[mi];protected=positions[:,1]>.070 if name=='Body' else np.full(len(positions),name not in ['SculptedPistolGrip','RoundedTriggerGuard'])
   for tri in old:
    if protected[tri].all() and np.linalg.norm(np.cross(positions[tri[1]]-positions[tri[0]],positions[tri[2]]-positions[tri[0]]))>0:
     protected_count+=1
     if tuple(sorted(tri)) not in new:fail.append(name+' protected triangle')
 rows.append({'key':path.stem,'protected_triangles':protected_count,'failures':sorted(set(fail))})
(OUT/'attribute-validation.json').write_text(json.dumps(rows,indent=2)+'\n');failures=[r for r in rows if r['failures']]
print('ATTRIBUTE_CHECK',len(rows),'protected triangles',sum(r['protected_triangles'] for r in rows),'failures',failures)
assert not failures
