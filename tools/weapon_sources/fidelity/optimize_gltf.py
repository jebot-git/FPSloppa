"""Attribute-aware, index-only simplification; original UVs, normals and nodes survive.
Requires meshoptimizer v1.0 (MIT), commit 73583c335e541c139821d0de2bf5f12960a04941.
Build shared src/{simplifier,allocator,indexgenerator,vfetchoptimizer,vcacheoptimizer}.cpp
with g++ -O2 -shared -fPIC, then pass --library /path/to/library.so.
"""
from pathlib import Path
import json,struct,ctypes as C,numpy as np,argparse
ROOT=Path(__file__).resolve().parent;OUT=ROOT.parents[2]/'test-results/weapon-optimization';OUT.mkdir(exist_ok=True)
p=argparse.ArgumentParser();p.add_argument('--library',default='/tmp/fps-meshoptimizer.so');args=p.parse_args();lib=C.CDLL(args.library)
U=C.POINTER(C.c_uint);F=C.POINTER(C.c_float);B=C.POINTER(C.c_ubyte)
fn=lib.meshopt_simplifyWithAttributes;fn.restype=C.c_size_t;fn.argtypes=[U,U,C.c_size_t,F,C.c_size_t,C.c_size_t,F,C.c_size_t,F,C.c_size_t,B,C.c_size_t,C.c_float,C.c_uint,F]
cache=lib.meshopt_optimizeVertexCache;cache.argtypes=[U,U,C.c_size_t,C.c_size_t]
def pointer(a,t):return a.ctypes.data_as(t)
def unpack(path):
 raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);return doc,raw[28+n:]
def read(doc,raw,index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];w={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];item=np.dtype(dtype).itemsize
 return np.ndarray((a['count'],w),dtype=dtype,buffer=raw,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',w*item),item)).copy()
rows=[]
for path in sorted((ROOT/'refined').glob('*.glb')):
 doc,raw=unpack(path);overrides={};parts=[]
 names={n['mesh']:n.get('name','') for n in doc['nodes'] if 'mesh' in n}
 for mi,mesh in enumerate(doc['meshes']):
  name=names[mi]
  # Recognizable cylindrical housings may use modest n-gons. Faceted casts,
  # receivers and CS control/sight assemblies do not receive this allowance.
  cylindrical=any(x in name.lower() for x in ['barrels','heavyrotarybarrel','laserfocusingbarrel','heavymortartube','mortarcollar','rotaryspindle','rotaryouterbrace','stabilizer','plasmaemitter','emittercollar','focusingcoil','fieldcoil','blasteremitter','targetinglens'])
  for prim in mesh['primitives']:
   indices=read(doc,raw,prim['indices']).ravel().astype(np.uint32);before=len(indices)//3
   positions=read(doc,raw,prim['attributes']['POSITION']).astype(np.float32);count=len(positions)
   protected=path.stem.startswith('cs16') and name not in ['Body','SculptedPistolGrip','RoundedTriggerGuard']
   dest=np.zeros_like(indices);error=C.c_float();new_count=len(indices)
   if before>=80 and not protected:
    attrs=np.concatenate([(read(doc,raw,prim['attributes'][k]) if k in prim['attributes'] else np.zeros((count,3 if k=='NORMAL' else 2))) for k in ['NORMAL','TEXCOORD_0']],axis=1).astype(np.float32)
    weights=np.array([1,1,1,12,12],dtype=np.float32);locks=np.zeros(count,dtype=np.uint8)
    if path.stem.startswith('cs16') and name=='Body':locks[positions[:,1]>.070]=1
    options=4
    if cylindrical:
     # Permit redundant normal seams to collapse into moderate polygonal
     # cylinders, while preserving discontinuities in the baked UV atlas.
     groups={}
     for vi,point in enumerate(positions):groups.setdefault(tuple(point),[]).append(vi)
     for group in groups.values():
      values=attrs[group,3:]
      if np.max(np.ptp(values,axis=0))>1e-5:locks[group]=2
     weights[:3]=.5;options|=32
    limit=(.004 if name.startswith('Donor_barrels') else .0015) if cylindrical else .0002
    new_count=fn(pointer(dest,U),pointer(indices,U),len(indices),pointer(positions,F),count,12,pointer(attrs,F),20,pointer(weights,F),5,pointer(locks,B),int(len(indices)*(.35 if name.startswith('Donor_barrels') else .55))//3*3,limit,options,C.byref(error))
   else:dest[:]=indices
   dest=dest[:new_count].copy()
   if new_count<len(indices):
    cache(pointer(dest,U),pointer(dest,U),new_count,count)
    accessor=doc['accessors'][prim['indices']];old_view=accessor['bufferView'];view_index=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteLength':dest.nbytes,'target':34963});accessor['bufferView']=view_index;accessor.pop('byteOffset',None);accessor.update(count=new_count,componentType=5125,min=[int(dest.min())],max=[int(dest.max())]);overrides[view_index]=dest.astype('<u4').tobytes()
   parts.append({'name':name,'before':before,'after':new_count//3,'cylindrical_allowance':cylindrical,'combined_error_m':error.value})
 # Repack live views; vertex/normal/UV/image bytes and all node metadata remain exact.
 used={a['bufferView'] for a in doc['accessors'] if 'bufferView' in a}|{im['bufferView'] for im in doc.get('images',[]) if 'bufferView' in im};binary=bytearray();views=[];remap={}
 for i,v in enumerate(doc['bufferViews']):
  if i not in used:continue
  data=overrides.get(i,raw[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]);binary.extend(b'\0'*((-len(binary))%4));v['byteOffset']=len(binary);v['byteLength']=len(data);binary.extend(data);remap[i]=len(views);views.append(v)
 for a in doc['accessors']:
  if 'bufferView' in a:a['bufferView']=remap[a['bufferView']]
 for im in doc.get('images',[]):
  if 'bufferView' in im:im['bufferView']=remap[im['bufferView']]
 doc['bufferViews']=views;doc['buffers'][0]['byteLength']=len(binary);binary.extend(b'\0'*((-len(binary))%4));encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
 output=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary
 (OUT/'candidates'/path.name).write_bytes(output)
 row={'key':path.stem,'before':sum(p['before'] for p in parts),'after':sum(p['after'] for p in parts),'parts':parts};rows.append(row);print(row['key'],row['before'],row['after'])
(OUT/'candidate-counts.json').write_text(json.dumps(rows,indent=2)+'\n')
