"""Check exported clip timing and recover toe landmarks from actual skin data."""
import json,struct,hashlib
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'tools/ba2/animated/BA2-10m-walk.glb';raw=p.read_bytes()
size=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+size]);binary=raw[28+size:]
def accessor(index):
    a=g['accessors'][index];v=g['bufferViews'][a['bufferView']]
    dtype={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',np.dtype(dtype).itemsize*width)
    return np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=offset,strides=(stride,np.dtype(dtype).itemsize)).copy()
names={n['name']:i for i,n in enumerate(g['nodes']) if 'name' in n}
skin=g['skins'][0];primitive=g['meshes'][0]['primitives'][0];attrs=primitive['attributes']
positions=accessor(attrs['POSITION']);joints=accessor(attrs['JOINTS_0']);weights=accessor(attrs['WEIGHTS_0']);inverse=accessor(skin['inverseBindMatrices'])
toes={}
for part in ['Front.L','Front.R','Rear.L','Rear.R']:
    front,side=part.split('.');name=f'Leg.3.{front}.FK.{side}'
    joint=skin['joints'].index(names[name]);ids=np.where(np.any((joints==joint)&(weights>.5),axis=1))[0]
    toe=positions[min(ids,key=lambda i:positions[i,1])]
    local=inverse[joint].reshape(4,4).T@np.r_[toe,1]
    toes[part]={'bone':name,'bone_local':local[:3].tolist()}
clips={}
durations={'WalkStart':6.6,'WalkLoop':5.6,'TurretSweep':16.,'RoutePreview':17.8}
for a in g['animations']:
    starts=[float(accessor(s['input'])[0,0]) for s in a['samplers']]
    ends=[float(accessor(s['input'])[-1,0]) for s in a['samplers']]
    assert max(abs(x) for x in starts)<1e-6,(a['name'],starts)
    assert abs(max(ends)-durations[a['name']])<1e-4
    nodes=sorted(set(g['nodes'][c['target']['node']]['name'] for c in a['channels']))
    if a['name'] in ['WalkStart','WalkLoop']:assert not any('Cannon' in n for n in nodes)
    if a['name']=='TurretSweep':assert nodes==['Cannon.L','Cannon.R']
    clips[a['name']]={'start':min(starts),'end':max(ends),'animated_nodes':nodes}
r={'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'bones':len(skin['joints']),'clips':clips,'toes':toes}
(ROOT/'test-results/ba2/walk/glb-checks.json').write_text(json.dumps(r,indent=2)+'\n')
print('BA2_GLB_CHECKS_PASS',len(raw),'bytes',len(skin['joints']),'bones')
