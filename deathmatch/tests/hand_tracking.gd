extends SceneTree
const Hands=preload("res://deathmatch/vr/hand_input.gd")
const Glove=preload("res://deathmatch/vr/glove_fingers.gd")
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func _initialize(): call_deferred("run")
func run():
	var map: OpenXRActionMap=load("res://deathmatch/vr/actions.tres")
	for side in ["left","right"]:
		var index:=map.find_interaction_profile("/interaction_profiles/valve/index_controller")
		for input_path in ["a/touch","b/touch","thumbstick/touch","trackpad/touch"]:
			check(index.bindings.any(func(b):return b.binding_path=="/user/hand/"+side+"/input/"+input_path),"Index binds "+side+" "+input_path)
		var touch:=map.find_interaction_profile("/interaction_profiles/oculus/touch_controller")
		check(touch.bindings.any(func(b):return b.action.resource_name=="thumbrest_touch" and b.binding_path=="/user/hand/"+side+"/input/thumbrest/touch"),"Touch binds "+side+" thumbrest")
	var tracker:=XRControllerTracker.new();tracker.name="left_hand";XRServer.add_tracker(tracker)
	var controller:=XRController3D.new();controller.tracker="left_hand";root.add_child(controller)
	tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	check(Hands.sample(controller)==PackedFloat32Array([0,0,0,0,0]),"Released controller opens all fingers")
	tracker.set_input("grip",1.0)
	check(Hands.sample(controller)==PackedFloat32Array([0,0,1,1,1]),"Touch grip makes pointing gesture")
	tracker.set_input("trigger",1.0)
	check(Hands.sample(controller)==PackedFloat32Array([0,1,1,1,1]),"Grip and trigger with thumb released makes thumbs up")
	tracker.set_input("thumbrest_touch",true)
	check(Hands.sample(controller)[0]>.8,"Touch thumbrest closes thumb")
	tracker.set_input("thumbrest_touch",false);tracker.set_input("trigger",0.0);tracker.set_input("trigger_touch",true)
	check(is_equal_approx(Hands.sample(controller)[1],.15),"Trigger touch has a resting pose without firing")
	check(ProjectSettings.get_setting("xr/openxr/extensions/hand_tracking"),"OpenXR hand joints requested at startup")
	check(ProjectSettings.get_setting("xr/openxr/extensions/hand_tracking_controller_data_source"),"Controller-inferred Index hand data requested")
	var hand:=XRHandTracker.new();hand.name="/user/hand_tracker/left";hand.has_tracking_data=true
	hand.hand_tracking_source=XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
	XRServer.add_tracker(hand)
	for finger in range(5):
		var angle:float=float(finger)*.5
		var points:=[Vector3.ZERO,Vector3(0,.03,0),Vector3(0,.05,0),Vector3(sin(angle)*.03,.05+cos(angle)*.03,0)]
		for i in range(4):
			var joint:int=Hands.FINGERS[finger][i]
			hand.set_hand_joint_flags(joint,XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID)
			hand.set_hand_joint_transform(joint,Transform3D(Basis.IDENTITY,points[i]))
	var curls:=Hands.sample(controller,hand)
	check(curls[0]<.01 and curls[1]<curls[2] and curls[2]<curls[3] and curls[3]<curls[4],"Index/streamed native joints bend each finger independently without requiring wrist data")
	check(Hands.local_sample(controller,"left")==curls,"Local glove consumes independent Index finger joints")
	check(Hands.local_sample(controller,"right")==Hands.controller_curls(controller),"Missing local tracker keeps controller gesture fallback")
	hand.set_hand_joint_flags(Hands.FINGERS[2][0],0)
	check(Hands.sample(controller,hand)[2]==1 and Hands.sample(controller,hand)[1]<.3,"Invalid finger falls back individually to controller input")
	hand.has_tracking_data=false
	check(Hands.sample(controller,hand)==Hands.controller_curls(controller),"Lost native hand data falls back immediately")
	for side in ["left","right"]:
		var model=load("res://addons/godot-xr-tools/hands/scenes/lowpoly/"+side+"_tac_glove_low.tscn").instantiate();controller.add_child(model)
		model.set_physics_process(false);model.top_level=false
		var modifier:=Glove.new();modifier.setup(model,side)
		var skel:=modifier.get_skeleton()
		var before: Array=[]
		for bone in range(skel.get_bone_count()):before.append(skel.get_bone_pose_position(bone))
		check(modifier.rotations.size()>=15,side+" glove has authored poses for all five fingers")
		modifier.curls=PackedFloat32Array([0,1,0,0,0]);modifier._process_modification_with_delta(1)
		var changed:=false
		for entry in modifier.rotations:
			var actual:=skel.get_bone_pose_rotation(entry[0])
			check(actual.is_equal_approx(entry[3] if entry[1]==1 else entry[2]),side+" glove finger rotation "+str(entry[0]))
			if entry[1]==1 and not entry[2].is_equal_approx(entry[3]): changed=true
		check(changed,side+" index finger bends independently")
		check(range(skel.get_bone_count()).all(func(b):return skel.get_bone_pose_position(b).is_equal_approx(before[b])),side+" gesture preserves all bone lengths and wrist position")
		var updates:=[0]
		modifier.modification_processed.connect(func():updates[0]+=1)
		await process_frame;await process_frame;await process_frame
		check(updates[0]>0,side+" glove modifier runs automatically with CQ physics driver disabled")
		model.free()
	XRServer.remove_tracker(hand);XRServer.remove_tracker(tracker);controller.free()
	print("HAND_TRACKING_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
