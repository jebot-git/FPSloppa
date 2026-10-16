extends SceneTree
const Preview=preload("res://deathmatch/vr/calibration_preview.gd")
class Tracking extends RefCounted:
 var pose:Dictionary={}
 var hand_models:Array=[]
 var left_handed:=false
 var virtual_stock_enabled:=true
 func sample_pose()->Dictionary:return pose
class Arena extends RefCounted:
 var headless:=false
 var loadout_menu=null
 var xr_rig=Tracking.new()
 var avatars:Dictionary={}
 func is_vr()->bool:return true
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var library=preload("res://deathmatch/avatars/library.gd").new()
 var hash:String=library.register_file("res://deathmatch/avatars/models/base/soldier.utavatar",false);library.selected=hash
 var game=Arena.new();game.avatars={"library":library}
 for i in 2:
  var hand:=Node3D.new();game.xr_rig.hand_models.append(hand)
 var page=Preview.new();root.add_child(page);page.setup(game);page.set_process(false)
 check(page.get_child(0).flip_h,"preview texture is horizontally mirrored")
 var neutral:Dictionary={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.3,1.1,-.4)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.4)),"weapon":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.4))}
 for yaw in [0.,PI/2.,PI,-PI/2.]:
  var reference:=Transform3D(Basis(Vector3.UP,yaw),Vector3(1.2,0,-.8))
  game.xr_rig.pose=neutral.duplicate()
  for key in game.xr_rig.pose:game.xr_rig.pose[key]=reference*neutral[key]
  var original:Dictionary=game.xr_rig.pose.duplicate()
  page._process(0.)
  check(is_instance_valid(page.preview),"live preview created")
  page.preview.set_process(false);page.preview.advance_animation(.1)
  check(absf(page.preview.rotation.y)<.00001,"avatar faces camera at tracking yaw %s"%yaw)
  check(page.preview.local_xr_pose.head.is_equal_approx(neutral.head),"avatar tracking normalized at yaw %s"%yaw)
  for i in 2:
   check(page.hands[i].transform.is_equal_approx(neutral["left" if i==0 else "right"]),"hand/avatar alignment at yaw %s"%yaw)
  check(original==game.xr_rig.pose,"live source pose unchanged")
 if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name()!="headless":
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  page.viewport.get_texture().get_image().save_png("/tmp/cq-calibration-front-facing.png")
 page.free()
 for hand in game.xr_rig.hand_models:hand.free()
 library.free()
 print("CALIBRATION_PREVIEW_LIVE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
