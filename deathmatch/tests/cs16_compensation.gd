extends "res://deathmatch/tests/cs16_accuracy.gd"
func sequence_heat(w: int,left: bool,motion: String) -> float:
	prepare(w)
	for id in g.players:
		if id!=1:g.players[id].dead=true
	var s: Dictionary=g.players[1]
	s.vr_device=true;s.xr=Poses.neutral();s.xr.left_handed=left;s.reload_grip=true
	var primary: String="left" if left else "right"
	var other: String="right" if left else "left"
	s.xr[primary]=Transform3D(Basis.IDENTITY,Vector3(.2,1.2,-.3))
	s.xr[other]=Transform3D(Basis.IDENTITY,Vector3(.2,1.2,-.7))
	s.xr.weapon=s.xr[primary];s.xr.offhand_weapon=s.xr[other];cs.physical(1).braced=true
	seed(217)
	check(cs.definition(1).spread==0 and cs.shoot(1),"Compensation keeps accurate opening shot: "+str([w,left,motion]))
	var c: Dictionary=cs.state(1);var recoil: Vector2=c.spray_angles
	var prior_ray: Vector3=cs.spray_direction(1,cs.definition(1,g.clock+s.cooldown),0)
	g.clock+=s.cooldown;s.cooldown=0;s.last_input=g.clock
	var angles: Vector2=-recoil*(.6 if motion=="partial" else 1.5) if motion in ["counter","partial","released","stale","duplicate"] else recoil*1.5 if motion=="wrong" else Vector2.ZERO
	s.xr[other].origin=s.xr[primary].origin+Vector3(-tan(angles.y),tan(angles.x),-1).normalized()*.4
	if motion=="body":
		var move:=Transform3D(Basis(Vector3.UP,.2),Vector3(.05,0,.1))
		s.xr[primary]=move*s.xr[primary];s.xr[other]=move*s.xr[other];s.xr.weapon=move*s.xr.weapon
	if motion=="released":s.reload_grip=false
	if motion=="stale":s.last_input=g.clock-.2
	if motion=="duplicate":s.last_input=c.support_sample.stamp
	s.xr.offhand_weapon=s.xr[other]
	g.demos.events.clear();g.demos.recording=true
	var basis: Basis=g._weapon_transform(1).basis
	check(cs.shoot(1),"Follow-up accepted: "+str([w,left,motion]))
	g.demos.recording=false
	check(is_equal_approx(s.cooldown,g.armory.data(w).cycle),"Offhand correction preserves firing interval")
	for event in g.demos.events:
		if event[0]=="_impacts" and motion!="released":
			var actual: Vector3=(basis.inverse()*(event[1][1][0]-event[1][0])).normalized()
			check(actual.distance_to(prior_ray)<.00001,"Current bullet keeps the preceding visual recoil direction")
		if event[0]=="_variant_shot_fx":
			var expected: Vector3=cs.spray_direction(1,cs.definition(1,g.clock+s.cooldown),0)
			check(event[1][3].distance_to(expected)<.00001,"Visual recoil anticipates compensated next shot")
	var heat: float=c.heat
	if motion=="counter":
		# Follow the next animation's change of direction, not its absolute offset.
		angles-=c.spray_step*2.0
		s.xr[other].origin=s.xr[primary].origin+Vector3(-tan(angles.y),tan(angles.x),-1).normalized()*.4
		s.xr.offhand_weapon=s.xr[other];g.clock+=s.cooldown;s.cooldown=0;s.last_input=g.clock
		check(cs.shoot(1) and is_equal_approx(c.heat,minf(5.0,heat+g.armory.data(w).bloom*.5)),"Continued compensation follows changes in the spray direction")
	return heat
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	g.start_host("Offhand spray compensation",0,100,60,true,"dm","cs16");g.bots.free();g.bots=null
	g.set_process(false);g.set_physics_process(false);cs=g.variant_combat.cs
	await physics_frame;await physics_frame
	for w in [5,6,7,8,11]:
		for left in [false,true]:
			var base:=sequence_heat(w,left,"still")
			var full:=sequence_heat(w,left,"counter")
			var partial:=sequence_heat(w,left,"partial")
			check(is_equal_approx(base,g.armory.data(w).bloom*2),"Holding support alone preserves standard buildup")
			check(is_equal_approx(full,g.armory.data(w).bloom*1.5) and full<partial and partial<base,"Active correction proportionally slows spray buildup, capped at half the increment")
			for mode in ["wrong","body","released","stale","duplicate"]:
				check(is_equal_approx(sequence_heat(w,left,mode),base),"No compensation bonus for "+mode+" "+str([w,left]))
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/compensation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_COMPENSATION_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
