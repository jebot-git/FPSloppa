extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var g
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func _initialize():call_deferred("run")
func reset():
	g.clock+=2;g.intermission=0
	for id in g.players:
		var s: Dictionary=g.players[id]
		s.hp=1000;s.armor=0;s.dead=false;s.invulnerable=0;s.weapon=2;s.owned=range(9);s.ammo=[50,50,50,50]
		s.cooldown=0;s.offhand_cooldown=0;s.fire=false;s.offhand_fire=false;s.held=false;s.offhand_held=false;s.charge=0
		s.xr={};s.vr_device=false;s.last_input=g.clock;s.yaw=0;s.pitch=0;s.melee=false
	g.fighters[1].position=Fixture.point();g.fighters[-1].position=Fixture.point(0,-2.7);g.fighters[-2].position=Fixture.point(4,-2.7)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	await physics_frame
	g.start_host("Dual test",0,100,60,true);g.bots.free();g.bots=null;g.set_physics_process(false)
	await physics_frame
	await physics_frame
	reset()
	g._fire(1);g._fire(1,true)
	check(g.players[1].ammo[0]==48 and g.players[-1].hp<=988 and g.players[-1].hp>=964,"Both pistols fire independently with 6–18 damage and shared bullets")
	g._fire(1);g._fire(1,true)
	check(g.players[1].ammo[0]==48,"Repeated commands cannot bypass either pistol cooldown")
	g._server_tick(.4);g._fire(1,true)
	check(g.players[1].ammo[0]==47,"Offhand fires again after its own 0.4 second cycle")
	reset();g.players[1].ammo[0]=1;g.players[1].owned=[2];g._fire(1);g._fire(1,true)
	check(g.players[1].ammo[0]==0 and g.players[-1].hp>=982,"Simultaneous fire with one bullet produces only one shot")
	reset();g.players[1].weapon=3;g._fire(1,true)
	check(g.players[1].ammo[1]==50 and g.players[-1].hp==1000,"Offhand input cannot fire other weapons")
	reset();g.players[1].vr_device=true;g.players[1].xr=Poses.neutral();g._fire(1,true)
	check(g.players[1].ammo[0]==50,"Missing offhand tracking cannot fire a VR pistol")
	for left_handed in [false,true]:
		reset()
		var pose:=Poses.neutral();pose.left_handed=left_handed
		var main_key:="left" if left_handed else "right"
		var other_key:="right" if left_handed else "left"
		pose.weapon=Transform3D(Basis.IDENTITY,pose[main_key].origin)
		var toward:Vector3=g.fighters[-2].position+Vector3.UP*1.1-g.fighters[1].position-pose[other_key].origin
		pose.offhand_weapon=Transform3D(Basis.looking_at(toward),pose[other_key].origin)
		check(not Poses.validate(pose).is_empty(),"Valid independent aim accepted for handedness "+str(left_handed))
		g.players[1].vr_device=true;g.players[1].xr=pose
		g._fire(1);g._fire(1,true)
		check(g.players[-1].hp<1000 and g.players[-2].hp<1000,"Separate VR pistols hit separate targets for handedness "+str(left_handed))
		var bad:=pose.duplicate(true);bad.offhand_weapon.origin=Vector3(5,1,0)
		check(Poses.validate(bad).is_empty(),"Forged offhand reach is rejected")
		var shifted:=pose.duplicate(true)
		preload("res://deathmatch/vr/room_scale.gd").rebase_pose(shifted,Vector3(.1,0,0))
		check(shifted.offhand_weapon.origin.is_equal_approx(pose.offhand_weapon.origin-Vector3(.1,0,0)),"Room-scale rebasing preserves offhand aim and grip alignment")
	reset()
	g.players[1].fire=true;g.players[1].offhand_fire=true
	for i in range(100): g.players[1].last_input=g.clock;g._server_tick(.01)
	check(g.players[1].ammo[0]==44,"Holding both triggers produces three shots per gun in one second")
	var lib=load("res://deathmatch/avatars/library.gd").new();root.add_child(lib)
	var avatar=lib.create_avatar(lib.entries.keys()[0]);root.add_child(avatar)
	avatar.set_weapon(2)
	check(is_instance_valid(avatar.offhand_gun),"Remote avatar displays two pistols")
	avatar.set_weapon(3)
	check(not is_instance_valid(avatar.offhand_gun),"Switching weapon removes secondary pistol model")
	avatar.free();lib.free()
	print("DUAL_PISTOLS_RESULT ",JSON.stringify(failures));g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
