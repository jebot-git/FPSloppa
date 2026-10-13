"""Verify the delivered GLBs, including attachments, against their budget and atlas manifest."""
from pathlib import Path
import json,struct
root=Path(__file__).resolve().parents[2];assets=root/'deathmatch/weapons/cq';manifest=json.loads((assets/'manifest.json').read_text());result={}
for name,info in manifest.items():
 raw=(assets/(name+'.glb')).read_bytes();assert raw[:4]==b'glTF'
 size=struct.unpack_from('<I',raw,12)[0];data=json.loads(raw[20:20+size])
 triangles=sum(data['accessors'][p['indices']]['count']//3 for mesh in data['meshes'] for p in mesh['primitives'])
 runtime=12 if name=='massacre' else 2 if name in ['carbine','designator','scout_pistol'] else 0
 assert triangles==info['triangles'] and triangles+runtime<1000,(name,triangles)
 assert len(data.get('images',[]))==len(data.get('textures',[]))==len(data.get('materials',[]))==1,name
 if name=='massacre':assert 'ChargingHandle' in [n.get('name') for n in data['nodes']]
 result[name]={'exported_triangles':triangles,'runtime_total_triangles':triangles+runtime,'materials':1,'baked_textures':1}
 dimensions={name:[hi-lo for lo,hi in manifest[name]['bounds_blender']] for name in ['health_box','ammo_box']}
 assert abs(max(dimensions['health_box'])-max(dimensions['ammo_box']))<.02,dimensions
print(json.dumps({'models':result,'case_dimensions_metres':dimensions,'errors':[]},indent=2))
