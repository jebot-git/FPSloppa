extends SceneTree
const Stock=preload("res://deathmatch/vr/virtual_stock.gd")
const Guard=preload("res://deathmatch/vr/foveation_guard.gd")
class Runtime extends RefCounted:
 signal session_begun
 signal session_synchronized
 signal session_focussed
 var ready:=false
 var native:=true
 var gaze:=true
 var writes:=0
 var foveation_level:=0:
  set(value):foveation_level=value;writes+=1
 var foveation_dynamic:=false
 var vrs_min_radius:=0.0
 var vrs_strength:=0.0
 var render_target_size_multiplier:=1.0:
  set(value):render_target_size_multiplier=value;foveation_level=0
 func is_initialized()->bool:return ready
 func is_foveation_supported()->bool:return native
 func is_eye_gaze_interaction_supported()->bool:return gaze
 func get_view_count()->int:return 2
 func get_render_target_size()->Vector2:return Vector2(2000,2000)*render_target_size_multiplier
class Bindings extends RefCounted:
 var two_handed:=true
 func vr_pressed(_rig,_action)->bool:return true
class Hands extends RefCounted:
 func claims_hand(_a,_b)->bool:return false
class Game extends Node:
 var bindings=Bindings.new()
 var menu_open:=false
 var desired_weapon:=9
 func local_state()->Dictionary:return {"weapon":desired_weapon}
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 for weapon in [9]:
  for left in [false,true]:
   var stock=Stock.new()
   var head:=Transform3D(Basis.IDENTITY,Vector3(0,1.7,0))
   var pistol:=Transform3D(Basis.IDENTITY,Vector3(-.18 if left else .18,1.5,-.2))
   var support:=pistol.translated(Vector3(0,-.05,-.04))
   var result:Transform3D=stock.solve(pistol,support,head,weapon,left,true,"cq")
   check(stock.engaged and result.is_equal_approx(pistol),"scout engagement preserves sights")
   var jitter:=pistol;jitter.basis=Basis(Vector3.RIGHT,.08)
   result=stock.solve(jitter,support,head,weapon,left,true,"cq")
   check(result.basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY)<.04 and result.origin==pistol.origin,"scout wrist jitter reduced without translation")
   stock.solve(pistol,support,head,weapon,left,false,"cq")
   check(not stock.engaged,"release disables stock")
   check(stock.solve(jitter,support,head,weapon,left,true,"cq").is_equal_approx(jitter),"regrip recalibrates without snap")
 var distant=Stock.new()
 var extended:=Transform3D(Basis.IDENTITY,Vector3(.18,1.5,-.65))
 distant.solve(extended,extended,Transform3D(Basis.IDENTITY,Vector3(0,1.7,0)),9,false,true,"cq")
 check(not distant.engaged,"stocked scout pistol does not snap while held at arm length")
 var rifle=Stock.new()
 var rifle_pose:=Transform3D(Basis.IDENTITY,Vector3(.18,1.47,-.1))
 var rifle_support:=rifle_pose.translated(Vector3(0,0,-.35))
 check(rifle.solve(rifle_pose,rifle_support,Transform3D(Basis.IDENTITY,Vector3(0,1.7,0)),3,false,true,"cq").origin==rifle_pose.origin and rifle.engaged,"rifle shoulder brace retained")
 rifle.solve(rifle_pose,rifle_support,Transform3D.IDENTITY,0,false,true,"cq")
 check(not rifle.engaged,"ordinary sidearms remain unsupported")
 var game:=Game.new();root.add_child(game)
 var rig=load("res://deathmatch/vr/rig.gd").new();game.add_child(rig);rig.set_process(false)
 rig.game=game;rig.simulated=true;rig.focused=true;rig.cq_hands=Hands.new()
 rig.head=XRCamera3D.new();rig.add_child(rig.head);rig.head.position=Vector3(0,1.7,0)
 for key in ["left","right","left_aim","right_aim"]:
  rig.set(key,XRController3D.new());rig.add_child(rig.get(key))
 rig.right.position=Vector3(.18,1.5,-.2);rig.right_aim.transform=rig.right.transform
 rig.left.transform=rig.right.transform;rig.left.position+=Vector3(0,.025,-.07)*.65
 for weapon in [9,10]:
  game.desired_weapon=weapon
  rig.left.transform=rig.right.transform;rig.left.position+=preload("res://deathmatch/conquest/classes/models.gd").anchor(weapon,"support_anchor")*.65
  rig.weapon_pose()
  check(rig.support_aim.engaged and rig.virtual_stock.engaged,"actual rig enables scout stock")
 rig.virtual_stock_enabled=false;rig.weapon_pose();check(not rig.virtual_stock.engaged,"rig setting disables scout stock")
 game.free()
 var runtime:=Runtime.new();var viewport:=SubViewport.new();root.add_child(viewport)
 var guard:=Guard.new();root.add_child(guard);guard.set_process(false)
 var settings={"render_scale":.8,"foveation_level":2,"fovea_size":2,"foveation_dynamic":true}
 guard.configure(viewport,runtime,settings)
 check(viewport.vrs_mode==Viewport.VRS_DISABLED,"late XR initialization safe")
 runtime.ready=true;guard._process(.5)
 check(runtime.foveation_level==2 and runtime.foveation_dynamic and viewport.vrs_mode==Viewport.VRS_XR,"late readiness applies scale then profile")
 for i in 31:guard._process(.01)
 var writes:=runtime.writes
 for i in 100:guard._process(.01)
 check(runtime.writes==writes,"stable runtime avoids profile rewrites")
 runtime.session_focussed.emit()
 for i in 30:guard._process(.01)
 check(runtime.writes==writes+3,"resume refreshes matching native profile in bounded retries")
 viewport.vrs_mode=Viewport.VRS_DISABLED;guard._process(.5)
 check(viewport.vrs_mode==Viewport.VRS_XR,"lost viewport VRS repaired")
 runtime.render_target_size_multiplier=1.0;guard._process(.5)
 check(is_equal_approx(runtime.render_target_size_multiplier,.8) and runtime.foveation_level==2,"lost render scale repaired before profile")
 settings.foveation_level=0;settings.fovea_size=0;guard.configure(viewport,runtime,settings)
 for i in 31:guard._process(.02)
 check(viewport.vrs_mode==Viewport.VRS_DISABLED,"Off preserved after retries")
 settings.foveation_level=1;settings.foveation_dynamic=false;guard.configure(viewport,runtime,settings)
 check(not runtime.foveation_dynamic and runtime.foveation_level==1,"static preference preserved")
 runtime.native=false;runtime.gaze=true;settings.foveation_dynamic=true;settings.fovea_size=3;guard.configure(viewport,runtime,settings)
 check(runtime.vrs_min_radius==55.0 and viewport.vrs_mode==Viewport.VRS_XR,"generic gaze VRS configured")
 guard.free();viewport.free()
 print("CQ_STOCK_FOVEATION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
