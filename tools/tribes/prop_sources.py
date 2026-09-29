"""Load the retained CC0 kit parts into Blender without disturbing other art."""
import bpy
from pathlib import Path
ROOT=Path(globals().get('PROP_PROJECT',(Path(__file__).resolve().parents[2] if '__file__' in globals() else Path('/home/blux/Documents/FPSloppa'))))
folder=ROOT/'tools/tribes/prop-sources'
for index,path in enumerate(sorted(folder.glob('*.glb'))):
 obj=bpy.data.objects.get('STPropSource_'+path.stem)
 if obj is None:
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path))
  added=set(bpy.data.objects)-before
  meshes=[o for o in added if o.type=='MESH'];empties=[o.name for o in added if o.type!='MESH']
  for o in bpy.context.selected_objects:o.select_set(False)
  for o in meshes:o.select_set(True)
  bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
  obj=bpy.context.object;obj.name='STPropSource_'+path.stem;world=obj.matrix_world.copy()
  for v in obj.data.vertices:v.co=world@v.co
  obj.parent=None;obj.matrix_world.identity()
  for name in empties:
   if bpy.data.objects.get(name):bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
 obj.hide_set(False);obj.location=(index*4,-15,0)
 print(obj.name,'verts',len(obj.data.vertices),'bounds',[[round(f(v.co[i] for v in obj.data.vertices),3) for i in range(3)] for f in [min,max]])
for o in bpy.context.selected_objects:o.select_set(False)
for o in bpy.data.objects:
 if o.name.startswith('STPropSource_'):o.select_set(True)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  with bpy.context.temp_override(area=area,region=next(r for r in area.regions if r.type=='WINDOW')):bpy.ops.view3d.view_selected()
