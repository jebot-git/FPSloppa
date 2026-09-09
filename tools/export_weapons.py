import bpy,os,math
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
SOURCE=PROJECT.parent/"WeaponSource"
from mathutils import Vector
out=str(PROJECT/'deathmatch/weapons')
os.makedirs(out,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
with bpy.data.libraries.load(str(SOURCE/'afps_weapons.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if n.startswith('weapon')]
lengths={1:.9,2:.55,3:1.05,4:1.05,5:.9,6:1.1,7:.9,8:1.2,9:1.05}
for ob in dst.objects:
 if not ob or ob.type!='MESH':continue
 num=int(ob.name.replace('weapon',''));bpy.context.scene.collection.objects.link(ob)
 ob.location=(0,0,0);ob.rotation_euler=(0,0,0);ob.scale=(1,1,1)
 coords=[v.co.copy() for v in ob.data.vertices];mn=Vector(tuple(min(v[i] for v in coords) for i in range(3)));mx=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
 scale=lengths[num]/(mx.z-mn.z)
 for v in ob.data.vertices:
  original=v.co.copy();gx=(original.x-(mn.x+mx.x)*.5)*scale;gy=(original.y-(mn.y+mx.y)*.5)*scale;gz=.22-(original.z-mn.z)*scale
  v.co=(gx,-gz,gy)
 mat=bpy.data.materials.new('AFPS_Weapon_'+str(num));mat.use_nodes=True
 bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.65
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(SOURCE/('weapon%d.png'%num)),check_existing=True);mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
 ob.data.materials.clear();ob.data.materials.append(mat)
 bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
 bpy.ops.export_scene.gltf(filepath=out+'/afps_%d.glb'%num,export_format='GLB',use_selection=True,export_animations=False)
 print('EXPORTED',num,len(ob.data.polygons),lengths[num])
 bpy.context.scene.collection.objects.unlink(ob)
