extends "res://deathmatch/tests/cs16_vr_reload.gd"
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("Magazine pulls",0,100,60,true,"dm","cs16");g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame;cs=g.variant_combat.cs
	# Interleave fresh controller packets with duplicate server-tick samples.
	for left in [false,true]:
		for w in [5,6,7,9,11]:
			prepare(w,left);cs.state(1).clips[w]=6
			var mag: Vector3=Reload.MAG_POINTS[w];var direction:=Reload.mag_direction(w)
			step(point(mag));step(point(mag),true)
			var started: float=cs.physical(1).started
			for sample in range(1,6):
				g.clock+=.008;cs.tick_input(1,.008)
				check(cs.physical(1).started==started or not cs.physical(1).mag,"Repeated sample does not restart magazine pull")
				step(point(mag+direction*.026*sample),true,false,.012)
			check(cs.physical(1).carry==Reload.REMOVED_MAG and cs.row(1)[11]==5,"Network-rate pull exposes exact held ammo: "+str([w,left]))
			for tick in 10:g.clock+=.008;cs.tick_input(1,.008)
			check(cs.physical(1).carry==Reload.REMOVED_MAG and cs.row(1)[11]==5,"Inspection survives repeated server ticks")
	for left in [false,true]:
		for w in [5,6,7,8,9,11]:
			prepare(w,left)
			cs.state(1).clips[w]=6
			if w==8:
				step(point(Reload.MAG_POINTS[w]));step(point(Reload.MAG_POINTS[w]),true);step(point(Reload.MAG_POINTS[w]+Vector3.DOWN*.2),true)
				check(cs.physical(1).mag and cs.physical(1).carry==0,"Closed M249 cover prevents hand removal")
				cover(1)
			var at: Vector3=Reload.MAG_POINTS[w];var direction:=Reload.mag_direction(w);var total: Array=g.players[1].ammo.duplicate()
			step(point(at));step(point(at),true)
			check(cs.physical(1).grab=="magazine" and cs.physical(1).mag,"Grip catches seated magazine without ejecting: %s/%s"%[w,left])
			step(point(at+direction*.03),true)
			check(cs.physical(1).mag,"Small hand jitter leaves magazine seated")
			step(point(at-direction*.13),true)
			check(cs.physical(1).mag,"Pushing inward cannot remove magazine")
			step(point(at+direction*.13),true)
			var p: Dictionary=cs.physical(1)
			check(not p.mag and p.carry==Reload.REMOVED_MAG and cs.state(1).clips[w]==(0 if w==8 else 1),"Pull removes magazine into hand and preserves chamber: %s/%s"%[w,left])
			check(g.players[1].ammo==total,"Pull conserves shared ammunition")
			var retained:=6 if w==8 else 5
			check(p.carried_rounds==retained,"Retained magazine excludes the chambered round")
			var row: Array=cs.row(1);cs.receive({1:row})
			check(cs.view.has(1) and cs.view[1][8]==Reload.REMOVED_MAG and cs.view[1][11]==retained,"Removed magazine and exact count survive snapshot validation")
			step(point(at+direction*.13),true)
			check(not p.mag,"Holding the extracted magazine still cannot immediately reseat it")
			step(point(at),true)
			check(p.mag and p.carry==0 and p.carried_rounds==0 and cs.state(1).clips[w]==6,"Returning old magazine restores exactly its partial load")
			check(g.players[1].ammo==total and (w==8 and not p.belt or w!=8 and p.ready),"Reinsertion preserves reserve, chamber and M249 belt requirements")
			step(point(at));step(point(at),true);step(point(at+direction*.13),true,false,.08)
			check(p.carry==Reload.REMOVED_MAG and p.carried_rounds==retained,"The same magazine can be removed again without topping up")
			step(point(at))
			check(p.carry==0 and p.carried_rounds==0 and p.grab.is_empty(),"Release frees the offhand for a fresh magazine")
			magazine()
			check(p.mag and (w==8 or p.ready),"Fresh pouch magazine retains the tactical reload chamber")
	for w in [1,2,3,4,10]:
		prepare(w);var at: Vector3=Reload.MAG_POINTS[w]
		step(point(at));step(point(at),true);step(point(at+Vector3.DOWN*.18),true)
		check(cs.physical(1).mag and cs.physical(1).carry==0,"Pistols and tube shotguns do not support hand magazine removal: "+str(w))
	prepare(7);var at: Vector3=Reload.MAG_POINTS[7]
	step(point(at),true);step(point(at+Vector3.DOWN*.15),true,false,.06,true)
	check(cs.physical(1).mag,"Menu interruption cannot finish a magazine pull")
	step(point(at+Vector3.DOWN*.15),true)
	check(cs.physical(1).mag,"Input recovery needs a fresh grab")
	prepare(7);step(point(at),true);pose.weapon.origin+=Vector3.RIGHT*.3;pose.right=pose.weapon;pose.head.origin+=Vector3.RIGHT*.3
	step(point(at),true)
	check(cs.physical(1).mag,"Moving both hands and head together cannot remove magazine")
	prepare(7);step(point(at),true);step(point(at+Vector3.DOWN*.6),true)
	check(cs.physical(1).mag,"Tracking jump cannot remove magazine")
	prepare(7);step(point(at),true);step(point(at+Vector3.DOWN*.15),true,false,.25)
	check(cs.physical(1).mag,"Stale motion cannot remove magazine")
	prepare(7);cs.state(1).clips[7]=6;at=Reload.MAG_POINTS[7]
	step(point(at),true);step(point(at+Vector3.DOWN*.14),true)
	check(cs.shoot(1) and cs.state(1).clips[7]==0,"The separate chambered round can fire while the magazine is held")
	step(point(at),true)
	check(cs.state(1).clips[7]==5 and not cs.physical(1).ready,"Reinsertion after chamber firing restores five rounds and still requires racking")
	cycle();check(cs.physical(1).ready and cs.state(1).clips[7]==5,"Racking makes the retained ammunition ready without creating rounds")
	prepare(7);cs.state(1).clips[7]=0;cs.physical(1).ready=false;cs.physical(1).locked=true
	step(point(at),true);step(point(at+Vector3.DOWN*.14),true)
	check(cs.physical(1).carry==Reload.REMOVED_MAG and cs.physical(1).carried_rounds==0,"An empty removed magazine remains a real held object")
	step(point(at),true);check(cs.physical(1).mag and cs.state(1).clips[7]==0 and not cs.physical(1).ready,"Reinserting an empty magazine cannot generate ammunition")
	prepare(7);step(point(at),true);step(point(at+Vector3.DOWN*.14),true)
	var partial: Array=cs.row(1)
	for invalid in [-1,101,1.5]:
		var malformed:=partial.duplicate();malformed[11]=invalid;cs.receive({1:malformed});check(cs.view.is_empty(),"Invalid held-round count is rejected: "+str(invalid))
	step(point(at),true,false,.25);check(not cs.physical(1).mag,"Stale pose cannot reinsert a retained magazine")
	step(point(at),true,false,.06,true);check(cs.physical(1).carry==0 and cs.physical(1).carried_rounds==0,"Blocked input clears held rounds and cannot insert them")
	# Reproduce a fore-end overlapping the broad hip volume and the implicit
	# held-pump continuation path: neither is a new pouch grab.
	for left in [false,true]:
		for w in [3,4]:
			prepare(w,left);cs.state(1).clips[w]=2
			var bag: Vector3=Reload.pouch(pose).origin
			pose.weapon.origin+=bag-point(Models.support(w));pose["left" if left else "right"]=pose.weapon
			step(bag);step(bag,true)
			check(cs.physical(1).carry==0 and cs.physical(1).grab.is_empty(),"Low shotgun fore-end grip does not conjure a shell: %s/%s"%[w,left])
		prepare(3,left);cs.state(1).clips[3]=2
		step(point(Reload.RACK_POINTS[3]),true);cs.physical(1).ready=false
		step(Reload.pouch(pose).origin,true)
		check(cs.physical(1).carry==0,"Continuing an existing shotgun grip over the hip cannot draw a shell")
		step(Reload.pouch(pose).origin);step(Reload.pouch(pose).origin,true)
		check(cs.physical(1).carry==2,"A deliberate new pouch grab still supplies a shell")
		pose.pump=true
		step(point(Reload.RACK_POINTS[3]),true)
		check(cs.physical(1).pump_hold and cs.physical(1).carry==0,"Taking the pump cancels carried shell state immediately")
		pose.erase("pump");step(point(Reload.RACK_POINTS[3]))
		check(cs.physical(1).carry==0,"Taking back or releasing the shotgun cannot leave a stuck shell")
	print("CS16_MAG_PULL_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
