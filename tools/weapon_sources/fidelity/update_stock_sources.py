"""Install reduced stock geometry into GLBs without changing other parts or atlases."""
from pathlib import Path
import copy,json,struct
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parents[2]/'test-results/weapon-stock'
def load(p):
 raw=p.read_bytes();n=struct.unpack_from('<I',raw,12)[0];return json.loads(raw[20:20+n]),raw[28+n:]
def write(p,doc,data):
 doc['buffers'][0]['byteLength']=len(data);data+=b'\0'*(-len(data)%4)
 encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
 p.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(data))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(data),0x004e4942)+data)
for path in (OUT).glob('tribes_*-stock.glb'):
 key=path.name.replace('-stock.glb','');target=ROOT/'refined'/(key+'.glb');backup=OUT/(key+'-source-before.glb')
 if not backup.exists():backup.write_bytes(target.read_bytes())
 doc,data=load(backup);part,pdata=load(path)
 old=next(n['mesh'] for n in doc['nodes'] if n.get('name')=='SculptedShoulderStock')
 new=next(n['mesh'] for n in part['nodes'] if n.get('name')=='SculptedShoulderStock')
 mesh=copy.deepcopy(part['meshes'][new]);material=doc['meshes'][old]['primitives'][0].get('material')
 remap={}
 for prim in mesh['primitives']:
  for index in list(prim['attributes'].values())+[prim['indices']]:
   if index in remap:continue
   a=copy.deepcopy(part['accessors'][index]);v=copy.deepcopy(part['bufferViews'][a['bufferView']]);start=v.get('byteOffset',0)
   data+=b'\0'*(-len(data)%4);v['byteOffset']=len(data);data+=pdata[start:start+v['byteLength']]
   a['bufferView']=len(doc['bufferViews']);doc['bufferViews'].append(v)
   remap[index]=len(doc['accessors']);doc['accessors'].append(a)
  prim['attributes']={k:remap[v] for k,v in prim['attributes'].items()};prim['indices']=remap[prim['indices']]
  if material is not None:prim['material']=material
 doc['meshes'][old]=mesh;write(target,doc,data)
 print(key,'stock replaced; other meshes/atlas unchanged')
