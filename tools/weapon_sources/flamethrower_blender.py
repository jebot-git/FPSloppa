"""Convert TheJosh's CC0 flamethrower, preserving geometry, UVs and original texture."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'tools/weapon_sources/oga/flamethrower'
bpy.ops.wm.open_mainfile(filepath=str(source/'flamethrower.blend'),load_ui=False,use_scripts=False)
mesh_objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
image=bpy.data.images.load(str(source/'flamethrower.png'),check_existing=False)
image.scale(1024,1024) # Match the current weapon texture resolution; source stays untouched.
material=bpy.data.materials.new('TheJosh original baked diffuse');material.use_nodes=True
bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.72
tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
for obj in bpy.context.scene.objects:obj.select_set(False)
bpy.context.view_layer.objects.active=mesh_objects[0]
if mesh_objects[0].mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for o in mesh_objects:
 world=o.matrix_world.copy()
 for v in o.data.vertices:
  v.co=world@v.co
  # Original -Y front -> Blender +Y / Godot -Z. Uniform metres, upright Z retained.
  v.co=Vector((-v.co.x*.85,-v.co.y*.85-.03,v.co.z*.85))
 o.matrix_world=Matrix.Identity(4);o.data.materials.clear();o.data.materials.append(material)
 o.name='TF Pyro Flamethrower';o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'tools/weapon_sources/refined/tf_flamethrower.glb'),export_format='GLB',use_selection=True,export_yup=True)
print('TF_FLAMETHROWER_EXPORTED')
