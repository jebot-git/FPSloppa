"""CC0 X-001: collapse source materials to vertex colours and decimate for a one-draw bomber."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
root=Path(bpy.data.filepath).parents[3]
o=next(o for o in bpy.data.objects if o.type=='MESH')
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
source_tris=sum(len(p.vertices)-2 for p in o.data.polygons)
# Opaque painted metal, dark canopy and engine trim; no glass/transparency or large texture.
for attribute in list(o.data.color_attributes):o.data.color_attributes.remove(attribute)
col=o.data.color_attributes.new(name='Bomber paint',type='BYTE_COLOR',domain='CORNER')
colours=[(.19,.23,.25,1),(.035,.09,.12,1),(.43,.46,.42,1)]
for p in o.data.polygons:
 for i in p.loop_indices:col.data[i].color=colours[min(p.material_index,2)]
mat=bpy.data.materials.new('X001 vertex paint');mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF');vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name=col.name
mat.node_tree.links.new(vc.outputs['Color'],bsdf.inputs['Base Color']);bsdf.inputs['Roughness'].default_value=.9
o.data.materials.clear();o.data.materials.append(mat)
for p in o.data.polygons:p.material_index=0
mod=o.modifiers.new('Flight silhouette simplification','DECIMATE');mod.ratio=.12
bpy.ops.object.modifier_apply(modifier=mod.name)
# Source nose is +Y, exported Godot forward is -Z. Center and retain a 20 m span.
lo=Vector([min(v.co[i] for v in o.data.vertices) for i in range(3)])
hi=Vector([max(v.co[i] for v in o.data.vertices) for i in range(3)])
for v in o.data.vertices:v.co=(v.co-(lo+hi)*.5)*(20/(hi.x-lo.x))
o.location=(0,0,0);o.rotation_euler=(0,0,0);o.scale=(1,1,1)
bpy.ops.export_scene.gltf(filepath=str(root/'deathmatch/models/airstrike/bomber.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_materials='EXPORT')
result={'source_triangles':source_tris,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'materials':len(o.data.materials),'span_metres':20}
(root/'tools/airstrike/mesh-budget.json').write_text(json.dumps(result,indent=2)+'\n');print('BOMBER_BUDGET',result)
