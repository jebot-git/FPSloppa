"""CC0 atze tankcar hull + mutantleg rocket battery, metre scale and generated Godot LODs."""
import bpy,subprocess,tempfile,zipfile,json,math,numpy as np
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
out=root/'deathmatch/models/battery_tank';out.mkdir(parents=True,exist_ok=True)
def material(name,path,size):
 image=bpy.data.images.load(str(path));image.scale(size,size);image.name=name
 m=bpy.data.materials.new(name);m.use_nodes=True
 bsdf=m.node_tree.nodes.get('Principled BSDF');t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=image;m.node_tree.links.new(t.outputs['Color'],bsdf.inputs['Base Color']);bsdf.inputs['Roughness'].default_value=.9
 return m
with tempfile.TemporaryDirectory(prefix='battery-tank-') as tmp:
 folder=Path(tmp);subprocess.run(['7z','x','-y',str(root/'tools/battery_tank/source/panzerwagen.7z'),'-o'+tmp],check=True,stdout=subprocess.DEVNULL)
 with zipfile.ZipFile(root/'tools/battery_tank/source/launcher_tank.zip') as z:z.extractall(folder/'launcher')
 bpy.ops.wm.open_mainfile(filepath=str(folder/'panzerwagen/panzerwagen_3x3.blend'))
 # Original cannon, turret and antenna are replaced by the requested battery.
 for o in list(bpy.data.objects):
  if o.type!='MESH' or o.name in ['Plane.004','Plane.011','Plane.016']:bpy.data.objects.remove(o,do_unlink=True)
 bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=[o for o in bpy.data.objects if o.type=='MESH'][0];bpy.ops.object.join();hull=bpy.context.object;hull.name='Hull'
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 source=sum(len(p.vertices)-2 for p in hull.data.polygons)
 lo=Vector([min(v.co[i] for v in hull.data.vertices) for i in range(3)]);hi=Vector([max(v.co[i] for v in hull.data.vertices) for i in range(3)])
 factor=4.8/(hi.y-lo.y)
 for v in hull.data.vertices:v.co=(v.co-Vector(((lo.x+hi.x)*.5,(lo.y+hi.y)*.5,lo.z)))*factor
 # Tankcar front is Blender -Y; export forward is Blender +Y / Godot -Z.
 hull.rotation_euler.z=math.pi;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 dec=hull.modifiers.new('Hull reduction','DECIMATE');dec.ratio=.72;bpy.ops.object.modifier_apply(modifier=dec.name)
 hull.data.materials.clear();hull.data.materials.append(material('Tank camouflage',folder/'panzerwagen/texture_panzerwagen.png',512))
 for p in hull.data.polygons:p.material_index=0
 bpy.ops.object.select_all(action='DESELECT');bpy.ops.wm.obj_import(filepath=str(folder/'launcher/rockethead.obj'),forward_axis='Y',up_axis='Z');head=bpy.context.object;head.name='Battery'
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 hlo=Vector([min(v.co[i] for v in head.data.vertices) for i in range(3)]);hhi=Vector([max(v.co[i] for v in head.data.vertices) for i in range(3)])
 print('HEAD_BOUNDS',hlo,hhi)
 for v in head.data.vertices:v.co=(v.co-Vector(((hlo.x+hhi.x)*.5,(hlo.y+hhi.y)*.5,hlo.z)))*(2.2/(hhi.x-hlo.x))
 # Crop only the green upper half of the hull atlas. No tire/metal regions.
 original=hull.data.materials[0].node_tree.nodes.get('Image Texture').image
 pixels=np.empty(512*512*4,dtype=np.float32);original.pixels.foreach_get(pixels)
 crop=pixels.reshape(512,512,4)[256:512:2,0:512:2,:].copy()
 camouflage=bpy.data.images.new('Battery camouflage only',width=256,height=128)
 camouflage.pixels.foreach_set(crop.ravel());camouflage.filepath_raw=str(folder/'battery_camouflage.png');camouflage.file_format='PNG';camouflage.save()
 head.data.materials.clear();head.data.materials.append(material('Battery camouflage only',folder/'battery_camouflage.png',256));head.data.materials.append(material('Missile metal original',folder/'launcher/rockethead_skin.png',128))
 # Eight separate 5-vertex pyramid nose caps are missiles, never camouflage.
 adjacent={v.index:set() for v in head.data.vertices}
 for edge in head.data.edges:
  a,b=edge.vertices;adjacent[a].add(b);adjacent[b].add(a)
 unseen=set(adjacent);missiles=set();missile_groups=0
 while unseen:
  seed=unseen.pop();group={seed};todo=[seed]
  while todo:
   for other in adjacent[todo.pop()]:
    if other in unseen:unseen.remove(other);group.add(other);todo.append(other)
  if len(group)==5:missiles.update(group);missile_groups+=1
 assert missile_groups==8, f'Expected eight missile nose caps, got {missile_groups}'
 for polygon in head.data.polygons:polygon.material_index=1 if polygon.vertices[0] in missiles else 0
 pivot=bpy.data.objects.new('Aim',None);bpy.context.scene.collection.objects.link(pivot);pivot.location=(0,0,1.8);head.parent=pivot
 bpy.ops.object.select_all(action='DESELECT')
 for o in [hull,head,pivot]:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(out/'battery_tank.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
 result={'source_hull_triangles':source,'hull_triangles':sum(len(p.vertices)-2 for p in hull.data.polygons),'battery_triangles':sum(len(p.vertices)-2 for p in head.data.polygons),'length_m':4.8,'width_m':float(hull.dimensions.x),'materials':3,'draws':3,'textures':[512,256,128],'missile_components':missile_groups}
 (root/'tools/battery_tank/mesh-budget.json').write_text(json.dumps(result,indent=2)+'\n');print('BATTERY_BUDGET',result)
