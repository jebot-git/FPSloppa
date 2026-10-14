extends SceneTree
const Test=preload("res://deathmatch/tests/cq_battery_tank.gd")
class Bindings extends "res://deathmatch/settings/bindings.gd":
	var inputs:Dictionary={}
	func vr_pressed(_rig:Node,action:String) -> bool:return inputs.get(action,false)
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false);game.start_host("Avatar mounts",28812,100,10,false)
	game.voice.set_process(false);game.voice.mode=1;game.voice_enabled=true;game.menu_open=false;game.players[1].team=0
	game.hud=load("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
	var rig=load("res://deathmatch/vr/rig.gd").new();game.add_child(rig);game.xr_rig=rig;rig.setup(game,true);rig.set_process(false);rig.calibration_pending=false;rig.seated=false
	var bindings:=Bindings.new();game.bindings=bindings
	var settings=load("res://deathmatch/settings/panel.gd").new();game.add_child(settings);settings.setup(game);settings.refresh()
	check(settings.tracking_status.text.contains("T-pose") and not settings.controls.has("body"),"Calibration menu explains T-pose without retired tracking controls")
	var library=game.avatars.library
	var hash:String=library.register_file("res://deathmatch/avatars/models/base/soldier.utavatar",false)
	var actor=game.fighters[1];actor.set_avatar(library.create_avatar(hash),hash);actor.set_process(false)
	game.classes.ensure(1);game.players[1].dead=false;game.players[1].spectator=false;actor.show_alive(true,true)
	rig.head.position=Vector3(0,1.65,0);rig.left.position=Vector3(-1.2,1.5,-.5);rig.right.position=Vector3(1.2,1.5,-.5)
	for i in 20:rig._process(.02)
	check(actor.avatar.ik_weight>.99,"Hidden first person body still solves anatomical arm limits")
	check(rig.gun.global_position.distance_to(actor.avatar.to_global(actor.avatar.hand_pose().origin))<.00001,"First person gun shares constrained avatar wrist")
	check(rig.hand_models[1].global_position.distance_to(rig.gun.global_position)<.00001,"Controller glove stays with gun at visual reach limit")
	check(rig.shoulder_radio.model.global_position.distance_to(rig.shoulder_mount(true).origin)<.00001,"Radio mounted on mainhand shoulder")
	check(rig.shoulder_utility.global_position.distance_to(rig.shoulder_mount(false).origin)<.00001,"Class utility mounted on offhand shoulder")
	rig.head.position=Vector3(.25,1.65,-.2);rig.left.position=Vector3(-.45,1.35,-.2);rig.right.position=Vector3(.95,1.35,-.2);rig.origin_offset=Vector3.ZERO
	for i in 75:rig._process(.02)
	check(is_equal_approx(rig.origin_offset.x,-.25) and is_equal_approx(rig.origin_offset.z,.2),"Held calibration T-pose recenters body under headset")
	bindings.physical_crouch=true;bindings.physical_prone=true;bindings.physical_jump=true
	var controls=load("res://deathmatch/settings/bindings_panel.gd").new();game.add_child(controls);controls.setup(game)
	check(controls.checks.has("physical_crouch") and controls.checks.has("physical_prone") and controls.checks.has("physical_jump"),"All physical movement controls remain exposed")
	rig.head.position.y=1.65;rig.crouch_detector.reset();rig.jump_detector.reset()
	for i in 5:rig._process(.02)
	rig.head.position.y=.95;rig._process(.02)
	var crouch:Dictionary=rig.command(30);game._accept_input(1,crouch);game._update_crouch(1,game.players[1].xr,crouch)
	check(is_equal_approx(crouch.xr.height,1.05) and is_equal_approx(actor.collision_height,1.05),"Physical crouch reaches authoritative collision capsule")
	rig.head.position.y=.35;rig._process(.02)
	var prone:Dictionary=rig.command(31);game._accept_input(1,prone);game._update_crouch(1,game.players[1].xr,prone)
	check(prone.prone and actor.stance=="prone" and is_equal_approx(actor.collision_height,.65),"Physical prone reaches authoritative stance and capsule")
	rig.head.position.y=1.65;actor.update_height(1.65);rig.jump_detector.reset()
	for i in 30:
		actor.simulate(Vector2.ZERO,0,false,1.0/60.0);await physics_frame
	check(actor.is_supported(),"Physical jump fixture has actual grounded contact")
	for i in 6:rig._process(.02)
	rig.head.position.y=1.67;rig._process(.02);rig.head.position.y=1.71;rig._process(.02)
	check(rig.command(32).jump,"Physical headset jump reaches the input command")
	rig.head.position.y=1.65
	var saved_avatar=actor.avatar;actor.avatar=null
	game.avatars.choices[1]={"hash":hash};game.players[1].xr=rig.sample_pose()
	var profile:Dictionary=library.entries[hash].reach_profile
	var expected:Transform3D=preload("res://deathmatch/avatars/controller_arms.gd").weapon_pose(profile,game.players[1].xr)
	check(game._weapon_transform(1).origin.distance_to((Transform3D(Basis(Vector3.UP,game.players[1].yaw),actor.position)*expected).origin)<.00001,"Dedicated server clamps tracked muzzle to native arm length without GPU avatars")
	actor.avatar=saved_avatar
	game.battery_tanks.configure();game.battery_tanks.rows[0].pilot=1;game.battery_tanks.rows[0].life=game.players[1].serial;game.battery_tanks.seat(1,0)
	bindings.inputs={};game.voice.set_radio(false)
	check(game.voice.team_channel() and not game.voice.push_to_talk(),"Driver defaults to team radio without opening microphone")
	bindings.inputs={"ptt":true};check(game.voice.team_channel() and game.voice.push_to_talk(),"Driver ordinary PTT transmits on radio")
	game.voice.mode=0;check(not game.voice.team_channel(),"Driver radio respects microphone off")
	game.voice.mode=1;game.battery_tanks.leave(1,true);bindings.inputs={}
	check(not game.voice.team_channel(),"Dismount restores proximity channel")
	print("CQ_AVATAR_MOUNTS_RESULT ",JSON.stringify(failures));game.disconnect_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
