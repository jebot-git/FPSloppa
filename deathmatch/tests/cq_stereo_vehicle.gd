extends SceneTree
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
class Rig extends Node3D:
 var head:Camera3D
 var gun:Node3D
 var hand_models:Array=[]
class Game extends Node3D:
 var active:=true
 var menu_open:=false
 var viewmodel:Node3D
 var offhand_viewmodel:Node3D
 var camera:Camera3D
 var xr_rig:Rig
 var players:Dictionary={1:{}}
 func _weapon_transform(_id:int)->Transform3D:return xr_rig.gun.global_transform
 func is_vr():return true
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var game:=Game.new();root.add_child(game);game.xr_rig=Rig.new();game.add_child(game.xr_rig)
 game.xr_rig.head=Camera3D.new();game.xr_rig.head.position.y=1.65;game.xr_rig.add_child(game.xr_rig.head);game.camera=game.xr_rig.head;game.camera.make_current()
 game.xr_rig.gun=Node3D.new();game.xr_rig.add_child(game.xr_rig.gun)
 var service:=Tanks.new();game.add_child(service);service.game=game
 service.rows[0]=service.spawn_row({"poi":"test","position":Vector3.ZERO,"yaw":0.,"kind":"rocket","team":0});service.rows[0].pilot=1;service.body(0)
 var hull:=Node3D.new();service.add_child(hull);service.models[0]=hull
 var view=preload("res://deathmatch/conquest/classes/battery_view.gd").new();game.add_child(view);view.setup(game,service)
 var mask:int=game.camera.cull_mask;var env=game.camera.environment
 await physics_frame;view.update()
 check(view.viewport==null and view.screen==null and view.overlay==null,"VR tank never creates desktop scope feed")
 check(game.camera.cull_mask==mask and game.camera.environment==env,"VR tank retains the normal world and lighting")
 check(view.reticle!=null and view.reticle.visible and view.reticle.mesh.get_surface_count()==1,"tank crosshair is projected world geometry for both eyes")
 check(not hull.visible,"own tank hull cannot occlude seated eye cameras")
 view.deactivate();check(hull.visible and not view.reticle.visible,"dismount restores hull and removes reticle")
 game.queue_free();await process_frame;await process_frame
 print("CQ_STEREO_VEHICLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
