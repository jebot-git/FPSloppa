extends "res://deathmatch/tests/cs16_vr_reload.gd"
const PumpHold=preload("res://deathmatch/vr/pump_hold.gd")
func gun_move(offset: Vector3,dt: float=.04):
	pose.weapon.origin+=offset;pose["left" if pose.left_handed else "right"]=pose.weapon
	step(pose["right" if pose.left_handed else "left"].origin,false,false,dt)
func pump_move(offset: Vector3,dt: float=.05):
	var hand: Transform3D=pose.right if pose.left_handed else pose.left
	hand.origin+=offset
	pose.pump=true;pose.weapon=PumpHold.weapon(hand,Basis.IDENTITY,cs.physical(1).stroke)
	step(hand.origin,true,false,dt)
func run():
	DirAccess.make_dir_recursive_absolute("res://test-results/cs16/actions")
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("CS action tests",0,100,60,true,"dm","cs16");g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame;cs=g.variant_combat.cs
	for left in [false,true]:
		prepare(6,left);cs.state(1).clips[6]=10;var total: Array=g.players[1].ammo.duplicate()
		var bag:=Reload.pouch(pose).origin;step(bag);step(bag,true)
		check(cs.physical(1).carry==1 and cs.physical(1).mag,"AK draws a replacement while the old magazine is seated, handed="+str(left))
		step(point(Reload.AK_RELEASE+Vector3.BACK*.17),true,false,.2)
		step(point(Reload.AK_RELEASE+Vector3.BACK*.10),true,false,.2);step(point(Reload.AK_RELEASE+Vector3.BACK*.03),true,false,.2)
		check(cs.physical(1).mag,"Slow magazine contact cannot knock out the AK magazine")
		step(point(Reload.AK_RELEASE+Vector3.BACK*.17),true,false,.2)
		step(point(Reload.AK_RELEASE+Vector3.BACK*.10),true,false,.04);step(point(Reload.AK_RELEASE+Vector3.BACK*.03),true,false,.04)
		check(not cs.physical(1).mag and cs.physical(1).carry==1 and cs.state(1).clips[6]==1,"AK bump ejects only the old magazine and keeps the replacement")
		step(point(Reload.MAG_POINTS[6]),true,false,.2);step(point(Reload.MAG_POINTS[6]));cycle()
		check(cs.physical(1).ready and g.players[1].ammo==total,"AK bump, insertion and rack preserve total ammunition")
		prepare(5,left);step(Reload.pouch(pose).origin,false,true);magazine()
		var rack: Vector3=Reload.RACK_POINTS[5]
		step(point(rack));step(point(rack),true);step(point(rack+Vector3.BACK*.065),true,false,.12)
		step(point(rack+Vector3.BACK*.065+Vector3.UP*.055),true,false,.12);step(point(rack+Vector3.BACK*.065+Vector3.UP*.055))
		check(cs.physical(1).hk_locked and cs.physical(1).stroke==1 and not cs.physical(1).ready,"MP5 charging handle stays in its raised rear notch")
		var latch:=Reload.rack_point(5,cs.physical(1))
		step(point(latch+Vector3.UP*.10),false,false,.2);step(point(latch+Vector3.UP*.04),false,false,.2);step(point(latch),false,false,.2)
		check(cs.physical(1).hk_locked,"Touching or slowly lowering the hand does not HK-slap")
		step(point(latch+Vector3.UP*.10),false,false,.2)
		step(point(latch+Vector3.UP*.04),false,false,.04);step(point(latch-Vector3.UP*.02),false,false,.04)
		check(not cs.physical(1).hk_locked and cs.physical(1).ready,"Fast open-hand downward slap releases the MP5 handle")
		prepare(9,left);cs.shoot(1);var handle: Vector3=Reload.RACK_POINTS[9]
		step(point(handle));step(point(handle),true);step(point(handle+Vector3.BACK*.10),true,false,.2)
		check(cs.physical(1).stroke==0 and not cs.physical(1).ready,"AWP cannot pull a locked bolt straight back")
		step(point(handle));step(point(handle),true)
		var up: Vector3=Reload.BOLT_PIVOT+Basis(Vector3.BACK,PI/3)*(handle-Reload.BOLT_PIVOT)
		step(point(up),true,false,.12)
		check(cs.physical(1).lift>.9 and cs.physical(1).stroke==0,"AWP first raises its handle without retracting")
		step(point(up+Vector3.BACK*.10),true,false,.12)
		check(cs.physical(1).stroke>.9 and not cs.physical(1).ready,"AWP then retracts while unlocked")
		step(point(handle+Vector3.BACK*.10),true,false,.12)
		check(cs.physical(1).lift>.9 and cs.physical(1).stroke>.9,"AWP cannot lock while the bolt is back")
		step(point(up),true,false,.12)
		check(cs.physical(1).stroke==0 and cs.physical(1).lift>.9 and not cs.physical(1).ready,"AWP closes but cannot fire until locked")
		step(point(handle),true,false,.12);step(point(handle))
		check(cs.physical(1).ready and cs.physical(1).lift==0,"AWP lowering the handle locks and chambers")
		for pistol in [1,2,10]:
			prepare(pistol,left);cs.state(1).clips[pistol]=1;cs.shoot(1)
			step(Reload.pouch(pose).origin,false,true);magazine()
			var total_before: Array=g.players[1].ammo.duplicate()
			gun_move(Vector3.RIGHT*.025,.10);gun_move(Vector3.RIGHT*.025,.10)
			check(cs.physical(1).locked,"Slow pistol movement keeps the slide locked")
			gun_move(Vector3.FORWARD*.06);gun_move(Vector3.FORWARD*.06)
			check(cs.physical(1).locked,"Forward movement does not count as a sideways slide flick")
			gun_move(Vector3.RIGHT*.06);gun_move(Vector3.RIGHT*.06)
			check(cs.physical(1).ready and not cs.physical(1).locked and g.players[1].ammo==total_before,"Locked pistol side flick chambers without adding ammunition")
		prepare(3,left);cs.shoot(1);var pump: Vector3=point(Reload.RACK_POINTS[3])
		step(pump);step(pump,true);pump_move(Vector3.ZERO)
		check(cs.physical(1).pump_hold and not g.players[1].xr.is_empty(),"M3 offhand pump ownership passes authoritative pose validation")
		pump_move(Vector3.BACK*.02,.1);pump_move(Vector3.BACK*.02,.1)
		check(not cs.physical(1).ready and cs.physical(1).stroke==0,"Slow offhand movement does not cycle the pump")
		pump_move(Vector3.BACK*.07);pump_move(Vector3.BACK*.07)
		check(cs.physical(1).stroke==1 and not cs.physical(1).ready,"Fast first swing opens the pump but does not chamber")
		pump_move(Vector3.FORWARD*.07);pump_move(Vector3.FORWARD*.07)
		check(cs.physical(1).ready and cs.physical(1).pump_hold and not Reload.can_fire(cs.physical(1),3),"Return swing closes the pump; offhand-only hold cannot fire")
		pose.erase("pump");pose.weapon=pose.left if left else pose.right;step(pump,true,true)
		check(not cs.physical(1).pump_hold and Reload.can_fire(cs.physical(1),3),"Weapon-hand grip takes back the cycled shotgun")
	prepare(8);var total: Array=g.players[1].ammo.duplicate();cover(1)
	step(point(Reload.cover_point(1)),false,true);magazine();cover(0)
	check(cs.physical(1).cover>.8 and not cs.physical(1).belt and not cs.physical(1).ready,"M249 cannot close a loaded box without laying its belt")
	step(point(Reload.BELT_PICKUP));step(point(Reload.BELT_PICKUP),true)
	check(cs.physical(1).carry==3,"M249 grabs its attached belt, not another ammo box")
	step(point(Reload.BELT_PICKUP));check(not cs.physical(1).belt,"Dropping the belt outside the tray does not seat it")
	step(point(Reload.BELT_PICKUP),true);step(point(Reload.BELT_TRAY),true,false,.2);step(point(Reload.BELT_TRAY))
	check(cs.physical(1).belt and not cs.physical(1).ready,"M249 belt placement still requires closing and charging")
	cover(0);cycle();check(cs.physical(1).ready and g.players[1].ammo==total,"M249 box, belt, cover and charging sequence preserves ammo")
	# Invalid snapshot extensions cannot drive remote weapon presentation.
	var row: Array=cs.row(1);cs.receive({1:row});check(cs.view.has(1),"Extended mechanism state survives snapshot validation")
	for field in [9,10]:
		var bad:=row.duplicate();bad[field]=101;cs.receive({1:bad});check(cs.view.is_empty(),"Snapshot rejects invalid mechanism progress "+str(field))
	prepare(7);pose.pump=true;step(Reload.pouch(pose).origin,true)
	check(g.players[1].xr.is_empty(),"Other weapons cannot claim an offhand pump pose")
	prepare(2);cs.physical(1).locked=true;cs.physical(1).ready=false
	pose.head.origin.x+=.08;step(pose.left.origin,false,false,.04);pose.head.origin.x+=.08;step(pose.left.origin,false,false,.04)
	check(cs.physical(1).locked,"Fast head motion alone cannot release a pistol slide")
	for i in 2:
		for key in ["head","left","right","weapon"]:pose[key].origin.x+=.08
		step(pose.left.origin,false,false,.04)
	check(cs.physical(1).locked,"Common body translation cannot release the slide")
	prepare(2);cs.physical(1).locked=true;cs.physical(1).ready=false
	gun_move(Vector3.RIGHT*.4);gun_move(Vector3.RIGHT*.4)
	check(cs.physical(1).locked,"Controller teleports cannot count as a pistol flick")
	prepare(2);cs.physical(1).locked=true;cs.physical(1).ready=false
	pose.weapon.origin.x+=.06;pose.right=pose.weapon
	step(pose.left.origin,false,false,.04,true);step(pose.left.origin)
	check(cs.physical(1).locked,"A menu movement cannot release the slide when play resumes")
	prepare(2);cs.physical(1).locked=true;cs.physical(1).ready=false
	pose.erase("offhand_weapon");g.players[1].xr=Poses.validate(pose)
	for i in 3:
		g.clock+=.04;pose.weapon.origin.x+=.06;pose.right=pose.weapon;g.players[1].last_input=g.clock;g.players[1].xr=Poses.validate(pose);cs.tick_input(1,.04)
	check(cs.physical(1).ready,"A pistol flick needs only the tracked weapon hand")
	prepare(2);cs.physical(1).ready=false;step(Reload.pouch(pose).origin,false,true);cs.physical(1).locked=true
	gun_move(Vector3.RIGHT*.06);gun_move(Vector3.RIGHT*.06)
	check(not cs.physical(1).ready and cs.state(1).clips[2]==0,"Side flick cannot chamber an absent magazine")
	prepare(3);cs.shoot(1);step(point(Reload.RACK_POINTS[3]));step(point(Reload.RACK_POINTS[3]),true);pump_move(Vector3.ZERO)
	pump_move(Vector3.BACK*.07);pump_move(Vector3.BACK*.07)
	step(pose.left.origin,true,false,.2,true)
	check(not cs.physical(1).ready and not cs.physical(1).pump_hold,"Menu interruption cannot finish an open swing pump")
	prepare(3);pose.pump=true;pose.weapon=PumpHold.weapon(pose.left,Basis.IDENTITY,0);step(pose.left.origin,true)
	check(not cs.shoot(1),"Claiming a pump pose cannot fire a loaded gun from the offhand")
	prepare(9);cs.shoot(1)
	var bolt_up: Vector3=Reload.BOLT_PIVOT+Basis(Vector3.BACK,PI/3)*(Reload.RACK_POINTS[9]-Reload.BOLT_PIVOT)
	step(point(Reload.RACK_POINTS[9]));step(point(Reload.RACK_POINTS[9]),true);step(point(bolt_up),true,false,.12);step(point(bolt_up+Vector3.BACK*.1),true,false,.12)
	step(point(Reload.RACK_POINTS[9]),true,false,.2,true)
	check(not cs.physical(1).ready and cs.physical(1).stroke>.9 and cs.physical(1).lift>.9,"Interrupted AWP keeps the real open bolt position and cannot chamber")
	step(point(Reload.RACK_POINTS[9]),true,false,.2)
	check(not cs.physical(1).ready,"Tracking recovery with grip held cannot skip AWP close and lock")
	prepare(9);cs.shoot(1)
	var offset:=Vector3(.03,-.025,.08)
	var knob: Vector3=Reload.RACK_POINTS[9]
	var lifted: Vector3=Reload.BOLT_PIVOT+Basis(Vector3.BACK,PI/3)*(knob-Reload.BOLT_PIVOT)
	step(point(knob+offset));step(point(knob+offset),true)
	step(point(lifted+offset+Vector3.BACK*.04),true,false,.04)
	step(point(lifted+offset+Vector3.BACK*.10),true,false,.04)
	step(point(knob+offset),true,false,.07)
	check(cs.physical(1).ready,"Continuous AWP raise/pull/close/lock accepts an off-centre palm without re-grabbing")
	prepare(5);var mp: Dictionary=cs.physical(1);mp.ready=false;mp.hk_locked=true;mp.lift=1.0;mp.stroke=1.0
	var hk: Vector3=Reload.rack_point(5,mp)
	step(point(hk));step(point(hk),true);step(point(hk+Vector3.BACK*.05),true,false,.12);step(point(hk+Vector3.BACK*.05))
	check(mp.ready and not mp.hk_locked,"Pulling and releasing the latched MP5 handle works without an HK slap")
	prepare(6);cs.state(1).heat=2;cs.state(1).shot_at=g.clock
	var unsupported: Dictionary=cs.definition(1)
	step(point(Models.support(6)),true)
	var braced: Dictionary=cs.definition(1)
	check(cs.supported(1) and unsupported.recoil_pitch>braced.recoil_pitch and unsupported.spread>braced.spread,"One-handed rifle firing has more recoil and spread than a held handguard")
	step(Reload.pouch(pose).origin);step(Reload.pouch(pose).origin,true)
	check(not cs.supported(1),"Holding the offhand away from the gun cannot claim recoil support")
	for w in [1,2,10,3,4,5,6,7,8,9,11]:
		prepare(w)
		check(is_equal_approx(cs.recoil_scale(1),1.0 if w in [1,2,10] else 2.0),"CS hand penalty applies to long guns only: "+Models.NAMES[w])
		var support_point: Vector3=Models.grip(w)+Vector3(0,0,-.07) if w in [1,2,10] else Models.support(w)
		step(point(support_point),true)
		check(cs.supported(1) and cs.recoil_scale(1)==1.0 and Reload.can_fire(cs.physical(1),w),"Bracing the loaded "+Models.NAMES[w]+" permits firing without grabbing a neighboring action")
		g.players[1].vr_device=false
		check(cs.recoil_scale(1)==1.0 and not cs.definition(1).has("recoil_pitch"),"Desktop CS keeps its existing recoil: "+Models.NAMES[w])
	for mode in ["dm","tf","tb","as","ig","if","cc"]:
		for rules in ["doom","quake","ut99"]:
			g.match_mode.kind=mode;g.armory.select(rules);cs.reset()
			g.players[1].vr_device=true;g.players[1].reload_grip=false
			check(cs.recoil_scale(1)==1.0 and cs.states.is_empty(),"No CS hand penalty/state in "+mode+" / "+g.armory.effective())
			check(not g.variant_combat.fire(1,false,0.0,true),"CS firing path rejects other effective loadouts")
	g.match_mode.kind="dm";g.armory.select("cs16")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/actions/gestures.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_ACTIONS_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
