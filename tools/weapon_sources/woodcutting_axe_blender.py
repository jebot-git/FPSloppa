"""Convert Price's CC0 axe, with the cutting edge forward and grip at local origin."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'tools/weapon_sources/oga/woodcutting_axe'
bpy.ops.wm.open_mainfile(filepath=str(source/'woodcutting_axe.blend'),load_ui=False,use_scripts=False)
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in bpy.context.scene.objects:o.select_set(False)
bpy.context.view_layer.objects.active=objects[0]
if objects[0].mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
image=bpy.data.images.load(str(source/'texture.png'),check_existing=False)
m=bpy.data.materials.new('Price original axe diffuse');m.use_nodes=True
p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.68
tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
# Source has +Z up, a blade in XZ and the cutting edge on +X.
# Express in Godot axes first, with a 30-degree forward lean about the grip.
pitch=Matrix.Rotation(math.radians(-30),3,'X')
def converted(v):return pitch@Vector((-v.y,(v.z+2.5),-(v.x-.025)))*.095
edge=[]
for o in objects:
 world=o.matrix_world.copy()
 for v in o.data.vertices:
  old=world@v.co;g=converted(old)
  if old.x>2.60:edge.append(g.copy())
  v.co=Vector((g.x,-g.z,g.y))
 o.matrix_world=Matrix.Identity(4);o.data.materials.clear();o.data.materials.append(m);o.name='Quake Woodcutting Axe';o.select_set(True)
# Mean along the cutting edge, not its top decorative corner.
cut=sum(edge,Vector())/len(edge)
report={'cutting_edge':list(cut),'grip':[0,0,0],'scale':.095,'source_grip':[.025,0,-2.5],'source_triangles':266}
(ROOT/'tools/weapon_sources/refined/axe-alignment.json').write_text(json.dumps(report,indent=2))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'tools/weapon_sources/refined/axe.glb'),export_format='GLB',use_selection=True,export_yup=True)
print('WOODCUTTING_AXE_EXPORTED',json.dumps(report))
