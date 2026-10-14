"""Convert surt's CC0 fighter to a centered, 8 m span, -Z-forward GLB."""
import bpy,math
from pathlib import Path
from mathutils import Vector
root=Path(bpy.data.filepath).parents[3]
model=next(o for o in bpy.data.objects if o.type=='MESH')
print('SOURCE_VERTICES', [tuple(v.co) for v in model.data.vertices])
# Retain the original nearest-filtered 128² eight-color pixel texture.
image=next(i for i in bpy.data.images if i.name=='fighter')
mat=bpy.data.materials.new('Recon fighter pixel atlas');mat.use_nodes=True
nodes=mat.node_tree.nodes;bsdf=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
texture=nodes.new('ShaderNodeTexImage');texture.image=image;texture.interpolation='Closest'
mat.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color']);bsdf.inputs['Roughness'].default_value=.85
model.data.materials.clear();model.data.materials.append(mat)
# Source nose points toward -Y. +Y maps to Godot -Z: rotate it 180 degrees.
for v in model.data.vertices:v.co=(v.co-Vector((0,-2,.45)))*2
model.rotation_euler.z=math.pi
bpy.ops.object.select_all(action='DESELECT');model.select_set(True);bpy.context.view_layer.objects.active=model
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
model.location=(0,0,0)
bpy.ops.export_scene.gltf(filepath=str(root/'deathmatch/models/recon/fighter.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_materials='EXPORT')
