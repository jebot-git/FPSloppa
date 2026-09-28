from pathlib import Path
p=Path('/home/blux/Documents/FPSloppa/tools/tribes/model.py')
exec(compile(p.read_text().split('report={};anchors={}')[0].replace("'Tribes Arsenal'","'Tribes Armour'"),str(p),'exec'))
report={}
for level,name in enumerate(['light','medium','heavy']):
 parts=[];width=[.43,.53,.63][level];depth=[.28,.34,.41][level]
 # Origin at torso centre. Open face and independent shoulder plates preserve avatars.
 profile('Front cuirass',[(-depth/2-.045,.25),(-depth/2-.075,.04),(-depth/2-.035,-.24),(-depth/2+.008,-.24),(-depth/2+.008,.25)],width,0)
 box('Spine plate',(0,0,depth/2),(.30,.46,.055),1)
 for side in [-1,1]:
  x=side*(width/2+.065)
  box('Shoulder shell',(x,.22,0),([.12,.20,.29][level],[.10,.17,.23][level],[.22,.30,.40][level]),0)
  box('Shoulder rim',(x,.28,0),([.13,.21,.30][level],.025,[.23,.31,.41][level]),2)
  box('Torso side',(side*width*.47,-.02,.005),(.055,.4,depth),1)
  for stripe in range(level+1):box('Class stripe',(side*.13,.15-stripe*.055,-depth/2-.075),(.10,.021,.015),6)
 if level>0:
  for y in [-.11,-.20]:box('Abdominal overlap',(0,y,-depth/2-.06),(width*.74,.07,.06),2)
 if level==2:
  for side in [-1,1]:box('Raised armoured collar',(side*.145,.33,.03),(.07,.23,.30),1)
  box('Collar bridge',(0,.35,.18),(.30,.17,.06),1)
  box('Heavy breastplate',(0,.025,-depth/2-.085),(.20,.15,.07),3)
 for ob in scene.objects:ob.select_set(False)
 for ob in parts:ob.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();ob=parts[0];ob.name='armour_'+name
 bpy.ops.export_scene.gltf(filepath=str(OUT/(ob.name+'.glb')),use_selection=True,use_active_scene=True,export_yup=True)
 report[name]={'triangles':sum(len(f.vertices)-2 for f in ob.data.polygons)};ob.location.x=level*1.2
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_distance=4;area.spaces.active.region_3d.view_location=Vector((1.2,0,0));area.spaces.active.region_3d.view_rotation=Quaternion((.84,.35,.18,.36))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'tribes-armour.blend'),copy=True)
print(report)
