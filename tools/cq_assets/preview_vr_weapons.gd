extends SceneTree
## Synthetic controller poses with the actual runtime glove assets and CQ grip transforms.
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const Art=preload("res://deathmatch/art.gd")
const Glove=preload("res://deathmatch/vr/glove_fingers.gd")
const Support=preload("res://deathmatch/vr/aim_support.gd")
const OUTPUT="res://test-results/weapon-sources/vr-held-20261016"
const ROWS=[
 {"class":"SHOCKTROOP","slots":[4,1,14]},
 {"class":"MEDIC","slots":[3,12,13]},
 {"class":"SCOUT","slots":[9,10,16]},
 {"class":"TECHNICIAN","slots":[5,11,15]},
 {"class":"SIDEARMS / DESIGNATOR","slots":[2,0,8]}
]
var viewport:SubViewport
var world:Node3D
var holder:Node3D
var camera:Camera3D
var records:Array=[]
func _initialize():run.call_deferred()
func glove(side:String,parent:Node3D,pose:Transform3D):
 var hand:Node3D=load("res://addons/godot-xr-tools/hands/scenes/lowpoly/"+side+"_tac_glove_low.tscn").instantiate()
 parent.add_child(hand);hand.set_physics_process(false);hand.set_process(false);hand.top_level=false;hand.global_transform=pose
 var fingers:=Glove.new();fingers.setup(hand,side)
 fingers.curls=PackedFloat32Array([.8,.25 if side=="right" else .9,.95,.95,.95]);fingers.displayed=fingers.curls
 return hand
func bounds(node:Node3D)->AABB:
 var box:=AABB();var first:=true
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  if not mesh.mesh or mesh.mesh.get_surface_count()==0:continue
  var next:AABB=mesh.global_transform*mesh.get_aabb();box=next if first else box.merge(next);first=false
 return box
func add_weapon(slot:int,at:Vector3,rotate:bool=true):
 var unit:=Node3D.new();holder.add_child(unit)
 var model:=Models.weapon(slot,"cq_technician");unit.add_child(model)
 model.global_transform=Art.held_transform(Transform3D.IDENTITY,slot,Art.VR_SCALE,"cq_technician")
 glove("right",unit,Transform3D.IDENTITY)
 if Support.supports(slot,"cq"):glove("left",unit,Models.support_pose(model.global_transform,slot,true))
 for display in model.find_children("*","SubViewport",true,false):
  display.own_world_3d=true;display.render_target_update_mode=SubViewport.UPDATE_ONCE
 if rotate:unit.rotation=Vector3(.1,-PI/2+.35,0)
 var box:=bounds(unit);unit.position+=at-box.get_center()
 return model
func text_label(value:String,at:Vector3):
 var label:=Label3D.new();label.text=value;label.position=at;label.font_size=40;label.pixel_size=.0012;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;holder.add_child(label)
func clear():
 if holder:holder.free()
 holder=Node3D.new();world.add_child(holder)
func capture(filename:String):
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 var picture:=viewport.get_texture().get_image();assert(picture.save_png(OUTPUT+"/"+filename+".png")==OK)
 print("VR_WEAPON_RENDER ",filename," ",picture.get_size())
func run():
 assert(DisplayServer.get_name()!="headless")
 DirAccess.make_dir_recursive_absolute(OUTPUT);root.size=Vector2i(960,640)
 viewport=SubViewport.new();viewport.size=Vector2i(2400,1800);viewport.msaa_3d=Viewport.MSAA_4X;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 world=Node3D.new();viewport.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("26323c");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.9;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=3.;world.add_child(light)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,140,0);fill.light_energy=1.2;world.add_child(fill)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.;camera.position=Vector3(0,.35,10);world.add_child(camera);camera.look_at(Vector3.ZERO);camera.make_current()
 clear()
 for row in ROWS.size():
  var data:Dictionary=ROWS[row];var y:=1.75-row*.87
  text_label(data["class"],Vector3(0,y+.33,0))
  for column in 3:
   var slot:int=data.slots[column];var at:=Vector3((column-1)*1.9,y,0)
   add_weapon(slot,at);text_label(Models.entry(slot,"cq_technician").to_upper().replace("_"," "),at+Vector3(0,-.31,.05))
 await capture("all-weapons-vr-hands")
 viewport.size=Vector2i(1600,1100)
 for data in ROWS:
  for slot in data.slots:
   clear();var model:Node3D=add_weapon(slot,Vector3.ZERO)
   camera.position=Vector3(.1,.2,3);camera.look_at(Vector3.ZERO);camera.size=maxf(.48,bounds(holder).size.length()*.9)
   var filename:=Models.entry(slot,"cq_technician")+"-held"
   await capture(filename)
   # Head-relative view: real grip at origin, neutral aim forward, camera above/behind.
   clear();model=add_weapon(slot,Vector3.ZERO,false)
   var grip:Vector3=model.global_position
   camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=70.;camera.position=grip+Vector3(-.16,.20,.42);camera.look_at(grip+Vector3(0,.05,-.55))
   await capture(Models.entry(slot,"cq_technician")+"-first-person")
   camera.projection=Camera3D.PROJECTION_ORTHOGONAL
   records.append({"slot":slot,"asset":Models.entry(slot,"cq_technician"),"held":filename+".png","first_person":Models.entry(slot,"cq_technician")+"-first-person.png"})
 clear();var launcher:Node3D=add_weapon(11,Vector3.ZERO,false);var panel=launcher.get_node("GuidanceMonitor")
 camera.position=panel.global_position+Vector3(.008,.008,.13);camera.look_at(panel.global_position);camera.size=.065
 for state in ["search","acquiring","locked","in-flight"]:
  panel.update_guidance(launcher,{"elapsed":.75} if state=="acquiring" else {"ready":true} if state in ["locked","in-flight"] else {},{},0.,true,8.2 if state=="in-flight" else -1.)
  await capture("t2-screen-"+state)
 FileAccess.open(OUTPUT+"/render.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"models":records,"scope":"Actual runtime models, attachments, glove assets, artist finger curls and CQ held/support transforms; synthetic neutral controller poses, studio lighting. First-person views are desktop renders, not HMD captures. T2 closeups use demonstration lock/lifetime data."},"  "))
 world.free();quit()
