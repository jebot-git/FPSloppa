extends "res://deathmatch/tests/cs16_vr_reload.gd"
func lock_handle() -> void:
	var rack: Vector3=Reload.RACK_POINTS[5]
	step(point(rack));step(point(rack),true)
	step(point(rack+Vector3.BACK*.065),true,false,.12)
	step(point(Reload.hk_transform(1,1)*rack),true,false,.12)
func slap_handle() -> void:
	var latch:=Reload.rack_point(5,cs.physical(1))
	step(point(latch+Vector3.UP*.12),false,false,.2)
	step(point(latch+Vector3.UP*.04),false,false,.04)
	step(point(latch-Vector3.UP*.02),false,false,.04)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("DE HK reload checks",0,100,60,true,"dm","cs16");g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame;cs=g.variant_combat.cs
	g.match_mode.kind="de";g.match_mode.defusal.phase="live"
	for left in [false,true]:
		for empty in [false,true]:
			prepare(5,left)
			var p: Dictionary=cs.physical(1)
			if empty:cs.state(1).clips[5]=0;p.ready=false;p.locked=true
			var total: Array=g.players[1].ammo.duplicate()
			lock_handle()
			check(p.hk_locked and p.stroke==1 and p.lift==1 and not p.ready,"DE MP5 pulls back and locks in notch: "+str([left,empty]))
			# Once seated in the notch, the mechanical latch owns the handle.
			step(point(Reload.RACK_POINTS[5]),true,false,.12)
			check(p.hk_locked and p.stroke==1 and p.lift==1,"Latched handle stays back/up while grip is still held")
			step(point(Reload.RACK_POINTS[5]))
			check(not cs.shoot(1),"Locked action blocks firing")
			step(Reload.pouch(pose).origin,false,true,.12)
			check(not p.mag and p.hk_locked and cs.label(1).begins_with("DRAW MAGAZINE"),"After locking and ejecting, prompt requests a magazine")
			slap_handle()
			check(p.hk_locked and not p.ready,"Slap without a magazine cannot finish the reload")
			var bag:=Reload.pouch(pose).origin;step(bag);step(bag,true)
			check(p.carry==1 and cs.label(1).begins_with("INSERT MAGAZINE"),"Carried magazine prompt takes priority over slap")
			var at:=point(Reload.MAG_POINTS[5])-Models.ammo_contact(Transform3D(pose.weapon.basis*Models.ammo_basis(5).inverse(),Vector3.ZERO),5)
			step(at,true,false,.20);step(at)
			check(p.mag and p.hk_locked and not p.ready and not cs.shoot(1),"Magazine seats with handle locked; insertion alone cannot fire")
			check(cs.label(1).begins_with("SLAP COCKING HANDLE"),"Seated loaded magazine enables slap prompt")
			var row: Array=cs.row(1)
			check(row[5]&Reload.HK_LOCK and row[6]==100 and row[9]==100,"Snapshot preserves the rear raised handle during magazine swap")
			var latch:=Reload.rack_point(5,p)
			step(point(latch-Vector3.UP*.12),false,false,.2)
			step(point(latch+Vector3.UP*.03),false,false,.06)
			check(p.hk_locked,"Reaching upward from the magazine is not a slap")
			slap_handle()
			check(not p.hk_locked and p.ready and p.stroke==0 and p.lift==0,"Fresh downward slap releases and chambers")
			check(g.players[1].ammo==total and cs.state(1).clips[5]==30,"Pull-lock-insert-slap conserves ammunition")
			check(cs.shoot(1) and cs.state(1).clips[5]==29,"Completed DE sequence permits the next shot")
		prepare(5,left);var p: Dictionary=cs.physical(1);var rack: Vector3=Reload.RACK_POINTS[5]
		step(point(rack));step(point(rack),true);step(point(rack+Vector3.UP*.05),true,false,.12)
		check(not p.hk_locked,"Lifting before pulling back cannot lock")
		step(point(rack+Vector3.BACK*.065),true,false,.12)
		step(point(rack+Vector3.UP*.05),true,false,.12)
		check(not p.hk_locked,"Earlier full pull cannot authorize locking at the forward position")
		prepare(5,left);lock_handle();var hk:=Reload.rack_point(5,cs.physical(1));step(point(hk))
		step(point(hk),false,false,.2,true);step(point(hk))
		check(cs.physical(1).hk_locked and cs.physical(1).stroke==1 and cs.physical(1).lift==1,"Menu interruption preserves an already seated notch")
		prepare(5,left);step(point(rack));step(point(rack),true)
		step(point(rack+Vector3.BACK*.7+Vector3.UP*.1),true,false,.12)
		check(not cs.physical(1).hk_locked,"Tracking teleport cannot pull and lock the handle")
	var result:={"checks":checks,"failures":failures};print("CS16_HK_SLAP_RESULT ",JSON.stringify(result))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
