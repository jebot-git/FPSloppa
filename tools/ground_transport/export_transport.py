"""Build the CC0 BlendSwap LPMAC: two surfaces, one 1024 atlas, eight occupant anchors.
Run Blender --factory-startup -b --python tools/ground_transport/export_transport.py.
The source .blend is never overwritten. Runtime geometry faces Godot -Z.
"""
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'deathmatch/models/ground_transport';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/ground_transport/source/lpmac.blend'),load_ui=False)
removed=[];parts=[];source=0
for o in list(bpy.data.objects):
 if o.type!='MESH' or o.name.startswith('Plane') or o.name in ['gun high','turret high','turret mantlet high','rotating sensor high','antena high']:
  removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True);continue
 source+=sum(len(p.vertices)-2 for p in o.data.polygons)
 o.hide_render=False;o.hide_set(False);o.modifiers.clear();o.data.transform(o.matrix_world);o.parent=None;o.matrix_world=Matrix.Identity(4);parts.append(o)
lo=Vector([min(v.co[i] for o in parts for v in o.data.vertices) for i in range(3)]);hi=Vector([max(v.co[i] for o in parts for v in o.data.vertices) for i in range(3)])
scale=8/(hi.y-lo.y);center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z));rotate=Matrix.Rotation(math.pi,4,'Z')
for o in parts:
 for v in o.data.vertices:v.co=(rotate@(v.co-center))*scale
 # The source cab contains coincident duplicate shells (1,336 duplicate faces).
 # Weld before reduction so two differently decimated surfaces cannot shimmer.
 if o.name=='drvercab high':
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bm.to_mesh(o.data);bm.free()
 # Preserve the low-poly pod shells and silhouette; aggressively remove authored tiny hardware.
 tris=sum(len(p.vertices)-2 for p in o.data.polygons)
 if tris>2500:
  bpy.context.view_layer.objects.active=o;dec=o.modifiers.new('Game mesh budget','DECIMATE');dec.ratio=min(1,1600/tris) if o.name!='wheel high' else .14
  bpy.ops.object.modifier_apply(modifier=dec.name)
# Glass is a separate transparent surface; it must not become an opaque atlas panel.
glass=[];opaque=[]
for o in parts:
 if o.name=='cargo pod high.001':glass.append(o)
 else:opaque.append(o)
def join(objects,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
hull=join(opaque,'Hull')
for m in hull.data.materials:
 if not m or not m.use_nodes:continue
 tree=m.node_tree;output=next((n for n in tree.nodes if n.type=='OUTPUT_MATERIAL'),None);shader=next((n for n in tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
 if not output:continue
 emit=tree.nodes.new('ShaderNodeEmission')
 if shader:
  color=shader.inputs['Base Color'];emit.inputs['Color'].default_value=color.default_value
  if color.is_linked:tree.links.new(color.links[0].from_socket,emit.inputs['Color'])
 tree.links.new(emit.outputs[0],output.inputs['Surface'])
if not hull.data.uv_layers.active:hull.data.uv_layers.new(name='Source')
source_uv=hull.data.uv_layers.active.name
for m in hull.data.materials:
 if not m or not m.use_nodes:continue
 uv=m.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map=source_uv
 for n in list(m.node_tree.nodes):
  if n.type=='TEX_IMAGE' and not n.inputs['Vector'].is_linked:m.node_tree.links.new(uv.outputs['UV'],n.inputs['Vector'])
hull.data.uv_layers.new(name='Atlas');hull.data.uv_layers.active_index=len(hull.data.uv_layers)-1
bpy.context.view_layer.objects.active=hull;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.008);bpy.ops.object.mode_set(mode='OBJECT');hull.data.uv_layers.active.active_render=True
image=bpy.data.images.new('LPMAC_original_colours',1024,1024,alpha=False)
for m in hull.data.materials:
 if not m or not m.use_nodes:continue
 node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;m.node_tree.nodes.active=node
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=4;scene.render.bake.use_selected_to_active=False
bpy.ops.object.select_all(action='DESELECT');hull.select_set(True);bpy.ops.object.bake(type='EMIT')
image.filepath_raw=str(OUT/'transport_atlas.png');image.file_format='PNG';image.save()
mat=bpy.data.materials.new('LPMAC_atlas');mat.use_nodes=True;bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);bsdf.inputs['Roughness'].default_value=.88
hull.data.materials.clear();hull.data.materials.append(mat)
for p in hull.data.polygons:p.material_index=0
for uv in list(hull.data.uv_layers):
 if uv.name!='Atlas':hull.data.uv_layers.remove(uv)
window=join(glass,'PodWindows');window.data.materials.clear();m=bpy.data.materials.new('Clear_pod_windows');m.use_nodes=True;bsdf=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bsdf.inputs['Base Color'].default_value=(.16,.3,.32,.12);bsdf.inputs['Alpha'].default_value=.12;bsdf.inputs['Roughness'].default_value=.22
window.data.materials.append(m)
for p in window.data.polygons:p.material_index=0
# Six side passenger pods, one cockpit driver and one front passenger.
seats=[]
for side in [-1,1]:
 for i,source_y in enumerate([-2.544,.0145,2.5735]):
  z=(source_y-center.y)*scale;entry=[side*(4.169*scale+.45),0,z];seat=[side*2.8*scale,(-1-lo.z)*scale-.12,z]
  seats.append({'name':('Left' if side<0 else 'Right')+str(i+1),'entry':entry,'seat':seat})
  for prefix,point in [('Entry',entry),('Seat',seat)]:
   node=bpy.data.objects.new(prefix+str(len(seats)-1),None);scene.collection.objects.link(node);node.location=(point[0],-point[2],point[1]);node.empty_display_size=.15
for name,x in [('Driver',-.63),('FrontPassenger',.63)]:
 seats.append({'name':name,'entry':[(-2.2 if x<0 else 2.2),0,-2.65],'seat':[x,.4,-2.65]})
 for prefix,point in [('Entry',seats[-1]['entry']),('Seat',seats[-1]['seat'])]:
  node=bpy.data.objects.new(prefix+str(len(seats)-1),None);scene.collection.objects.link(node);node.location=(point[0],-point[2],point[1]);node.empty_display_size=.15
size=[(hi.x-lo.x)*scale,(hi.z-lo.z)*scale,8.]
manifest={'asset_id':29498,'kind':'transport','size':size,'seats':seats,'entry_radius':1.6,'driver_seat':6,'passenger_capacity':7,'driver_policy':'dedicated cockpit driver; passengers may use to take vacant driver seat','turret':False,'model':'res://deathmatch/models/ground_transport/transport.glb'}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(OUT/'transport.glb'),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in [hull,window]);budget={'source_triangles_retained_parts':source,'triangles':triangles,'meshes':2,'materials':2,'atlas':1024,'size':size,'removed':removed,'seats':8}
(ROOT/'tools/ground_transport/mesh-budget.json').write_text(json.dumps(budget,indent=2)+'\n')
# Workbench QA only; no camera or light enters the exported model.
scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.display.shading.show_cavity=True
camera=bpy.data.objects.new('QA',bpy.data.cameras.new('QA'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=10;camera.location=(9,11,7);camera.rotation_euler=(Vector((0,0,1.3))-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.resolution_x=1100;scene.render.resolution_y=750;scene.render.resolution_percentage=100;scene.render.filepath='/tmp/cq-lpmac/optimized.png';bpy.ops.render.render(write_still=True)
print('TRANSPORT_BUDGET',json.dumps(budget))
