extends "res://deathmatch/tests/cs16_vr_reload.gd"
const Aim=preload("res://deathmatch/vr/aim_support.gd")
const Kick=preload("res://deathmatch/vr/weapon_kick.gd")
const Throw=preload("res://deathmatch/vr/throw_ballistics.gd")
func kick_shot(kick,slot: int,support: bool):
	kick.shot(slot,support);kick.update(.016);kick.update(.03)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("Video feedback tests",0,100,60,true,"dm","cs16");g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame;cs=g.variant_combat.cs
	for w in [1,2,5,6,7,9,10,11]:
		prepare(w);cs.state(1).clips[w]=3
		var total: Array=g.players[1].ammo.duplicate()
		step(Reload.pouch(pose).origin,false,true)
		check(cs.physical(1).ready and not cs.physical(1).mag and cs.state(1).clips[w]==1,"Tactical ejection retains exactly one chambered round: "+Models.NAMES[w])
		magazine()
		check(Reload.can_fire(cs.physical(1),w) and g.players[1].ammo==total,"Tactical insertion fires without charging or inventing ammunition: "+Models.NAMES[w])
	prepare(2);step(Reload.pouch(pose).origin,false,true)
	check(cs.shoot(1) and cs.state(1).clips[2]==0 and not cs.physical(1).ready,"The retained chamber fires once with its magazine removed")
	step(Reload.pouch(pose).origin,false,false,.5);magazine()
	check(not cs.physical(1).ready and not cs.shoot(1),"An empty chamber still requires charging after magazine insertion")
	for left in [false,true]:
		prepare(9,left);cs.shoot(1)
		var knob: Vector3=Reload.RACK_POINTS[9];var offset:=Vector3(.04,-.025,.05)
		var raised: Vector3=Reload.BOLT_PIVOT+Basis(Vector3.BACK,PI/3)*(knob-Reload.BOLT_PIVOT)
		var lowered: Vector3=Reload.BOLT_PIVOT+Basis(Vector3.BACK,deg_to_rad(28))*(knob-Reload.BOLT_PIVOT)
		step(point(knob+offset));step(point(knob+offset),true)
		step(point(raised+offset),true,false,.04);step(point(raised+offset+Vector3.BACK*.09),true,false,.04)
		step(point(lowered+offset+Vector3.BACK*.04),false,false,.06)
		check(cs.physical(1).ready and cs.physical(1).lift==0,"AWP catches a diagonal final close/lock on release with natural wrist tolerance, left="+str(left))
		for w in [1,2,10]:
			for direction in [-1,1]:
				prepare(w,left);var p: Dictionary=cs.physical(1);p.ready=false;p.locked=true
				pose.weapon.basis=Basis(Vector3.FORWARD,PI/2);pose["left" if left else "right"]=pose.weapon
				step(Reload.pouch(pose).origin)
				pose.weapon.origin.x+=direction*.045;pose["left" if left else "right"]=pose.weapon
				step(Reload.pouch(pose).origin,false,false,.04)
				check(p.ready and not p.locked,"One swift lateral stroke releases a rolled pistol, slot/side="+str([w,left,direction]))
	prepare(8);cover(1);step(point(Reload.cover_point(1)),false,true);magazine()
	step(point(Reload.BELT_PICKUP));step(point(Reload.BELT_PICKUP),true)
	step(point(Reload.BELT_TRAY+Vector3(.10,.02,0)),false,false,.08,false,Basis(Vector3.RIGHT,PI))
	check(cs.physical(1).belt and cs.physical(1).carry==0,"M249 leader sticks in the tray on a rotated-hand release")
	step(Reload.pouch(pose).origin,true,false,.2);step(Reload.pouch(pose).origin)
	check(cs.physical(1).belt,"Moving away and releasing cannot pull a seated belt back out")
	cover(0);cycle();check(Reload.can_fire(cs.physical(1),8),"Latched belt permits cover closure, charging and firing")
	prepare(6);step(point(Models.support(6)),true);check(cs.supported(1),"Authority acquires the actual handguard")
	step(Reload.pouch(pose).origin,true)
	check(cs.supported(1),"Authority keeps acquired support while grip remains held")
	step(Reload.pouch(pose).origin);step(Reload.pouch(pose).origin,true)
	check(not cs.supported(1),"Release clears support; distant re-grab cannot claim it")
	for w in [3,4,5,6,7,8,9,11]:
		var solver:=Aim.new();var primary:=Transform3D.IDENTITY
		var hand:=Transform3D(Basis.IDENTITY,(Models.support(w)-Models.grip(w))*.65)
		solver.solve(primary,hand,w,true,true,"cs16")
		primary.basis=Basis(Vector3.RIGHT,.4);hand.origin+=Vector3(.12,.12,.1)
		solver.solve(primary,hand,w,true,true,"cs16")
		check(solver.engaged,"Recoil/wrist drift does not break held support: "+Models.NAMES[w])
		solver.solve(primary,hand,w,false,true,"cs16");check(not solver.engaged,"Grip release detaches support")
		for left in [true,false]:
			var snap:=Models.support_pose(Transform3D.IDENTITY,w,left)
			var palm: Basis=snap.basis*preload("res://deathmatch/avatars/pose.gd").controller_hand_basis(left)
			check(palm.z.dot(Vector3.UP)>.999 and snap.origin==Models.support(w),"Snapped palm faces the underside of the handguard")
	var kick:=Kick.new();kick_shot(kick,6,true);var supported_pitch:=kick.pitch
	var kicked:=kick.apply(Transform3D.IDENTITY)
	check(kicked.origin.z>0 and -kicked.basis.z.y>0,"Recoil visibly kicks the rendered gun backward and upward")
	kick.reset();kick_shot(kick,6,false);check(kick.pitch>supported_pitch,"One-handed visual recoil is stronger")
	kick.update(.5);check(kick.pitch<.001 and kick.back<.001,"Visual recoil settles promptly")
	var ammo:=Models.ammo_pose(Transform3D.IDENTITY,6,true)
	check(ammo.basis.y.normalized().dot(Vector3.FORWARD)>.999,"Magazine feed end points toward the thumb, not the old reversed axis")
	pose=Poses.neutral();pose.weapon.basis=Basis(Vector3.UP,PI/2)
	var launch:=Throw.guided(pose,Vector3(0,0,-3))
	check(launch.normalized().dot(Vector3.LEFT)>.999 and is_equal_approx(launch.length(),Throw.launch(Vector3(0,0,-3)).length()),"DE grenade free hand chooses direction while swing chooses power")
	check(Throw.guided(pose,Vector3.DOWN*.2).is_equal_approx(Vector3.DOWN*.2),"Gentle grenade drops remain physical")
	for left in [false,true]:
		for direction in [Vector3.DOWN,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD]:
			prepare(5,left);var mp: Dictionary=cs.physical(1);mp.ready=false;mp.hk_locked=true;mp.lift=1.0;mp.stroke=1.0
			var hk: Vector3=Reload.rack_point(5,mp)
			var offset:=Vector3(0,.0,.22) if absf(direction.x)>.5 else Vector3(.22,0,0)
			step(point(hk+offset-direction*.12));step(point(hk+offset+direction*.08),false,false,.04)
			check(mp.ready and not mp.hk_locked,"One fast palm sweep catches the MP5 latch beyond the former radius: "+str([left,direction]))
	prepare(5);var mp: Dictionary=cs.physical(1);mp.ready=false;mp.hk_locked=true;mp.lift=1.0;mp.stroke=1.0
	var hk: Vector3=Reload.rack_point(5,mp)
	step(point(hk+Vector3.UP*.12));step(point(hk+Vector3.UP*.10),false,false,.12)
	check(mp.hk_locked,"Slow near-latch movement remains harmless")
	step(point(hk+Vector3.UP*.05),false,false,.2);step(point(hk+Vector3.UP*.15),false,false,.04)
	check(mp.hk_locked,"Withdrawing an open palm does not release the latch")
	step(point(hk+Vector3.RIGHT*.65),false,false,.2);step(point(hk-Vector3.RIGHT*.65),false,false,.04)
	check(mp.hk_locked,"Controller teleport through the larger latch area is rejected")
	for w in [1,2,10]:
		prepare(w);var one: Dictionary=cs.definition(1);var scale: float=cs.recoil_scale(1)
		step(point(Models.grip(w)+Vector3.FORWARD*.07),true)
		var braced: Dictionary=cs.definition(1)
		check(scale==1.0 and one.spread==braced.spread and one.get("recoil_pitch",0)==braced.get("recoil_pitch",0),"Pistol accuracy and recoil have no unsupported-hand penalty: "+Models.NAMES[w])
		kick.reset();kick_shot(kick,w,false);var one_pitch:=kick.pitch;kick.reset();kick_shot(kick,w,true)
		check(is_equal_approx(one_pitch,kick.pitch),"Pistol visual recoil also has no extra one-hand multiplier")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/video-feedback/gestures.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_FEEDBACK_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
