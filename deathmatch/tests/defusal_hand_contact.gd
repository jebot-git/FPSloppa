extends SceneTree
const Contact=preload("res://deathmatch/counterstrike/bomb_interaction.gd")
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Finger geometry",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	if not g.hud:g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true)
	var rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false
	await physics_frame;await physics_frame
	var de=g.match_mode.defusal;de.tick(0);de.phase="live";de.phase_end=g.clock+300;de.carrier=1;de.held=true
	g.players[1].weapon=1;g.desired_weapon=1;g.menu_open=false
	var actor=g.fighters[1];rig.global_position=actor.position
	rig.head.position=Vector3(0,1.65,0);rig.left.transform=Transform3D(Basis.IDENTITY,Vector3(-.2,1.35,-.45));rig.right.transform=Transform3D(Basis.IDENTITY,Vector3(.25,1.2,-.35))
	rig.left_aim.transform=Transform3D(Basis(Vector3.RIGHT,-.7),rig.left.position);rig.right_aim.transform=rig.right.transform
	actor.set_local_body(false)
	for left in [false,true]:
		rig.left_handed=left
		var i:=1 if left else 0;var skeleton: Skeleton3D=rig.hand_animators[i].get_skeleton()
		for curl in [0.0,.7]:
			rig.hand_animators[i].curls=PackedFloat32Array([0,curl,0,0,0]);rig.hand_animators[i]._process_modification_with_delta(1)
			var pose: Dictionary=rig.sample_pose()
			var tip: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Index_Tip_"+("R" if left else "L"))).origin
			check(pose.has("index_tip") and (rig.global_transform*pose.index_tip).distance_to(tip)<.0001,"Glove contact follows visible fingertip, independent of aim ray: "+str([left,curl]))
	rig.left_handed=false
	var library=g.avatars.library
	for hash in library.entries:
		var avatar=library.create_avatar(hash);actor.set_avatar(avatar,hash);actor.show_alive(true,true);actor.set_local_body(true)
		for left in [false,true]:
			rig.left_handed=left
			var side: String="right" if left else "left"
			var pose: Dictionary=rig.sample_pose();pose.erase("index_tip");actor.xr_pose=pose
			actor._process(.016);avatar._process(.016);avatar.solver._process_modification_with_delta(.016)
			var point: Vector3=rig.keypad_finger.sample(rig,pose)
			var visible: Vector3=rig.keypad_finger.world_tip(avatar,avatar.skeleton,not left)
			if not visible.is_finite():
				var i:=1 if left else 0
				visible=rig.keypad_finger.world_tip(rig.hand_models[i],rig.hand_animators[i].get_skeleton(),not left)
				rig.keypad_finger.present(rig,actor)
				check(rig.hand_models[i].visible and avatar.keypad_glove==side,"Legacy avatar uses visible tracked glove for precise keypad input")
			check(point.is_finite() and (rig.global_transform*point).distance_to(visible)<.001,"Avatar contact follows evaluated distal skin: "+library.entries[hash].title+" / "+side)
			var controller: XRController3D=rig.get(side);controller.position.x+=.04
			var moved: Dictionary=pose.duplicate();moved[side]=rig.origin.transform*controller.transform
			var now: Vector3=rig.keypad_finger.sample(rig,moved)
			check(now.is_finite() and now.distance_to(point+Vector3.RIGHT*.04)<.001,"Fingertip follows latest palm without skeletal update lag")
			controller.position.x-=.04
	# Render chest purchases and a fingertip resting on the held keypad.
	rig.left_handed=false;de.held=false;de.account(1).kit=true;g.players[1].xr=rig.sample_pose();rig.keypad_finger.present(rig,actor);de.draw()
	check(de.visuals.tools.has(1) and de.visuals.tools[1].visible,"Owned tweezers render on chest before being drawn")
	var expected: Transform3D=rig.global_transform*Contact.tool_carried(rig.sample_pose())
	check(de.visuals.tools[1].global_transform.is_equal_approx(expected),"Visible chest tweezers share the authoritative hip attachment")
	var camera:=Camera3D.new();g.add_child(camera);camera.near=.025;camera.fov=65;camera.make_current()
	for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
	for surface in [rig.panel,rig.keyboard,rig.status_surface,rig.blackout,rig.damage_overlay,rig.weapon_wheel]:
		if is_instance_valid(surface):surface.hide()
	for pointer in rig.pointers:pointer.enabled=false;pointer.hide()
	for guide in rig.aim_guides:guide.hide()
	actor.avatar.set_first_person(false)
	camera.global_position=actor.position+Vector3(.65,1.55,-1.15);camera.look_at(actor.position+Vector3(0,1.25,0))
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cs16/chest-keypad/chest.png")
	actor.avatar.set_first_person(true);de.held=true
	for animator in rig.hand_animators:animator.curls=PackedFloat32Array([0,0,0,0,0]);animator._process_modification_with_delta(1)
	var pose: Dictionary=rig.sample_pose();actor.xr_pose=pose;actor._process(.016);actor.avatar._process(.016);actor.avatar.solver._process_modification_with_delta(.016)
	var desired: Vector3=Contact.held(pose)*Contact.key_point(5)
	var point: Vector3=rig.keypad_finger.sample(rig,pose)
	rig.left.position+=desired-point
	pose=rig.sample_pose();actor.xr_pose=pose;actor._process(.016);actor.avatar._process(.016);actor.avatar.solver._process_modification_with_delta(.016)
	g.players[1].xr=rig.sample_pose();rig.keypad_finger.present(rig,actor);de.draw()
	check(de.visuals.bomb.focus_key.visible,"Actual free-hand fingertip highlights contacted keycap")
	camera.global_position=actor.position+Vector3(-.18,1.62,.05);camera.look_at(de.visuals.bomb.global_position)
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cs16/chest-keypad/keypad-finger.png")
	print("DE_HAND_CONTACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
