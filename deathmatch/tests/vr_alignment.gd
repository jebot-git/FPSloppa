extends SceneTree
var failures: Array=[]
class Locomotion extends Node:
	var actor
	var rig
	var avatar
	var worst:=0.0
	var frame_error:=0.0
	func _physics_process(delta: float) -> void:
		actor.position.z-=5.0*delta
		worst=maxf(worst,avatar.global_position.distance_to(rig.global_position))
	func _process(_delta: float) -> void:
		frame_error=maxf(frame_error,avatar.global_position.distance_to(rig.global_position))
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.avatars.set_process(false)
	game.hud=load("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
	game.xr_rig=load("res://deathmatch/vr/rig.gd").new();game.add_child(game.xr_rig);game.xr_rig.setup(game,true)
	var rig=game.xr_rig;rig.set_process(false);rig.tracking.enabled=false;rig.calibration_pending=false
	var peer:=ENetMultiplayerPeer.new();var result:=peer.create_client("127.0.0.1",27889)
	check(result==OK,"Client peer created for owner-side rendering test")
	if result!=OK:game.free();quit(1);return
	var id:=peer.get_unique_id();game._add_player(id,"Local tracked body");game.active=true;game.menu_open=false
	game.multiplayer.multiplayer_peer=peer
	var actor=game.fighters[id];actor.position=Vector3(1000,10,1000);actor.reset_view()
	var avatar=game.avatars.library.create_avatar(game.avatars.library.selected)
	check(avatar!=null,"Real bundled VRM loads for local-body test")
	if avatar==null:game.free();quit(1);return
	actor.set_avatar(avatar,game.avatars.library.selected);actor.show_alive(true,true);actor.set_local_body(true)
	rig.head.position=Vector3(0,1.65,0);rig.origin_offset=Vector3.ZERO
	for yaw in [0.0,PI/2,PI,-PI/2]:
		game.local_yaw=yaw;game.players[id].yaw=0;game.players[id].xr=game.VRPoses.neutral()
		rig._process(.01);actor._process(.01);avatar._process(.01)
		var pose: Dictionary=rig.sample_pose()
		var expected: Transform3D=rig.global_transform*pose.weapon
		var actual: Transform3D=game._weapon_transform(id)
		check(actual.is_equal_approx(expected),"Predicted shot matches tracked gun despite stale server yaw at %.2f"%yaw)
		check(avatar.global_transform.is_equal_approx(rig.global_transform),"Local avatar shares headset render origin at %.2f"%yaw)
		check(avatar.xr_pose.head.is_equal_approx(pose.head),"Local IK consumes current frame tracking at %.2f"%yaw)
	var state: Dictionary=game.players[id];var current: Dictionary=rig.sample_pose()
	actor.xr_pose=current;actor.update_height(.95,true);actor.spawn_serial=1
	var echoed: Dictionary=game.VRPoses.neutral();echoed.head.origin.x=.5
	var row: Array=[id,actor.position,Vector3.ZERO,0.0,0.0,100,0,false,2,[50,0,0,0],[2],0,0,30,1,0.0,false,0.0,echoed,0.0,false,Vector2.ZERO]
	game._snapshot([row],PackedByteArray(),60.0,0.0,"",20,600.0,[],[],game.map_epoch,{},{} )
	check(actor.xr_pose.head.is_equal_approx(current.head) and actor.collision_height==.95,"Stale snapshot cannot replace local tracking or expand current crouch")
	check(not avatar.secondary_nodes.is_empty(),"Bundled VRM contains spring systems for the suppression test")
	check(avatar.secondary_nodes.all(func(node):return node.local_body_disabled),"All local VRM spring systems are disabled")
	avatar.set_first_person(false)
	check(avatar.secondary_nodes.all(func(node):return not node.local_body_disabled),"Returning avatar to third person restores springs")
	# Exercise the actual client prediction-effects path with current tracking,
	# while the server echo still contains an unobstructed neutral pose.
	var fixture=preload("res://deathmatch/tests/fixture.gd");fixture.setup(game)
	actor.position=fixture.point(9.5,0);actor.update_height(1.65,true);actor.reset_view()
	game.local_yaw=0;state.yaw=0;state.xr=game.VRPoses.neutral();state.vr_device=true;state.weapon=2;state.ammo=[50,0,0,0]
	rig.right.position=Vector3(.8,1.1,0);rig.left.position=rig.right.position
	rig.right_aim.basis=Basis(Vector3.UP,-PI/2);rig.left_aim.basis=rig.right_aim.basis
	rig._process(.01);await physics_frame
	game.headless=false;game.clock=100;game.visual_cooldown=0;game.offhand_visual_cooldown=0;game.predicted_shot_clock=-99;game.predicted_offhand_shot_clock=-99
	game._predict_shots(id,{"fire":true,"offhand_fire":true,"xr":rig.sample_pose()})
	check(game.predicted_shot_clock==-99 and game.predicted_offhand_shot_clock==-99 and game.visual_cooldown==0 and game.offhand_visual_cooldown==0,"Both hands behind wall suppress predicted firing effects despite clear stale server pose")
	rig.right.position=Vector3(-.2,1.1,-.3);rig.left.position=Vector3(-.4,1.1,-.3)
	rig.right_aim.basis=Basis.IDENTITY;rig.left_aim.basis=Basis.IDENTITY;rig._process(.01)
	game._predict_shots(id,{"fire":true,"offhand_fire":true,"xr":rig.sample_pose()})
	check(game.predicted_shot_clock==100 and game.predicted_offhand_shot_clock==100 and game.visual_cooldown>0 and game.offhand_visual_cooldown>0,"Clear main and offhand shots still predict their firing effects")
	game.headless=DisplayServer.get_name()=="headless"
	# Let real render/physics ordering run at different rates. Comparing only
	# _process transforms misses a second interpolation in the rendered subtree.
	avatar.set_first_person(true)
	game.active=true;rig.set_process(true);actor.set_process(true);avatar.set_process(true)
	var driver:=Locomotion.new();driver.actor=actor;driver.rig=rig;driver.avatar=avatar;driver.process_priority=100
	# Flush the manual poses before collecting movement rather than teleport history.
	rig._process(.01);actor._process(.01);avatar._process(.01);root.add_child(driver)
	await create_timer(1.2).timeout
	print("LOCAL_BODY_MOTION_ERROR physics=",driver.worst," render=",driver.frame_error)
	check(driver.worst<.003 and driver.frame_error<.003,"Local avatar stays with tracked origin between physics ticks and render frames")
	driver.free();rig.set_process(false)
	peer.close();game.multiplayer.multiplayer_peer=null;game.active=false;game.free();await process_frame
	print("VR_ALIGNMENT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
