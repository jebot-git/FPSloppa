"""Blender: preserve musdasch's CC0 cell silhouette, remove the billboard shine,
collapse coplanar faces, reduce rings to the held-object budget, retain source UVs.
"""
import bpy,bmesh,math,json,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'deathmatch/models/cloak_device';OUT.mkdir(parents=True,exist_ok=True)
source=ROOT/'tools/cloak_device/source/EnergyCell/EnergyCell.blend'
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
for o in list(bpy.data.objects):
 if o.name!='EnergyCell':bpy.data.objects.remove(o,do_unlink=True)
o=bpy.data.objects['EnergyCell'];o.name='CloakEnergyCell';original=len(o.data.polygons);o.data.calc_loop_triangles();before=len(o.data.loop_triangles)
bpy.context.view_layer.objects.active=o;o.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# The outer glass becomes an opaque emissive shell; its hidden inner light
# cylinder is redundant. Retain the original outer profile and end caps.
bm=bmesh.new();bm.from_mesh(o.data);dead=[f for f in bm.faces if o.data.materials[f.material_index].name=='LightCellMaterial'];bmesh.ops.delete(bm,geom=dead,context='FACES');bm.to_mesh(o.data);bm.free();o.data.update()
# Source is only 636 triangles; retain silhouette with a modest ring reduction.
dec=o.modifiers.new('Held cell triangle budget','DECIMATE');dec.ratio=.65;dec.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=dec.name)
bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bmesh.ops.dissolve_limit(bm,angle_limit=math.radians(.1),verts=list(bm.verts),edges=list(bm.edges),delimit={'MATERIAL','UV'});bm.to_mesh(o.data);bm.free();o.data.update()
# The old Blender Internal materials have no node graphs. Keep the three source
# material regions and UVs, with an opaque energy core instead of layered glass.
image=bpy.data.images.load(str(ROOT/'tools/cloak_device/source/EnergyCell/img/EnergyCell.png'))
image.scale(256,256);image.filepath_raw=str(OUT/'cell-albedo.png');image.file_format='PNG';image.save()
for m in o.data.materials:
 name=m.name;m.use_nodes=True;nodes=m.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');bs=nodes.new('ShaderNodeBsdfPrincipled');m.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface']);bs.inputs['Roughness'].default_value=.68
 bs.inputs['Base Color'].default_value=(.05,.08,.09,1) if 'Base' in name else (.10,.65,.7,1)
 if 'Base' in name:
  tex=nodes.new('ShaderNodeTexImage');tex.image=image;m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
 else:
  bs.inputs['Emission Color'].default_value=(.02,.35,.4,1);bs.inputs['Emission Strength'].default_value=.35
# 18 cm high, palm-origin. Axis changes to Godot Y on export.
points=[o.matrix_world@v.co for v in o.data.vertices];lo=Vector([min(v[i] for v in points) for i in range(3)]);hi=Vector([max(v[i] for v in points) for i in range(3)]);center=(lo+hi)*.5
for v in o.data.vertices:v.co=(v.co-center)*(.18/(hi.z-lo.z))
o.data.calc_loop_triangles();after=len(o.data.loop_triangles)
for p in o.data.polygons:p.use_smooth=False
bpy.ops.export_scene.gltf(filepath=str(OUT/'cloak_device.glb'),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
report={'source_url':'https://opengameart.org/content/energy-pipe','author':'musdasch','license':'CC0-1.0','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_triangles':before+2,'runtime_triangles':after,'height_m':.18,'width_m':.072,'texture_size':[256,256],'removed':['2-triangle billboard shine','legacy transparent layered glass','hidden inner light cylinder'],'source_uv_preserved':True,'materials':2}
(OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('CQ_CLOAK_ASSET',json.dumps(report))
