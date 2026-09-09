extends SceneTree
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rig=preload("res://deathmatch/vr/rig.gd").new()
	root.add_child(rig)
	rig.origin=XROrigin3D.new();rig.add_child(rig.origin)
	rig.setup_controllers()
	var trackers: Array[XRControllerTracker]=[]
	for hand in ["left_hand","right_hand"]:
		var tracker:=XRControllerTracker.new();tracker.name=hand
		XRServer.add_tracker(tracker);trackers.append(tracker)
		var x:=-.25 if hand=="left_hand" else .25
		tracker.set_pose("grip",Transform3D(Basis(Vector3.UP,.4),Vector3(x,1.2,-.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		tracker.set_pose("aim",Transform3D(Basis(Vector3.RIGHT,.2),Vector3(x,1.25,-.5)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	for node in [rig.left,rig.right,rig.left_aim,rig.right_aim]:
		check(node.get_has_tracking_data() and node.position.y>1,"Late-connected runtime pose drives "+node.name)
	check(rig.left.transform!=rig.left_aim.transform,"Grip and weapon aim retain independent 6DoF poses")
	trackers[1].set_pose("aim",Transform3D(Basis(Vector3.UP,-.7),Vector3(.4,1.6,-.7)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	check(rig.right_aim.position.is_equal_approx(Vector3(.4,1.6,-.7)) and rig.right_aim.basis.is_equal_approx(Basis(Vector3.UP,-.7)),"Weapon aim follows translation and rotation")
	var map=load("res://deathmatch/vr/actions.tres")
	for path in ["/interaction_profiles/oculus/touch_controller","/interaction_profiles/valve/index_controller","/interaction_profiles/bytedance/pico4_controller"]:
		var profile=map.find_interaction_profile(path)
		for hand in ["left","right"]:
			for pose in ["grip","aim"]:
				var found:=false
				for binding in profile.get_bindings():
					if binding.action.resource_name==pose+"_pose" and binding.binding_path=="/user/hand/"+hand+"/input/"+pose+"/pose": found=true
				check(found,path+" binds "+hand+" "+pose)
	var eye_profile=map.find_interaction_profile("/interaction_profiles/ext/eye_gaze_interaction")
	check(eye_profile.get_bindings()[0].action.resource_name=="eye_gaze_pose","Gaze has a separate action from controller default pose")
	for tracker in trackers: XRServer.remove_tracker(tracker)
	await process_frame
	check(not rig.left.get_has_tracking_data() and not rig.right_aim.get_has_tracking_data(),"Tracker disconnection clears tracking")
	rig.free()
	print("CONTROLLER_TRACKING_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
