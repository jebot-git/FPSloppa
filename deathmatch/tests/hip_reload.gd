extends SceneTree
const Hip=preload("res://deathmatch/vr/hip_mount.gd")
const Room=preload("res://deathmatch/vr/room_scale.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Reload=preload("res://deathmatch/counterstrike/reload_state.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Body=preload("res://deathmatch/vr/body_basis.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func tracked_pose() -> Dictionary:
	var pose:=Poses.neutral();pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.95,0))};pose.offhand_weapon=pose.left
	return pose
func offhand(pose: Dictionary,point: Vector3):
	var key: String="right" if pose.left_handed else "left"
	pose[key]=Transform3D(Basis.IDENTITY,point);pose.offhand_weapon=pose[key]
func run():
	var pose:=tracked_pose();var base:=Hip.pouch(pose)
	pose.head=Transform3D(Basis(Vector3.UP,1.4),Vector3(0,1.15,-.8))
	check(not Poses.validate(pose).is_empty(),"A bounded 80 cm lean is valid with a tracked pelvis")
	check(Hip.pouch(pose).is_equal_approx(base) and Room.pose_request(pose)==Vector3.ZERO,"Head yaw and lean do not move the hip attachment or capsule")
	pose.body.hips.basis=Basis.from_euler(Vector3(.4,.65,.2))
	check(Hip.frame(pose).basis.y.is_equal_approx(Vector3.UP) and not Hip.pouch(pose).is_equal_approx(base),"Hip yaw turns the pouch while pelvic tilt leaves its belt frame upright")
	pose=tracked_pose();pose.body.hips.origin.x=.3;pose.head.origin.x=-.2
	check(Room.validate(Vector3(.5,4,0),pose).is_equal_approx(Vector3(.08,0,0)) and Room.validate(Vector3(-.5,0,0),pose)==Vector3.ZERO,"Authority accepts capped hip motion and rejects head-directed or vertical requests")
	pose.body.clear()
	check(Room.pose_request(pose).x<0,"Losing hips immediately restores headset-based room movement")
	pose=tracked_pose();pose.head.origin.x=1.3
	check(Poses.validate(pose).is_empty(),"Hip tracking does not permit unbounded head offsets")
	pose=tracked_pose();pose.body.hips.origin.x=.8
	check(Poses.validate(pose).is_empty(),"Tracked hips retain the fixed room-scale displacement limit")
	for left in [false,true]:
		for yaw in [0.0,1.1]:
			pose=tracked_pose();pose.left_handed=left;pose.body.hips.basis=Basis(Vector3.UP,yaw)
			pose.weapon=Transform3D(Basis.IDENTITY,Vector3(-.3 if left else .3,1.3,-.3));pose["left" if left else "right"]=pose.weapon
			var side:=Hip.offhand_side(pose);var frame:=Hip.frame(pose)
			for point in [Vector3(side*.15,0,-.39),Vector3(side*.53,0,0),Vector3(side*.15,0,.39)]:
				var world: Vector3=frame*point;offhand(pose,world)
				var p:=Reload.make(0);p.mag=false;p.grip=false
				var valid:=Poses.validate(pose)
				Reload.sample(p,2,0,90,12,valid,true,false,1)
				check(not valid.is_empty() and p.carry==1,"Front, side and rear hip grabs work: left-handed=%s yaw=%.1f point=%s"%[left,yaw,point])
				Room.rebase_pose(pose,Vector3(-.10,0,-.10))
				Reload.sample(p,2,0,90,12,Poses.validate(pose),true,false,1.2)
				check(not p.left_pouch,"Moving the body and hand together does not count as drawing ammo")
				Room.rebase_pose(pose,Vector3(.10,0,.10))
				var socket: Vector3=Reload.model_pose(pose,2)*Reload.MAG_POINTS[2];offhand(pose,socket)
				pose["right" if left else "left"].basis=pose.weapon.basis*preload("res://deathmatch/counterstrike/models.gd").ammo_basis(2).inverse();pose.offhand_weapon=pose["right" if left else "left"]
				var clip:=Reload.sample(p,2,0,90,12,Poses.validate(pose),true,false,1.4)
				check(clip==12 and p.mag and not p.ready,"A deliberate hip-to-gun draw inserts ammo but still needs racking")
			for point in [Vector3(-side*.25,0,0),Vector3(0,0,0),Vector3(side*.2,.40,0),Vector3(side*.2,-.45,0),Vector3(side*.7,0,0)]:
				check(not Hip.recovery_contains(pose,frame*point),"Opposite hip, midline, chest, leg and out-of-reach grabs are excluded")
	pose=tracked_pose();offhand(pose,Hip.frame(pose)*Vector3(-.40,0,.15))
	var waiting:=Reload.make(0);waiting.mag=false;waiting.grip=false
	Reload.sample(waiting,2,0,90,12,Poses.validate(pose),true,false,1)
	var socket: Vector3=Reload.model_pose(pose,2)*Reload.MAG_POINTS[2]
	pose.weapon.origin+=pose.left.origin-socket;pose.right=pose.weapon
	var unchanged:=Reload.sample(waiting,2,0,90,12,Poses.validate(pose),true,false,1.5)
	check(unchanged==0 and waiting.carry==1,"Bringing the gun to a stationary hip grab cannot skip the magazine draw")
	# Exercise the actual rig, waist tracker, room-scale authority and wall fade.
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	game.set_process(false);game.set_physics_process(false)
	game.hud=load("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
	game.xr_rig=load("res://deathmatch/vr/rig.gd").new();game.add_child(game.xr_rig);game.xr_rig.setup(game,true)
	var rig=game.xr_rig;rig.set_process(false);rig.calibration_pending=false
	game._add_player(1,"Hip test");game.active=true;game.menu_open=false;game.local_yaw=0
	var actor=game.fighters[1];actor.position=Fixture.point();actor.velocity=Vector3.ZERO
	rig.origin_offset=Vector3.ZERO;rig.head.position=Vector3(0,1.65,0)
	var waist:=XRControllerTracker.new();waist.name="/user/vive_tracker_htcx/role/waist";XRServer.add_tracker(waist)
	waist.set_pose("default",Transform3D(Basis(Vector3.UP,PI),Vector3(0,.95,0)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame;await physics_frame;rig._process(0)
	check(Hip.tracked(rig.sample_pose()) and rig.tracking.sample().hips.origin.is_equal_approx(Vector3(0,.95,0)),"Waist-only Vive tracking activates without T-pose and preserves its measured position")
	var mount: Transform3D=Hip.pouch(rig.sample_pose())
	rig.head.rotation.y=1.4;rig.head.position=Vector3(0,1.15,-.8);rig._process(0)
	check(Hip.pouch(rig.sample_pose()).is_equal_approx(mount),"Live tracker attachment stays on the hip through headset yaw and lean")
	var rail:=Fixture.box(game,Fixture.point(0,-.6)+Vector3.UP*.4,Vector3(2,.8,.1))
	await physics_frame;await physics_frame
	for i in 12:
		rig._process(0);game._accept_input(1,rig.command(i));game.clock+=1.0/60;game._server_tick(1.0/60)
		await physics_frame
	rig._process(0)
	check(absf(actor.position.z-Fixture.ORIGIN.z)<.005 and not rig.blackout.visible,"Leaning over a low rail keeps the capsule at the hips without a blackout")
	var wall:=Fixture.box(game,Fixture.point(0,-.6)+Vector3.UP*1.5,Vector3(2,3,.1))
	await physics_frame;await physics_frame;rig._process(0)
	check(rig.blackout.visible and Room.head_blocked(actor,rig.sample_pose(),0),"A fast head lean through a tall wall activates head-volume protection")
	rig.head.position.z=-.45;rig._process(0)
	check(rig.blackout.visible,"Head volume catches wall contact before its center reaches the wall")
	rig.head.position.z=-.8;rig._process(0)
	var command: Dictionary=rig.command(20);command.input_blocked=false;command.fire=true;command.reload_grip=true
	game._accept_input(1,command);game.clock+=.02;game._server_tick(.02)
	check(game.players[1].input_blocked and not game.players[1].fire and not game.players[1].reload_grip,"Server blocks wall-clipped combat/reloading independently of the client's fade")
	wall.free();rail.free();rig.head.position=Vector3(0,1.65,0);rig.head.rotation=Vector3.ZERO
	waist.set_pose("default",Transform3D(Basis(Vector3.UP,PI),Vector3(.3,.95,0)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame;await physics_frame
	var start: Vector3=actor.position
	for i in range(21,51):
		rig._process(0);game._accept_input(1,rig.command(i));game.clock+=1.0/60;game._server_tick(1.0/60)
		await physics_frame
	check(absf(actor.position.x-start.x-.28)<.015,"A 30 cm tracked hip step moves the authoritative capsule once")
	var settled: Vector3=actor.position
	for i in range(51,61):
		rig._process(0);game._accept_input(1,rig.command(i));game.clock+=1.0/60;game._server_tick(1.0/60)
	check(actor.position.distance_to(settled)<.01,"Stationary hip tracking does not accumulate locomotion drift")
	waist.invalidate_pose("default");await process_frame;rig._process(0)
	check(not Hip.tracked(rig.sample_pose()) and rig.command(61).room.x<0,"Live tracker loss restores head following")
	XRServer.remove_tracker(waist);game.free()
	await process_frame
	print("HIP_RELOAD_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}));quit(0 if failures.is_empty() else 1)
