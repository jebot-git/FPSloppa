"""Refresh only our review scene in the live Blender MCP session."""
import bpy,math
from pathlib import Path
from mathutils import Vector
root=Path('/home/blux/Documents/FPSloppa/tools/weapon_sources/fidelity')
name='FPSloppa reference armory'
scene=bpy.data.scenes.get(name) or bpy.data.scenes.new(name)
for ob in list(scene.objects):
 if len(ob.users_scene)==1:bpy.data.objects.remove(ob,do_unlink=True)
 else:scene.collection.objects.unlink(ob)
bpy.context.window.scene=scene
keys=['tribes_1','tribes_2','tribes_3','tribes_4','tribes_5','tribes_7','cs16_1','cs16_2','cs16_10','cs16_11']
for index,key in enumerate(keys):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(root/'refined'/(key+'.glb')))
 added=[o for o in bpy.data.objects if o not in before]
 assembly=bpy.data.objects.new(key,None);scene.collection.objects.link(assembly)
 for ob in added:
  if ob.parent is None:ob.parent=assembly
 assembly.rotation_euler.z=math.pi/2;assembly.location=((index%4-1.5)*1.7,0,(2-index//4)*1.05)
 text=bpy.data.curves.new(key+' label','FONT');text.body=key.replace('_',' ').upper();text.size=.09;text.align_x='CENTER';label=bpy.data.objects.new(key+' label',text);scene.collection.objects.link(label);label.location=assembly.location+Vector((-.15,-.15,-.35));label.rotation_euler.x=math.pi/2
world=bpy.data.worlds.new(name+' studio');world.use_nodes=True;next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs[0].default_value=(.12,.14,.18,1);next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs[1].default_value=.7;scene.world=world
for name,position,power,size in [('Key',(1,-4,6),1700,7),('Fill',(-4,-1,3),800,5)]:
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=position;ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.cameras.new('Armory review');ob=bpy.data.objects.new('Armory review',camera);scene.collection.objects.link(ob);ob.location=(0,-10,4.5);ob.rotation_euler=(Vector((0,0,1.15))-ob.location).to_track_quat('-Z','Y').to_euler();camera.type='ORTHO';camera.ortho_scale=7.7;scene.camera=ob
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
# Retain the scene's existing view transform.
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(root/'refined/armory-review.blend'),copy=True)
print('REFERENCE_ARMORY_READY',len(keys),len(scene.objects))
