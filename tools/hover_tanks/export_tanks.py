"""Bake original CC0 tank base colours to one 512 atlas each; three movable meshes.
Run Blender --factory-startup --background --python tools/hover_tanks/export_tanks.py.
No showcase floor, HDRI, transparency, normal maps or runtime lights are exported.
"""
import bpy, math, json, bmesh
from pathlib import Path
from mathutils import Vector, Matrix
root=Path(__file__).resolve().parents[2]
out=root/'deathmatch/models/hover_tanks';out.mkdir(parents=True,exist_ok=True)
budget={}
for kind,file,length in [('light','lightning.blend',4.8),('heavy','aegis2.blend',5.8)]:
 bpy.ops.wm.open_mainfile(filepath=str(root/'tools/hover_tanks/source'/file))
 if kind=='heavy':bpy.data.objects['Turret_Parent'].rotation_euler=(0,0,0)
 bpy.context.view_layer.update()
 parts={}
 for o in list(bpy.data.objects):
  if o.type!='MESH' or o.name=='Floor':continue
  part='Barrel' if o.name=='Barrel' else 'Turret' if o.name in ['Turret','Optics','Shield'] else 'Hull'
  o.data.transform(o.matrix_world);o.parent=None;o.matrix_world=Matrix.Identity(4)
  vg=o.vertex_groups.new(name=part);vg.add(list(range(len(o.data.vertices))),1,'REPLACE');parts[o]=part
 for o in list(bpy.data.objects):
  if o not in parts:bpy.data.objects.remove(o,do_unlink=True)
 meshes=list(parts); hull=[v.co for o in meshes if parts[o]=='Hull' for v in o.data.vertices]
 axis=0 if kind=='light' else 1
 lo=Vector([min(v[i] for v in hull) for i in range(3)]);hi=Vector([max(v[i] for v in hull) for i in range(3)])
 center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z));factor=length/(hi[axis]-lo[axis])
 rotation=Matrix.Rotation(math.pi/2 if kind=='light' else 0,4,'Z')
 pivot=(rotation@(Vector((-1.86,0,1.28)) if kind=='light' else Vector((0,0,0)))-rotation@center)*factor
 source=0
 for o in meshes:
  source+=sum(len(p.vertices)-2 for p in o.data.polygons)
  for v in o.data.vertices:v.co=(rotation@(v.co-center))*factor
  if len(o.data.polygons)>150:
   bpy.context.view_layer.objects.active=o;dec=o.modifiers.new('Reduce detail','DECIMATE');dec.ratio=.28 if kind=='heavy' else .55;bpy.ops.object.modifier_apply(modifier=dec.name)
 # Original material colour networks (including camo mix) are baked to emission.
 for m in bpy.data.materials:
  if not m.use_nodes:continue
  tree=m.node_tree;output=next((n for n in tree.nodes if n.type=='OUTPUT_MATERIAL'),None)
  if not output:continue
  shader=next((n for n in tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  emission=tree.nodes.new('ShaderNodeEmission')
  if shader:
   color=shader.inputs['Base Color'];emission.inputs['Color'].default_value=color.default_value
   if color.is_linked:tree.links.new(color.links[0].from_socket,emission.inputs['Color'])
  else:emission.inputs['Color'].default_value=(.12,.25,.3,1)
  tree.links.new(emission.outputs[0],output.inputs['Surface'])
 bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();joined=bpy.context.object
 # Retain source UV as input, bake into a new packed layout.
 if not joined.data.uv_layers.active:
  joined.data.uv_layers.new(name='Source');bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
 source_uv=joined.data.uv_layers.active.name
 for m in joined.data.materials:
  if not m:continue
  uv=m.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map=source_uv
  for n in list(m.node_tree.nodes):
   if n.type=='TEX_IMAGE' and not n.inputs['Vector'].is_linked:m.node_tree.links.new(uv.outputs['UV'],n.inputs['Vector'])
 joined.data.uv_layers.new(name='Atlas');joined.data.uv_layers.active_index=len(joined.data.uv_layers)-1
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT');joined.data.uv_layers.active.active_render=True
 image=bpy.data.images.new(kind+'_atlas',512,512,alpha=False)
 for m in joined.data.materials:
  node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;m.node_tree.nodes.active=node
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=4
 bpy.ops.object.bake(type='EMIT')
 image.filepath_raw=str(out/(kind+'_atlas.png'));image.file_format='PNG';image.save()
 material=bpy.data.materials.new(kind+'_baked_original');material.use_nodes=True
 bsdf=material.node_tree.nodes.get('Principled BSDF');tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);bsdf.inputs['Roughness'].default_value=.9
 joined.data.materials.clear();joined.data.materials.append(material)
 joined.data.uv_layers.remove(joined.data.uv_layers[source_uv])
 for p in joined.data.polygons:p.material_index=0
 nodes={}
 for part in ['Hull','Turret','Barrel']:
  obj=joined.copy();obj.data=joined.data.copy();bpy.context.collection.objects.link(obj);obj.name=part
  group=obj.vertex_groups[part].index
  keep={v.index for v in obj.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)}
  bm=bmesh.new();bm.from_mesh(obj.data);bm.verts.ensure_lookup_table();bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in keep],context='VERTS');bm.to_mesh(obj.data);bm.free();nodes[part]=obj
 bpy.data.objects.remove(joined,do_unlink=True)
 yaw=bpy.data.objects.new('Yaw',None);bpy.context.collection.objects.link(yaw);yaw.location=pivot
 aim=bpy.data.objects.new('Aim',None);bpy.context.collection.objects.link(aim);aim.parent=yaw
 for part in ['Turret','Barrel']:
  obj=nodes[part];obj.data.transform(Matrix.Translation(-pivot));obj.parent=yaw if part=='Turret' else aim
 # All gun muzzle positions derive from the actual barrel vertices in rest pose.
 coords=[v.co for v in nodes['Barrel'].data.vertices];front=max(v.y for v in coords)
 xs=[v.x for v in coords if v.y>front-.08]
 side=max(abs(min(xs)),abs(max(xs))) if kind=='heavy' else 0
 triangles=sum(sum(len(p.vertices)-2 for p in n.data.polygons) for n in nodes.values())
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(out/(kind+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
 budget[kind]={'source_triangles':source,'triangles':triangles,'meshes':3,'materials':1,'atlas':512,'size':[round((hi.y-lo.y if kind=='light' else hi.x-lo.x)*factor,3),length], 'pivot':[pivot.x,pivot.z,-pivot.y],'barrel_length':front,'barrel_offset':side}
(out/'SOURCES.md').write_text('Futuristic Hover Tanks by KillGorack, CC0.\nhttps://opengameart.org/content/futuristic-hover-tanks\n\nlightning.blend is light; aegis2.blend (source Medium Class) is used for heavy.\nOriginal camouflage/metal/stripe colours baked to a single 512 atlas per tank.\nThree meshes separate hull, yaw-only turret and pitch-limited barrels.\nShowcase floor, HDRI, lights, normals and glass omitted. Godot generates mesh LODs; runtime uses the shared baked lighting, distance and frustum culling.\nRebuild: Blender -b --factory-startup --python tools/hover_tanks/export_tanks.py\n')
(root/'tools/hover_tanks/mesh-budget.json').write_text(json.dumps(budget,indent=2))
print('HOVER_BUDGET',budget)
