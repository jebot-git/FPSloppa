import bpy,os,math
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
SOURCE=PROJECT.parent/"WeaponSource"
from mathutils import Vector, Quaternion
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(PROJECT/'vrm/sample_d.vrm'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
print('HAND_BONES',[b.name for b in rig.data.bones if '_R_' in b.name and any(n in b.name for n in ['Hand','Thumb','Index','Middle','Ring','Little'])])
for b in rig.pose.bones:
 if '_R_' in b.name and any(n in b.name for n in ['Thumb','Index','Middle','Ring','Little']):
  b.rotation_mode='QUATERNION'
  axis=b.bone.matrix_local.to_3x3().inverted()@Vector((0,1,0))
  b.rotation_quaternion=Quaternion(axis,1.3 if 'Thumb' not in b.name else .55)
bpy.context.view_layer.update()
hand=rig.pose.bones.get('J_Bip_R_Hand')
parts=[]
for ob in list(bpy.context.scene.objects):
 if ob.type!='MESH':continue
 groups={g.index for g in ob.vertex_groups if '_R_' in g.name and any(n in g.name for n in ['Hand','Thumb','Index','Middle','Ring','Little'])}
 if not groups:continue
 forearm={g.index for g in ob.vertex_groups if g.name=='J_Bip_R_LowerArm'}
 keep={v.index for v in ob.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.65 or (sum(g.weight for g in v.groups if g.group in forearm)>.5 and (ob.matrix_world@v.co-rig.matrix_world@hand.bone.head_local).length<.16)}
 if not keep:continue
 import bmesh
 evaluated=ob.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=bpy.data.meshes.new_from_object(evaluated)
 bm=bmesh.new();bm.from_mesh(mesh);bm.verts.ensure_lookup_table();bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in keep],context='VERTS');bm.to_mesh(mesh);bm.free()
 if len(mesh.polygons)==0:continue
 part=bpy.data.objects.new('VRoid_Fist',mesh);bpy.context.scene.collection.objects.link(part);part.matrix_world=ob.matrix_world.copy();parts.append(part)
print('FIST_PARTS',[(o.name,len(o.data.polygons)) for o in parts])
if not parts:raise RuntimeError('no hand mesh')
# Bake world transform, center hand, scale to a 22 cm fist.
coords=[o.matrix_world@v.co for o in parts for v in o.data.vertices];lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)));hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)));center=(lo+hi)*.5;scale=.34/max(hi-lo)
for ob in parts:
 for v in ob.data.vertices:v.co=(ob.matrix_world@v.co-center)*scale
 ob.matrix_world.identity()
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.export_scene.gltf(filepath=str(PROJECT/'deathmatch/weapons/fist.glb'),export_format='GLB',use_selection=True,export_animations=False)
