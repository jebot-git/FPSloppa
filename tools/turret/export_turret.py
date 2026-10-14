"""CC0 PolygonDan turret: reduce mesh and atlas, preserve its flat diffuse design."""
import bpy,bmesh,zipfile,tempfile,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
with tempfile.TemporaryDirectory(prefix='cq-turret-') as temp:
 with zipfile.ZipFile(root/'tools/turret/source/Turret_final_PolygonDan.zip') as z:z.extractall(temp)
 folder=Path(temp)/'Turret_final PolygonDan'
 bpy.ops.wm.obj_import(filepath=str(folder/'turret.obj'))
 meshes=[o for o in bpy.data.objects if o.type=='MESH'];print('SOURCE_BOUNDS',[(o.name,tuple(o.dimensions)) for o in meshes])
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();o=bpy.context.object
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 source=sum(len(p.vertices)-2 for p in o.data.polygons)
 mod=o.modifiers.new('Silhouette LOD','DECIMATE');mod.ratio=.6;bpy.ops.object.modifier_apply(modifier=mod.name)
 lo=Vector([min(v.co[i] for v in o.data.vertices) for i in range(3)]);hi=Vector([max(v.co[i] for v in o.data.vertices) for i in range(3)])
 # OBJ importer maps source Y up to Blender Z up. Model is rotated from source +X to Blender +Y (Godot -Z).
 for v in o.data.vertices:v.co=(v.co-Vector((0,0,lo.z)))*(1.4/(hi.z-lo.z))
 o.rotation_euler.z=1.5707963267948966 # Source barrel +X -> Godot -Z.
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 o.location=(0,0,0)
 adjacency={v.index:set() for v in o.data.vertices}
 for edge in o.data.edges:
  a,b=edge.vertices;adjacency[a].add(b);adjacency[b].add(a)
 unseen=set(adjacency);components=[]
 while unseen:
  seed=unseen.pop();group={seed};todo=[seed]
  while todo:
   for other in adjacency[todo.pop()]:
    if other in unseen:unseen.remove(other);group.add(other);todo.append(other)
  components.append(group)

 image=bpy.data.images.load(str(folder/'Texture_Texture Vr02.jpg'));image.scale(512,512);image.name='Turret diffuse 512'
 image.filepath_raw=str(root/'deathmatch/models/turret/diffuse.png');image.file_format='PNG';image.save()
 mat=bpy.data.materials.new('Turret flat diffuse');mat.use_nodes=True;bsdf=mat.node_tree.nodes.get('Principled BSDF');texture=mat.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image;mat.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color']);bsdf.inputs['Roughness'].default_value=.9
 o.data.materials.clear();o.data.materials.append(mat)
 for p in o.data.polygons:p.material_index=0
 # Disconnected upper components form the rotating gun. Keep the feet/base fixed.
 head_vertices=set().union(*(group for group in components if min(o.data.vertices[i].co.z for i in group)>.73))
 pivot=bpy.data.objects.new('Aim',None);bpy.context.scene.collection.objects.link(pivot);pivot.location=(0,0,1.15)
 parts=[]
 for name,keep in [('Base',set(adjacency)-head_vertices),('Gun',head_vertices)]:
  mesh=o.data.copy();bm=bmesh.new();bm.from_mesh(mesh);bm.verts.ensure_lookup_table()
  bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in keep],context='VERTS');bm.to_mesh(mesh);bm.free()
  part=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(part)
  if name=='Gun':
   for vertex in mesh.vertices:vertex.co.z-=1.15
   part.parent=pivot
  parts.append(part)
 triangles=sum(sum(len(p.vertices)-2 for p in part.data.polygons) for part in parts)
 bpy.data.objects.remove(o,do_unlink=True);bpy.ops.object.select_all(action='DESELECT')
 for part in parts+[pivot]:part.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(root/'deathmatch/models/turret/turret.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
 (root/'deathmatch/models/turret/diffuse.png').unlink(missing_ok=True)
 result={'source_triangles':source,'triangles':triangles,'height_m':1.4,'materials':1,'draws':2,'atlas':[512,512]};(root/'tools/turret/mesh-budget.json').write_text(json.dumps(result,indent=2)+'\n');print('TURRET_BUDGET',result)
