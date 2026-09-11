extends SceneTree
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.set_process(false);g.set_physics_process(false)
	g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig)
	var rig=g.xr_rig
	rig.setup(g,true);rig.set_process(false)
	var actor=load("res://deathmatch/fighter.gd").new();actor.setup(1,"Local",Color.WHITE);g.add_child(actor)
	actor.position=Vector3(1000,10,1000)
	g.fighters[1]=actor;g.players[1]=g._new_state("Local",1)
	g.active=true;g.menu_open=false
	actor.show_alive(true,true)
	var library=g.avatars.library
	for hash in library.entries:
		var avatar=library.create_avatar(hash)
		actor.set_avatar(avatar,hash)
		check(not avatar.visible,"Local avatar hidden before body tracking: "+library.entries[hash].title)
		actor.set_local_body(true)
		var visible_count:=0;var third_hidden:=0
		for mesh in avatar.visual_meshes:
			if mesh.visible: visible_count+=1
			if mesh.get_meta("arena_third_person") and not mesh.get_meta("arena_first_person") and not mesh.visible: third_hidden+=1
		check(avatar.visible and visible_count>0 and third_hidden>0,"Body visible and head meshes hidden: "+library.entries[hash].title)
		actor.xr_pose=Poses.neutral()
		actor.xr_pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.85,0)),"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.15,.2,-.2))}
		actor._process(.016);avatar._process(.016);avatar.solver._process_modification_with_delta(.016)
		check(not avatar.gun.visible and avatar.process_mode==Node.PROCESS_MODE_INHERIT,"Local IK runs without duplicate weapon")
		var foot: Vector3=avatar.skeleton.to_global(avatar.skeleton.get_bone_global_pose(avatar.skeleton.find_bone("LeftFoot")).origin)
		check(foot.distance_to(actor.to_global(Vector3(-.15,.2,-.2)))<.08,"First-person foot follows body tracking")
		actor.xr_pose.body.left_foot.origin.z=-.35
		actor._process(.016);avatar._process(.016)
		check(avatar.xr_pose.body.left_foot==actor.xr_pose.body.left_foot,"Local body uses current pose without network smoothing")
		actor.set_local_body(false)
		actor.show_alive(true,false)
		check(avatar.visible and not avatar.first_person,"Remote avatar retains full third-person mesh")
		actor.show_alive(true,true)
	var body:=XRBodyTracker.new();body.name="/user/body_tracker";body.has_tracking_data=true
	body.set_joint_transform(XRBodyTracker.JOINT_HIPS,Transform3D(Basis.IDENTITY,Vector3(0,.92,0)))
	body.set_joint_flags(XRBodyTracker.JOINT_HIPS,XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
	XRServer.add_tracker(body)
	rig._process(0)
	check(actor.local_body_visible and actor.xr_pose.body.has("hips") and not rig.hand_models[0].visible,"Live native tracking enables local body and replaces controller gloves")
	g.menu_open=true;rig._process(0)
	check(not actor.local_body_visible and rig.hand_models[0].visible,"Menu restores controller gloves and hides body")
	g.menu_open=false;rig._process(0)
	rig.focused=false;rig._process(0)
	check(not actor.local_body_visible,"Focus loss hides local body")
	rig.focused=true;rig.tracking.enabled=false;rig._process(0)
	check(actor.local_body_visible and actor.avatar.visible,"Controller-only VR retains avatar arms when body tracking is disabled")
	rig.tracking.enabled=true;body.has_tracking_data=false;rig._process(0)
	check(actor.local_body_visible and actor.avatar.visible,"Body tracker loss retains controller-driven avatar arms")
	body.has_tracking_data=true;actor.show_alive(false,true);rig._process(0)
	check(not actor.local_body_visible and not actor.avatar.visible,"Dead local player has no body obstructing view")
	XRServer.remove_tracker(body)
	# Feed controller inputs through XRServer, including handedness and focus.
	var controllers: Array[XRControllerTracker]=[]
	for hand in ["left_hand","right_hand"]:
		var tracker:=XRControllerTracker.new();tracker.name=hand;XRServer.add_tracker(tracker);controllers.append(tracker)
		tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(-.25 if hand=="left_hand" else .25,1.2,-.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		tracker.set_input("grip",0.0)
	await process_frame
	check(not g.voice.push_to_talk(),"VR microphone stays quiet with grips released")
	controllers[0].set_input("grip",1.0)
	check(g.voice.push_to_talk(),"Off-hand grip activates push-to-talk")
	rig.left_handed=true
	check(not g.voice.push_to_talk(),"Swapping weapon hand also swaps push-to-talk grip")
	controllers[1].set_input("grip",1.0)
	check(g.voice.push_to_talk(),"Right grip activates left-handed push-to-talk")
	rig.focused=false
	check(not g.voice.push_to_talk(),"Unfocused VR cannot activate push-to-talk")
	for tracker in controllers: XRServer.remove_tracker(tracker)
	g.free()
	print("LOCAL_BODY_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
