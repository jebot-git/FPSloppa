extends SceneTree
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures: Array=[]
class FakeRig extends Node3D:
	var origin:=Node3D.new()
	var head:=Node3D.new()
	var focused:=true
	func _init() -> void: add_child(origin);origin.add_child(head)
	func controller(label: String,tracker: String,pose: String) -> XRController3D:
		var node:=XRController3D.new();node.name=label;node.tracker=tracker;node.pose=pose;origin.add_child(node);return node
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var pose:=Poses.neutral()
	pose.face={"look":Vector2(20,-20),"blink":Vector2(2,-2),"gaze":true,"lids":true}
	var safe:=Poses.validate(pose)
	check(safe.face.look.is_equal_approx(Vector2(.20944,-.139626)) and safe.face.blink==Vector2(.9,0),"Network eye angles and eyelids clamped")
	pose.face.look.x=NAN
	check(Poses.validate(pose).face.is_empty() and Poses.validate(pose).weapon==pose.weapon,"Invalid eye data discarded without changing weapon")
	pose.face={"look":Vector2.ZERO,"blink":Vector2.ZERO,"gaze":1,"lids":true}
	check(Poses.validate(pose).face.is_empty(),"Invalid capability flags rejected")
	var rig:=FakeRig.new();root.add_child(rig)
	var eyes:=preload("res://deathmatch/vr/eyes.gd").new();rig.add_child(eyes);eyes.setup(rig)
	check(eyes.sample().is_empty(),"Unsupported headsets send no eye data")
	var face:=XRFaceTracker.new();face.name="/user/face_tracker";XRServer.add_tracker(face)
	face.set_blend_shape(XRFaceTracker.FT_EYE_CLOSED_LEFT,.6)
	face.set_blend_shape(XRFaceTracker.FT_EYE_LOOK_OUT_LEFT,.8)
	face.set_blend_shape(XRFaceTracker.FT_EYE_LOOK_IN_RIGHT,.8)
	check(is_equal_approx(eyes.sample().blink.x,.6) and eyes.sample().look.x>0,"Native face tracker supplies blink and gaze")
	rig.focused=false
	check(eyes.sample().is_empty(),"Unfocused session clears eye data")
	rig.focused=true;XRServer.remove_tracker(face)
	var gaze:=XRPositionalTracker.new();gaze.name="/user/eyes_ext";gaze.type=XRServer.TRACKER_CONTROLLER;XRServer.add_tracker(gaze)
	gaze.set_pose("eye_gaze",Transform3D(Basis(Vector3.UP,.1),Vector3.ZERO),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	var measured:=eyes.sample()
	check(measured.get("gaze",false) and not measured.get("lids",false) and absf(measured.look.x-.1)<.001,"OpenXR gaze works without inventing blinks")
	XRServer.remove_tracker(gaze);rig.free()
	var library=preload("res://deathmatch/avatars/library.gd").new();root.add_child(library)
	for hash in library.entries:
		# Saved custom avatars need not have eyes; these assertions describe bundled samples.
		if not library.entries[hash].path.begins_with("res://deathmatch/avatars/models/"): continue
		var actor:=Node3D.new();root.add_child(actor)
		var avatar=library.create_avatar(hash);actor.add_child(avatar)
		check(avatar.eyes.eye_bones.size()==2 or not avatar.eyes.binds[0].is_empty(),"VRM supports bounded look: "+library.entries[hash].title)
		check(not avatar.eyes.binds[6].is_empty() or not avatar.eyes.binds[4].is_empty(),"VRM supports blinking: "+library.entries[hash].title)
		var positions: Dictionary={}
		for bone in avatar.eyes.eye_bones: positions[bone]=avatar.skeleton.get_bone_pose_position(bone)
		avatar.xr_pose=Poses.neutral();avatar.xr_pose.face={"look":Vector2(10,10),"blink":Vector2(1,1),"gaze":true,"lids":true}
		avatar.eyes._process_modification_with_delta(1)
		var bounded: bool=avatar.eyes.look.x<=.20944 and avatar.eyes.look.y<=.139626
		for bone in positions:
			bounded=bounded and positions[bone]==avatar.skeleton.get_bone_pose_position(bone)
			var rest: Quaternion=avatar.skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			bounded=bounded and rest.angle_to(avatar.skeleton.get_bone_pose_rotation(bone))<deg_to_rad(15)
		check(bounded,"Eye bones rotate within limits without translation")
		for binds in avatar.eyes.binds:
			for bind in binds: check(bind[0].get_blend_shape_value(bind[1])<=.90001,"Eyelid / look shape weight bounded")
		avatar.xr_pose.clear();avatar.eyes._process_modification_with_delta(1)
		check(avatar.eyes.look.length()<.001 and avatar.eyes.blink.length()<.001,"Tracking loss returns eyes to rest")
		actor.free()
	library.free()
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	for row in game.map_catalog:
		game.selected_map=row.id;game.start_host("Practice",0,20,10,true)
		check(game.active and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and game.players.size()==4,"Offline BSP match with three bots: "+row.id)
		check(game.players[1].owned==[2] and game.players[-1].owned==[2],"Humans and bots spawn pistol-only")
		var initial: Vector3=game.fighters[-1].position
		await create_timer(2.5).timeout
		check(game.fighters[-1].position.distance_to(initial)>.5,"Bot moves through BSP: "+row.id)
		check(game.bots.region.navigation_mesh.get_polygon_count()>0,"Prebaked navigation available: "+row.id)
		game.disconnect_game()
	game.start_host("Practice",0,20,10,true)
	preload("res://deathmatch/tests/fixture.gd").setup(game)
	game.fighters[1].position=Vector3(1000,10,997)
	game.fighters[-1].position=Vector3(1000,10,1000)
	game.players[1].invulnerable=0
	await create_timer(2).timeout
	check(game.players[1].hp<100 and game.players[-1].ammo[0]<50,"Bot acquires visible target and shoots with normal ammo cost")
	game.players[-1].invulnerable=0;game._damage(-1,1,1000,"test",true)
	await create_timer(2.2).timeout
	check(not game.players[-1].dead and game.players[-1].owned==[2],"Bot respawns using normal inventory rules")
	game.disconnect_game()
	game.free()
	print("EYES_BOTS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
