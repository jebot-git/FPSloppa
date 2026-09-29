extends "res://deathmatch/tests/cs16.gd"
class CaptureVisuals extends Node3D:
	var start: Vector3
	var ends: PackedVector3Array
	func impacts(_rules: String,at: Vector3,targets: PackedVector3Array,_weapon: int,_definition: Dictionary={},_light: bool=true):start=at;ends=targets
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	g.start_host("Local tracer origins",0,100,60,true,"dm","cs16");g.bots.free();g.bots=null
	g.set_process(false);g.set_physics_process(false);cs=g.variant_combat.cs
	if not is_instance_valid(g.hud):g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.xr_rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(g.xr_rig);g.xr_rig.setup(g,true)
	var rig=g.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false
	await physics_frame;await physics_frame
	var capture:=CaptureVisuals.new();g.add_child(capture);g.variant_visuals=capture
	g.menu_open=false;g.headless=false
	var ends:=PackedVector3Array([Fixture.point(0,-20)+Vector3.UP])
	for left in [false,true]:
		rig.left_handed=left
		for w in range(1,12):
			reset(w);g.desired_weapon=w;rig.weapon_kick.reset();rig.gun_id=-1
			rig.head.position=Vector3(0,1.65,0)
			var grip=rig.left if left else rig.right
			var aim=rig.left_aim if left else rig.right_aim
			grip.transform=Transform3D(Basis(Vector3.RIGHT,.12),Vector3(.2,1.3,-.4));aim.transform=grip.transform
			rig._process(.016);rig.weapon_kick.shot(w,true,Vector3(.03,.04,-1).normalized());rig._process(.016);rig._process(.03)
			# Delayed network origin and an extra grip update simulate hand motion
			# between authority sampling and local display.
			var server_start: Vector3=g._shot_solution(1).origin
			grip.position+=Vector3(.14,.03,.1)
			var muzzle: Vector3=rig.gun.to_global(rig.gun.get_meta("muzzle"))
			g._impacts(server_start,ends,w,PackedVector3Array(),-1,1)
			check(capture.start.is_equal_approx(muzzle) and capture.start.distance_to(server_start)>.05,"Local tracer uses displayed barrel during recoil and motion: "+str([w,left]))
			check(capture.ends==ends,"Local muzzle adjustment preserves authoritative impacts")
			if w in [2,7]:
				preload("res://deathmatch/counterstrike/models.gd").presentation(rig.gun,true)
				g._impacts(server_start,ends,w,PackedVector3Array(),-1,1)
				check(capture.start.is_equal_approx(muzzle+rig.gun.global_basis*Vector3.FORWARD*.186),"Suppressed tracer starts at the suppressor cap")
				preload("res://deathmatch/counterstrike/models.gd").presentation(rig.gun,false)

			g._impacts(server_start,ends,w,PackedVector3Array(),-1,-1)
			check(capture.start==server_start,"Other players' shots retain their own origin")
			g._impacts(server_start,ends,w)
			check(capture.start==server_start,"Legacy ownerless effects cannot attach to the local gun")
			g.demos.playing=true;g._impacts(server_start,ends,w,PackedVector3Array(),-1,1);g.demos.playing=false
			check(capture.start==server_start,"Replay uses the recorded origin")
	rig.enabled=false;g.players[1].weapon=6;g.model_weapon=6
	g.viewmodel=g.Art.weapon(6,2,"cs16");g.add_child(g.viewmodel);g.viewmodel.transform=Transform3D(Basis(Vector3.UP,.3).scaled(Vector3.ONE*.72),Fixture.point()+Vector3(.2,1.3,-.4))
	g._impacts(Vector3.ZERO,ends,6,PackedVector3Array(),-1,1)
	check(capture.start.is_equal_approx(g.viewmodel.to_global(g.viewmodel.get_meta("muzzle"))),"Desktop tracer uses the visible viewmodel barrel")
	g.viewmodel.hide();g._impacts(Vector3.ONE,ends,6,PackedVector3Array(),-1,1)
	check(capture.start==Vector3.ONE,"Hidden local model falls back to authoritative origin")
	g.headless=true
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/local-tracers.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_LOCAL_TRACERS_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
