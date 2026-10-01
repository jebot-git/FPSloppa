import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
rows={}
for folder in ['28872','12291','25753','12345','8856','22552','29096','futuristic-weapons']:
 for path in (ROOT/'sources'/folder).rglob('*.blend'):
  with bpy.data.libraries.load(str(path),link=False) as (s,d):d.objects=s.objects
  for ob in d.objects:
   if ob:bpy.context.scene.collection.objects.link(ob)
  bpy.context.view_layer.update()
  objects=[]
  for ob in d.objects:
   if not ob or ob.type!='MESH':continue
   points=[ob.matrix_world@v.co for v in ob.data.vertices]
   if not points:continue
   objects.append({'name':ob.name,'vertices':len(points),'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons),'min':[min(v[i] for v in points) for i in range(3)],'max':[max(v[i] for v in points) for i in range(3)],'materials':[m.name for m in ob.data.materials if m],'modifiers':[(m.name,m.type) for m in ob.modifiers]})
  rows[str(path.relative_to(ROOT))]=objects
  for ob in d.objects:
   if ob:bpy.data.objects.remove(ob,do_unlink=True)
(ROOT/'blend-inventory.json').write_text(json.dumps(rows,indent=2))
for path,obs in rows.items():print(path,len(obs),'objects',sum(o['triangles'] for o in obs),'triangles',[(o['name'],o['vertices']) for o in obs[:25]])
