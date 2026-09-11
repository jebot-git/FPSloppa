extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Crouch=preload("res://deathmatch/vr/physical_crouch.gd")
const Swim=preload("res://deathmatch/vr/swim_strokes.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures: Array=[]
var game
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	var crouch:=Crouch.new();check(crouch.sample(1.65,true)==1.65,"Standing calibrates physical crouch")
	check(crouch.sample(1.4,true)==1.65,"Small head motion does not crouch")
	check(is_equal_approx(crouch.sample(1.0,true),1.1) and crouch.crouched,"Lowered headset requests shorter capsule")
	for i in 500:crouch.sample(1.0,true)
	check(is_equal_approx(crouch.baseline,1.65) and crouch.crouched,"Held crouch never becomes the standing baseline")
	check(crouch.sample(1.40,true)<1.65 and crouch.sample(1.50,true)==1.65,"Crouch threshold has release hysteresis")
	for i in 500:crouch.sample(1.9,true)
	check(is_equal_approx(crouch.baseline,1.65),"Physical jumps cannot raise standing calibration")
	check(crouch.sample(1.0,false)==1.65 and not crouch.crouched,"Disabled/seated/untracked crouch requests standing")
	check(crouch.sample(NAN,true)==1.65,"Invalid headset height is rejected")
	var pose:=Poses.neutral();pose.height=-5;check(Poses.validate(pose).height==.8,"Network height is bounded")
	pose.height=NAN;check(Poses.validate(pose).is_empty(),"Nonfinite crouch height invalidates pose")
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game);await physics_frame
	game.start_host("Crouch water test",0,100,60,true);game.bots.free();game.bots=null;game.set_process(false);game.set_physics_process(false)
	for id in game.players:game.fighters[id].position=Fixture.point(-12,-12)
	var actor=game.fighters[1];actor.position=Fixture.point();actor.velocity=Vector3.ZERO
	var ceiling:=Fixture.box(game,Fixture.point(0,-2)+Vector3.UP*1.5,Vector3(3,.8,2));await physics_frame
	for i in 30:await physics_frame;actor.simulate(Vector2(0,-1),0,false,1.0/60)
	check(actor.position.z>Fixture.ORIGIN.z-1,"Standing capsule cannot enter low tunnel")
	pose=Poses.neutral();pose.head.origin.y=.8;pose.height=.9;game._update_crouch(1,pose)
	check(is_equal_approx(actor.collision_height,.9) and is_equal_approx(actor.body_shape.position.y,.455),"Crouch shrinks collision from the feet upward")
	for i in 10:await physics_frame;actor.simulate(Vector2(0,-1),0,true,1.0/60)
	check(actor.position.z<Fixture.ORIGIN.z-1.2,"Physical crouch permits walking into low tunnel")
	var crouched_height: float=actor.collision_height;actor.update_height(1.65)
	check(actor.collision_height==crouched_height,"Standing cannot expand capsule through a ceiling")
	for i in 55:await physics_frame;actor.simulate(Vector2(0,-1),0,true,1.0/60)
	actor.update_height(1.65)
	check(actor.collision_height==1.65,"Standing clearance is restored after leaving tunnel")
	ceiling.queue_free();await physics_frame
	actor.position=Fixture.point();actor.velocity=Vector3.ZERO;game.players[1].yaw=0.0
	pose=Poses.neutral();pose.height=.8;game._update_crouch(1,pose)
	check(actor.collision_height==1.65,"Tall headset pose cannot spoof a tiny collider")
	game.history.clear();game.clock=1;game._record_history();actor.update_height(.9);game.clock=1.2;game._record_history()
	var start:=Fixture.point()+Vector3(0,1.4,2);var end:=Fixture.point()+Vector3(0,1.4,-2)
	check(game._trace(start,end,-1).id==0,"Crouched damage capsule no longer extends above head")
	check(game._trace(start,end,-1,.2).id==1,"Lag compensation retains the earlier standing hitbox")
	game.clock=1.3;game._record_history();actor.update_height(1.65);game.clock=1.4
	check(game._trace(start,end,-1,.15).id==0 and game._trace(start,end,-1).id==1,"Rewound crouch differs correctly from current standing hitbox")
	actor.update_height(.9);game.players[1].xr=Poses.neutral();game.players[1].xr.height=.9;game._send_snapshot()
	check(game.fighters[1].xr_pose.height==.9,"Authoritative crouch height is included in snapshots")
	game.players[1].xr.head.origin.y=.8
	game.players[1].xr.face={"look":Vector2.ZERO,"blink":Vector2.ZERO,"gaze":false,"lids":true,"expression":PackedFloat32Array([.7,0,0,0,0])}
	var demo_path: String="/tmp/fpsloppa-crouch-face-%d.fpsdemo"%Time.get_ticks_usec()
	check(game.demos.start_record(demo_path),"VR crouch and expression demo recording starts")
	game._send_snapshot();game.demos.stop_record();game.demos.input=FileAccess.open(demo_path,FileAccess.READ);game.demos.input.seek(8)
	var recorded: Dictionary=game.demos.read_frame()
	check(not recorded.is_empty(),"New VR data survives production demo frame validation")
	if not recorded.is_empty():
		var recorded_pose: Dictionary=recorded.snapshot[0][0][18]
		check(recorded_pose.height==.9 and recorded_pose.face.expression[0]>.5,"Demo preserves crouch and expression values")
		actor.update_height(1.65,true);game.demos.apply_frame(recorded,false)
		check(actor.collision_height==.9,"Demo playback restores the crouched collider")
	game.demos.input.close();game.demos.input=null
	game._spawn(1);check(actor.collision_height==1.65,"Respawn restores full collision height")
	test_stroke_directions()
	await test_shore()
	check(game.match_mode.NAMES.as=="Assault","AS display name is simply Assault")
	game.disconnect_game();game.free();print("VR_CROUCH_WATER_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
func test_stroke_directions() -> void:
	for pitch in [0.0,PI/4,-PI/4]:
		var detector:=Swim.new();var head:=Transform3D(Basis(Vector3.RIGHT,pitch),Vector3(0,1.65,0));var result:=Vector3.ZERO
		for i in 31:
			result=detector.sample(head,Vector3(-.3,1.3-i*.01,-.4),Vector3(.3,1.3,-.4),1.0/60,true)
		check(result.length()>.4 and result.normalized().distance_to(-head.basis.z)<.001,"Stroke thrust follows view pitch %.2f"%pitch)
	var actor=game.fighters[1];actor.position=Fixture.point()+Vector3.UP*5;actor.velocity=Vector3.ZERO;actor.in_water=true;actor.underwater=true;actor.water_surface=false
	for i in 60:actor.simulate(Vector2.ZERO,0,false,1.0/60,false,Vector3(0,0,-.8))
	check(actor.velocity.y< -1.9 and actor.velocity.z< -3,"Level arm strokes move forward while allowing passive sinking")
	actor.in_water=false;actor.water_surface=false;actor.water_exit_grace=0;actor.was_in_water=false;actor.velocity=Vector3.ZERO
	actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	check(actor.velocity.y<0,"Jump cannot create an unrelated midair jump")
func test_shore() -> void:
	var actor=game.fighters[1]
	var shore:=Fixture.box(game,Fixture.point(0,-11)+Vector3.UP*1.1,Vector3(3,2.2,20));await physics_frame
	var runtime=preload("res://deathmatch/maps/runtime.gd").new();game.add_child(runtime);runtime.game=game;runtime.set_physics_process(false);runtime.has_contents=true
	runtime.contents.planes.assign([Plane(Vector3.UP,Fixture.ORIGIN.y+2)]);runtime.contents.nodes.assign([Vector3i(0,-1,-2)]);runtime.contents.leaves=PackedInt32Array([-1,-3])
	var results: Array=[]
	for enabled in [false,true]:
		actor.position=Fixture.point()+Vector3.UP*.8;actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.reset_view();actor.water_jump_used=not enabled
		actor.jump_held=false;actor.jump_queued=false;var boosts:=0;var previous_boost:=0.0;var reached:=false
		for i in 120:
			await physics_frame;game.clock+=1.0/60;runtime._physics_process(1.0/60)
			actor.simulate(Vector2(0,-1),0,true,1.0/60,true)
			if actor.water_boost>previous_boost:boosts+=1
			previous_boost=actor.water_boost
			if actor.position.z<Fixture.ORIGIN.z-1.1 and actor.position.y>=Fixture.ORIGIN.y+2.18 and actor.is_supported():reached=true;break
		print("SHORE_PROBE ",enabled," ",actor.position," velocity=",actor.velocity," boosts=",boosts," used=",actor.water_jump_used)
		results.append(reached)
		if enabled:check(boosts==1,"Emerging grants exactly one surface boost with jump held")
	check(not results[0] and results[1],"One surface jump clears a shore ledge that ordinary swimming cannot reach")
	actor.in_water=true;actor.underwater=false;actor.water_surface=true;actor.water_jump_used=true;actor.water_boost=0;actor.velocity=Vector3.UP
	actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	check(actor.water_boost==0 and actor.velocity.y<7,"Surface bobbing cannot repeat an already spent boost")
	actor.in_water=true;actor.underwater=true;actor.water_surface=false;actor.water_jump_used=true;actor.position=Fixture.point(6,0)+Vector3.UP*.1;actor.velocity=Vector3.ZERO
	for i in 20:actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
	check(not actor.water_jump_used,"A fresh sustained submersion rearms the surface jump")
	actor.in_water=false;actor.underwater=false;actor.water_surface=false;actor.was_in_water=true;actor.water_jump_used=false;actor.velocity=Vector3.UP*4
	actor.simulate(Vector2.ZERO,0,false,1.0/60,true)
	check(actor.water_jump_used and actor.velocity.y>7,"Short exit grace catches crossing the surface between physics samples")
	runtime.free();shore.queue_free()
