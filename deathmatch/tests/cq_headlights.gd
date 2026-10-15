extends SceneTree
const Headlights=preload("res://deathmatch/conquest/classes/vehicle_headlights.gd")
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
var failures:Array=[]
var checks:=0
class Game extends Node3D:
 var camera:Camera3D
 func world_view_camera():return camera
class Service extends Node3D:
 var game
 var rendered_rows:Dictionary={}
 func profile(row):return Tanks.profile(row)
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func row(at:Vector3,pilot:int=0)->Dictionary:return {"position":at,"visual_y":at.y,"normal":Vector3.UP,"yaw":0.,"kind":"transport","hp":100,"pilot":pilot,"headlights":true}
func run():
 var game:=Game.new();root.add_child(game);game.camera=Camera3D.new();game.add_child(game.camera);game.camera.position=Vector3(0,1,3);game.camera.make_current()
 var service:=Service.new();game.add_child(service);service.game=game
 var lights:=Headlights.new();service.rendered_rows={1:row(Vector3(20,0,0)),2:row(Vector3(50,0,0),1),3:row(Vector3(30,0,0)),4:row(Vector3(200,0,0))}
 lights.update(service);check(lights.selected==[2,1],"local driver prioritized and bounded to two vehicles")
 service.rendered_rows[2].hp=0;service.rendered_rows[1].headlights=false
 lights.update(service);check(lights.selected==[3],"wrecks, switched-off and distant vehicles excluded")
 check(lights.previous.size()==4,"unused lamp slots cleared")
 var slope:Dictionary=row(Vector3(10,5,10));slope.normal=Vector3(0,.98,.2).normalized();slope.yaw=PI*.5
 var pose:=Headlights.lamp_pose(slope,-1,Tanks.PROFILES.transport.size)
 var direction:Vector3=-pose.basis.z
 check(direction.dot(Tanks.visual_basis(slope)*Vector3.FORWARD)>.99,"beam follows tilted hull orientation")
 var model:=Node3D.new();game.add_child(model);Headlights.prepare(model,slope,Tanks.PROFILES.transport.size);check(model.get_node("HeadlightLenses").get_child_count()==2,"two visible lens meshes per vehicle")
 lights.clear();check(lights.selected.is_empty() and lights.previous.is_empty(),"reset clears global illumination")
 # Exercise real optimized player shader with two dynamic cones.
 var library=load("res://deathmatch/avatars/library.gd").new();game.add_child(library)
 var avatar=library.create_avatar("20016c75fa136a32fd180fec93b3c7274f8ae2c851560691a0bc3b8a39e916f2");game.add_child(avatar);avatar.set_process(false);avatar.rotation.y=PI
 game.camera.look_at(Vector3(0,1,0));root.size=Vector2i(640,480);root.content_scale_size=root.size
 RenderingServer.global_shader_parameter_set("jungle_baked_enabled",true);RenderingServer.global_shader_parameter_set("jungle_sun_mix",Vector3.ZERO);RenderingServer.global_shader_parameter_set("jungle_sky_color",Vector3.ZERO);RenderingServer.global_shader_parameter_set("jungle_day_mix",1.)
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 var off:=root.get_texture().get_image()
 service.rendered_rows={1:row(Vector3(0,0,8),1)}
 # Put lamp faces behind the camera; forward cones still cover the actor.
 lights.update(service)
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 var on:=root.get_texture().get_image();var delta:=0.
 for y in range(0,mini(on.get_height(),off.get_height()),4):
  for x in range(0,mini(on.get_width(),off.get_width()),4):
   var a:=on.get_pixel(x,y);var b:=off.get_pixel(x,y);delta+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
 check(delta>1.,"production mixed headlights visibly illuminate optimized player shader")
 DirAccess.make_dir_recursive_absolute("res://test-results/headlights");off.save_png("res://test-results/headlights/player-off.png");on.save_png("res://test-results/headlights/player-on.png")
 lights.clear();game.free();print("CQ_HEADLIGHTS_RESULT ",JSON.stringify({"checks":checks,"image_delta":delta,"failures":failures}));quit(0 if failures.is_empty() else 1)
