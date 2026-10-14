"""Export mrpoly's CC0 Futuristic Grenade, 18 cm tall with opaque baked-compatible paint."""
import bpy,json
from pathlib import Path
from mathutils import Vector
root=Path(bpy.data.filepath).parents[3]
# Sphere is the low-poly cage; Sphere.001 is the finished detailed mesh.
o=max((o for o in bpy.data.objects if o.type=='MESH'),key=lambda o:len(o.data.polygons))
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
source=sum(len(p.vertices)-2 for p in o.data.polygons)
if source>1200:
 mod=o.modifiers.new('Handheld silhouette','DECIMATE');mod.ratio=1000/source;bpy.ops.object.modifier_apply(modifier=mod.name)
lo=Vector([min(v.co[i] for v in o.data.vertices) for i in range(3)]);hi=Vector([max(v.co[i] for v in o.data.vertices) for i in range(3)])
for a in list(o.data.color_attributes):o.data.color_attributes.remove(a)
col=o.data.color_attributes.new(name='Medical paint',type='BYTE_COLOR',domain='CORNER')
for p in o.data.polygons:
 z=(p.center.z-lo.z)/(hi.z-lo.z)
 # Pale medical shell, green belt and dark actuator end caps.
 colour=(.12,.65,.30,1) if .36<z<.58 else (.11,.15,.17,1) if z<.12 or z>.88 else (.68,.73,.70,1)
 for i in p.loop_indices:col.data[i].color=colour
for v in o.data.vertices:v.co=(v.co-(lo+hi)*.5)*(.18/(hi.z-lo.z))
o.location=(0,0,0)
mat=bpy.data.materials.new('Medical shell');mat.use_nodes=True;bsdf=mat.node_tree.nodes.get('Principled BSDF');vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name=col.name;mat.node_tree.links.new(vc.outputs['Color'],bsdf.inputs['Base Color']);bsdf.inputs['Roughness'].default_value=.8
o.data.materials.clear();o.data.materials.append(mat)
for p in o.data.polygons:p.material_index=0
exported=bpy.data.objects.new('Healing grenade',o.data.copy());bpy.context.scene.collection.objects.link(exported)
bpy.ops.object.select_all(action='DESELECT');exported.select_set(True);bpy.context.view_layer.objects.active=exported
bpy.ops.export_scene.gltf(filepath=str(root/'deathmatch/models/healing_grenade/grenade.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
result={'source_triangles':source,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'height_m':.18,'materials':1};(root/'tools/healing_grenade/mesh-budget.json').write_text(json.dumps(result,indent=2)+'\n');print(result)
