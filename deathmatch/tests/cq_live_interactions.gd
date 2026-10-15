extends SceneTree
const InputHands=preload("res://deathmatch/vr/hand_input.gd")
const Slots=preload("res://deathmatch/conquest/classes/equipment_slots.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game)
 game.start_host("Live interaction QA",0,200,10,true,"tdm","ut99");game.set_process(false);game.set_physics_process(false)
 if not game.hud:game.hud=load("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
 if not game.xr_rig:game.xr_rig=preload("res://deathmatch/vr/rig.gd").new();game.add_child(game.xr_rig)
 var rig=game.xr_rig
 if not rig.enabled:rig.setup(game,true)
 rig.set_process(false);rig.calibration_pending=false;rig.head.position=Vector3(0,1.65,0);rig.left_handed=false
 var trackers:Array=[]
 for i in 2:
  var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="left_hand" if i==0 else "right_hand";tracker.description="Test controller";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_pose("aim",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);XRServer.add_tracker(tracker);trackers.append(tracker)
 await process_frame
 for i in 2:
  trackers[i].set_input("grip",.9);trackers[i].set_input("trigger",.7)
  await process_frame
  var curls:=InputHands.controller_curls(rig.left if i==0 else rig.right)
  check(curls[1]>.6 and curls[2]>.8,"controller input supplies skeletal finger curls "+str(i))
  var animator=rig.hand_animators[i];check(animator.rotations.size()>10,"artist finger poses found in skeleton "+str(i))
  if not animator.rotations.is_empty():
   var skeleton:Skeleton3D=animator.get_skeleton();var bone:int=animator.rotations[0][0]
   animator.curls=PackedFloat32Array([0,0,0,0,0]);animator._process_modification_with_delta(.5);var before:Quaternion=skeleton.get_bone_pose_rotation(bone)
   animator.curls=PackedFloat32Array([1,1,1,1,1]);animator._process_modification_with_delta(.5);check(before.angle_to(skeleton.get_bone_pose_rotation(bone))>.05,"local hand skeleton physically animates "+str(i))
  trackers[i].set_input("grip",0.);trackers[i].set_input("trigger",0.)
 for side in 2:
  rig.cq_utility.reset()
  for t in trackers:t.set_input("grip",0.);t.set_input("trigger",0.)
  var mount:Vector3=rig.origin.to_local(rig.shoulder_mount(false).origin)
  trackers[side].set_pose("grip",Transform3D(Basis.IDENTITY,mount),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  await process_frame;rig.cq_utility.update(.016,true)
  trackers[side].set_input("grip",1.);await process_frame;rig.cq_utility.update(.016,true)
  check(rig.cq_utility.held and rig.cq_utility.hand_index==side,"either hand grips visible mirrored shoulder equipment "+str(side))
  rig.update_shoulder_utility(true)
  var expected:Transform3D=preload("res://deathmatch/conquest/classes/grenade_visuals.gd").held_pose(rig.cq_utility.hand().global_transform,side==0)
  check(rig.shoulder_utility.global_transform.is_equal_approx(expected),"grenade uses CS grip pose on chosen hand "+str(side))
  trackers[side].set_input("grip",0.);await process_frame;rig.cq_utility.update(.016,true);check(not rig.cq_utility.held,"release returns unarmed shoulder equipment "+str(side))
 trackers[1].set_input("by_button",true);trackers[0].set_input("by_button",false);await process_frame
 check(game.bindings.vr_pressed(rig,"reload") and not game.bindings.vr_pressed(rig,"menu") and not game.bindings.vr_pressed(rig,"scores"),"weapon B/Y is reserved for ejection")
 trackers[1].set_input("by_button",false);trackers[0].set_input("by_button",true);await process_frame
 check(game.bindings.vr_pressed(rig,"scores") and not game.bindings.vr_pressed(rig,"reload"),"support B/Y opens tactical map")
 var mount:=Slots.mount(Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),false,true)
 check(absf(mount.basis.z.x)>.8 and mount.origin.z<-.2,"primary holster carries diagonally across chest")
 rig.place_menu();var menu_at:Transform3D=rig.panel.global_transform;rig.global_position+=Vector3(30,5,-10)
 check(rig.panel.global_transform.is_equal_approx(menu_at),"deployment panel remains stable across actor-origin changes")
 var preview=load("res://deathmatch/vr/calibration_preview.gd").new();game.add_child(preview);preview.setup(game)
 var old:bool=rig.virtual_stock_enabled;preview.stock.pressed.emit();check(rig.virtual_stock_enabled!=old and preview.stock.button_pressed==rig.virtual_stock_enabled and preview.stock.text.ends_with("ON" if rig.virtual_stock_enabled else "OFF"),"virtual stock toggle updates highlight and on/off text")
 rig.virtual_stock_enabled=old;rig.save_turn_settings();preview.free()
 for t in trackers:XRServer.remove_tracker(t)
 game.disconnect_game();game.queue_free();await process_frame;await process_frame
 print("CQ_LIVE_INTERACTIONS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
