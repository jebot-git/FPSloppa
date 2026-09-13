"""Recover cannon muzzle anchors from the animated model's actual skinned mesh."""
import json,struct
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
raw=(ROOT/'tools/ba2/animated/BA2-10m-walk.glb').read_bytes()
size=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+size]);binary=raw[28+size:]
def accessor(index):
 a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];dtype={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']];w={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 return np.ndarray((a['count'],w),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',np.dtype(dtype).itemsize*w),np.dtype(dtype).itemsize)).copy()
names={n['name']:i for i,n in enumerate(g['nodes']) if 'name' in n};skin=g['skins'][0];attrs=g['meshes'][0]['primitives'][0]['attributes']
pos=accessor(attrs['POSITION']);joints=accessor(attrs['JOINTS_0']);weights=accessor(attrs['WEIGHTS_0']);inverse=accessor(skin['inverseBindMatrices']);rows={}
for side in ['L','R']:
 name='Cannon.'+side;joint=skin['joints'].index(names[name]);ids=np.where(np.any((joints==joint)&(weights>.5),axis=1))[0]
 # glTF mesh positions face +Z. Average the extreme front ring, excluding breech.
 front=pos[ids];front=front[front[:,2]>front[:,2].max()-.002]
 centre=front.mean(axis=0);local=inverse[joint].reshape(4,4).T@np.r_[centre,1]
 # Each side carries an upper/lower barrel. Split the front rings by height
 # instead of placing one fictional muzzle in the space between them.
 middle=(front[:,1].min()+front[:,1].max())*.5
 rings=[front[front[:,1]>middle],front[front[:,1]<middle]]
 assert all(len(ring)>=16 for ring in rings)
 barrel_points=[(inverse[joint].reshape(4,4).T@np.r_[ring.mean(axis=0),1])[:3].tolist() for ring in rings]
 rows[side]={'bone':name,'muzzle_local':local[:3].tolist(),'muzzles_local':barrel_points,'front_vertices':len(front)}
(ROOT/'tools/ba2/cockpit/mounts.json').write_text(json.dumps(rows,indent=2)+'\n');print(rows)
