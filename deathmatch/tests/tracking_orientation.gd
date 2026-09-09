extends SceneTree
const Body=preload("res://deathmatch/vr/body_basis.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
class FakeRig extends Node3D:
 var origin:=Node3D.new()
 var head:=Node3D.new()
 var focused:=true
 func _init():add_child(origin);origin.add_child(head);head.position.y=1.65
 func controller(label,tracker_name,pose_name):
  var c:=XRController3D.new();c.name=label;c.tracker=tracker_name;c.pose=pose_name;origin.add_child(c);return c
var failures: Array=[]
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
 var actions=load("res://deathmatch/vr/actions.tres")
 var profile=actions.find_interaction_profile("/interaction_profiles/htc/vive_tracker_htcx")
 check(profile!=null and profile.bindings.size()==8 and profile.bindings.all(func(binding):return binding.action.resource_name=="tracker_pose" and binding.binding_path.ends_with("/input/grip/pose")),"All eight Vive roles bind to the dedicated pose action")
 for action in actions.get_action_set(0).actions:
  if action.resource_name in ["default_pose","haptic"]:check(action.toplevel_paths.size()==2,"Hand action excludes unsupported and unrelated tracker subpaths: "+action.resource_name)
 var rig:=FakeRig.new();root.add_child(rig)
 var tracking=load("res://deathmatch/vr/tracking.gd").new();rig.add_child(tracking);tracking.setup(rig)
 var vive:=XRControllerTracker.new();vive.name="/user/vive_tracker_htcx/role/waist";XRServer.add_tracker(vive)
 vive.set_pose("default",Transform3D(Basis(Vector3.UP,PI),Vector3(0,.9,0)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
 await process_frame
 check(tracking.external().has("hips"),"SteamVR standard default role pose is detected")
 vive.invalidate_pose("default")
 vive.set_pose("tracker_pose",Transform3D(Basis(Vector3.UP,PI),Vector3(0,.9,0)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
 await process_frame
 check(tracking.external().has("hips") and tracking.role_nodes.hips.get_has_tracking_data(),"Dedicated Vive action drives the live role node")
 rig.head.rotation.y=PI
 tracking.calibrate()
 check(tracking.sample().hips.basis.z.dot(Vector3.FORWARD)>.99,"Vive calibration follows the direction the player faces")
 XRServer.remove_tracker(vive)
 rig.head.rotation=Vector3.ZERO
 var now:float=Time.get_ticks_msec()*.001
 tracking.osc.samples={"hips":{"position":Vector3(0,.9,0),"basis":Basis(Vector3.UP,PI),"time":now,"rotation_time":now},"left_foot":{"position":Vector3(.15,.1,0),"basis":Basis(Vector3.UP,PI),"time":now,"rotation_time":now}}
 tracking.calibrate()
 var before:Vector3=tracking.sample().left_foot.origin
 tracking.osc.samples.left_foot.position.z+=.2
 var after:Vector3=tracking.sample().left_foot.origin
 check(after.z<before.z-.19,"Slime forward motion stays forward when its reset frame is reversed")
 check(tracking.sample().hips.basis.is_equal_approx(Basis.IDENTITY),"Slime neutral torso faces the headset direction")
 tracking.osc.samples.clear()
 var native_tracker:=XRBodyTracker.new();native_tracker.name="/user/body_tracker";native_tracker.has_tracking_data=true
 native_tracker.set_joint_flags(XRBodyTracker.JOINT_HIPS,XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
 native_tracker.set_joint_transform(XRBodyTracker.JOINT_HIPS,Transform3D(Basis.from_euler(Vector3(PI/2,.4,0)),Vector3(0,.9,0)))
 XRServer.add_tracker(native_tracker);tracking.calibrate()
 check(tracking.sample().hips.basis.is_equal_approx(Basis.IDENTITY) and tracking.sample().hips.origin.is_equal_approx(Vector3(0,.9,0)),"Native bridge calibration corrects orientation without shifting measured joints")
 native_tracker.set_joint_flags(XRBodyTracker.JOINT_LEFT_LOWER_LEG,XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
 var lower_basis:Basis=Basis(Vector3.UP,PI)*Body.native_rest.LeftLowerLeg
 native_tracker.set_joint_transform(XRBodyTracker.JOINT_LEFT_LOWER_LEG,Transform3D(lower_basis,Vector3(-.13,.32,0)))
 tracking.calibrate()
 var planted:Transform3D=tracking.sample().left_foot
 check(absf(planted.origin.y-.08)<.001,"Calf tracker without foot joint calibrates ankle height")
 native_tracker.set_joint_transform(XRBodyTracker.JOINT_LEFT_LOWER_LEG,Transform3D(Basis(Vector3.RIGHT,-PI/2)*lower_basis,Vector3(-.13,.62,0)))
 var lifted:Transform3D=tracking.sample().left_foot
 check(lifted.origin.y>planted.origin.y+.4 and lifted.origin.z>.2,"Lifting and bending native lower leg lifts the estimated foot instead of pinning it to floor")
 native_tracker.set_joint_flags(XRBodyTracker.JOINT_LEFT_FOOT,XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
 native_tracker.set_joint_transform(XRBodyTracker.JOINT_LEFT_FOOT,Transform3D(Basis.IDENTITY,Vector3(-.2,.4,-.3)))
 check(tracking.sample().left_foot.origin.is_equal_approx(Vector3(-.2,.4,-.3)),"An actual native foot joint takes priority over the inferred ankle")
 XRServer.remove_tracker(native_tracker)
 rig.free()
 var world:=Node3D.new();root.add_child(world)
 var lib=load("res://deathmatch/avatars/library.gd").new();root.add_child(lib)
 Body.native_to_facing("hips",Basis.IDENTITY)
 for hash in lib.entries:
  var avatar=lib.create_avatar(hash);world.add_child(avatar);avatar.set_first_person(true)
  var pose=Poses.neutral()
  var turn:=Basis(Vector3.UP,.6)
  pose.body={}
  for key in ["hips","chest","left_foot","right_foot"]:
   var bone_name:String=Body.BONES[key]
   var idx:int=avatar.skeleton.find_bone(bone_name)
   var at:Vector3=avatar.skeleton.to_global(avatar.skeleton.get_bone_global_rest(idx).origin)
   var native:Basis=turn*Basis(Vector3.UP,PI)*Body.native_rest[bone_name]
   pose.body[key]=Transform3D(Body.native_to_facing(key,native),turn*at)
  avatar.target_xr_pose=pose;avatar._process(.016);avatar.solver._process_modification_with_delta(.016)
  for key in ["hips","chest","left_foot","right_foot"]:
   var idx:int=avatar.skeleton.find_bone(Body.BONES[key])
   var actual:Basis=avatar.skeleton.global_basis.orthonormalized()*avatar.skeleton.get_bone_global_pose(idx).basis.orthonormalized()
   var expected:Basis=turn*avatar.skeleton.global_basis.orthonormalized()*avatar.skeleton.get_bone_global_rest(idx).basis
   check(actual.is_equal_approx(expected),lib.entries[hash].title+" native "+key+" keeps correct facing/bone axes")
  avatar.free()
 lib.free();world.free()
 print("TRACKING_ORIENTATION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
