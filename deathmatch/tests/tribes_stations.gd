extends SceneTree
const A=preload("res://deathmatch/tribes/arsenal.gd")
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.selected_map="ctf_stonehenge";g.start_host("Stonehenge stations",0,100,30,true,"st","tribes")
	g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	await physics_frame;await physics_frame
	var rules=g.match_mode.tribes;var pads=rules.stations();var actor=g.fighters[1];var s: Dictionary=g.players[1]
	check(rules.base_ctf() and pads.rows.size()==4,"BSP imports four usable CTF inventory stations")
	check(pads.get_children().filter(func(n):return n is StaticBody3D and str(n.name).begins_with("Boundary")).size()==6,"Six invisible solid boundary slabs loaded on production map")
	var nav: NavigationMesh=load("res://maps/navigation/ctf_stonehenge.res")
	check(Array(nav.get_vertices()).all(func(p):return absf(p.x)<=350.01 and absf(p.z)<=350.01),"Ground navigation stays inside the playable boundary")
	var probe:=CapsuleShape3D.new();probe.radius=.31;probe.height=1.65
	var space=g.get_world_3d().direct_space_state
	for team in [0,1]:
		s.team=team;s.dead=false;s.spectator=false
		check(g.ctf_spawns[team].size()==8,"Eight spawn points belong to team %d"%team)
		for p in g.ctf_spawns[team]:
			var q:=PhysicsShapeQueryParameters3D.new();q.shape=probe;q.transform.origin=p+Vector3.UP*.84;q.collision_mask=1
			check(space.intersect_shape(q).is_empty(),"Spawn capsule clear: team %d %s"%[team,p])
			actor.position=p;check(not rules.can_refit(1),"Spawn point is not a purchase terminal")
		for row in pads.rows:
			actor.position=row.position
			check(rules.can_refit(1)==(row.team==team),"Station access restricted to owning team %d"%team)
		var row: Dictionary=pads.rows.filter(func(r):return r.team==team)[0];actor.position=row.position
		s.dead=true;check(not rules.can_refit(1),"Dead users cannot refit");s.dead=false
		s.spectator=true;check(not rules.can_refit(1),"Spectators cannot refit");s.spectator=false
		actor.position+=Vector3.UP*5.5;check(not rules.can_refit(1),"Roof above terminal cannot access it")
		actor.position=row.position;g.headless=false;g.menu_open=false;rules.local_station=-1
		rules._process(0)
		check(is_instance_valid(rules.panel) and rules.panel.opened,"Walking onto pad opens inventory automatically")
		rules.panel.close();rules._process(0)
		check(not rules.panel.opened,"Closing inventory on pad does not immediately reopen it")
		actor.position+=Vector3(8,0,0);rules._process(0);actor.position=row.position;rules._process(0)
		check(rules.panel.opened,"Re-entering pad opens inventory again")
		actor.position+=Vector3(8,0,0);rules._process(0)
		check(not rules.panel.opened,"Leaving pad closes inventory access")
		g.headless=true
		rules.reset();g._spawn(1)
		check(s.tribes_class=="light" and s.tribes_pack=="none" and s.weapon==3 and s.tribes_ammo[2]==100 and s.tribes_ammo[3]==15 and s.tribes_ammo[9]==0,"CTF spawn kit follows base Tribes equipment")
		var before: int=rules.energy[team];var other: int=rules.energy[1-team]
		g.clock+=1;check(rules.select_equipment(1,"heavy",A.defaults("heavy"),"ammo"),"Save heavy favourites away from a terminal")
		check(rules.energy[team]==before and s.tribes_class=="light","Saving favourites does not buy or heal")
		g.clock+=1;check(not rules.select_equipment(1,"heavy",A.defaults("heavy"),"ammo",true),"Server rejects remote station purchase")
		actor.position=row.position;s.hp=50;actor.tribes_state.energy=20
		var cost: int=rules.refit_cost(1,"heavy",A.defaults("heavy"),"ammo");g.clock+=1
		check(rules.select_equipment(1,"heavy",A.defaults("heavy"),"ammo",true),"Friendly pad equips a paid heavy loadout")
		check(rules.energy[team]==before-cost and rules.energy[1-team]==other,"Only own team pays the trade-in difference")
		check(s.hp==100 and actor.tribes_state.energy==20 and s.tribes_class=="heavy","Refit preserves damage ratio and jet charge")
		check(s.starting_weapons==[0,2,3,9,10,11],"Purchased guns do not become protected starting weapons")
		check(rules.refit_cost(1,"heavy",A.defaults("heavy"),"ammo")==0,"Repeating an unchanged loadout does not charge twice")
		check(not rules.select_equipment(1,"heavy",A.defaults("heavy"),"ammo",true),"Duplicate requests throttled")
		s.tribes_ammo[2]-=20;s.tribes_ammo[3]-=2;before=rules.energy[team]
		pads.tick(rules,.5)
		check(s.tribes_ammo[2]==350 and s.tribes_ammo[3]==30 and rules.energy[team]==before-24 and s.hp==104,"Station services ammunition at item prices and gradually repairs armour")
		var cheaper: int=rules.refit_cost(1,"light",[0],"none");before=rules.energy[team];g.clock+=1
		check(cheaper<0 and rules.select_equipment(1,"light",[0],"none",true) and rules.energy[team]==before-cheaper,"Trading down returns equipment value to the same team")
		rules.energy[team]=0;g.clock+=1
		var hp: int=s.hp;var owned: Array=s.owned.duplicate()
		check(not rules.select_equipment(1,"heavy",A.defaults("heavy"),"ammo",true) and s.hp==hp and s.owned==owned,"Unaffordable refit leaves inventory and health intact")
		g._spawn(1)
		check(s.tribes_class=="light" and s.tribes_next=="heavy" and rules.energy[team]==0 and rules.carried_value(1)==0,"Empty reserve still permits Light respawn without free trade-in credit")
		rules.tick(29.9);check(rules.energy[team]==0,"No early team energy regeneration")
		rules.tick(.1);check(rules.energy[team]==700,"Reserve replenishes 700 each thirty seconds")
		check(g.ctf_spawns[team].any(func(p):return actor.position.distance_to(p)<.1),"Respawn uses own team's drop points")
	# The boundary uses real swept character collision, at both normal and very
	# fast ski/jet speeds and at corner/ceiling junctions.
	for start in [Vector3(349,230,0),Vector3(-349,230,0),Vector3(0,230,349),Vector3(0,230,-349),Vector3(349,230,349),Vector3(0,318,0)]:
		for speed in [30.,100.,200.]:
			actor.position=start;actor.velocity=(Vector3.UP if start.y>300 else Vector3(start.x,0,start.z).normalized())*speed
			actor.reset_tribes();actor.ski_held=true
			for i in 90:actor.simulate(Vector2.ZERO,0,false,1.0/60)
			check(absf(actor.position.x)<350 and absf(actor.position.z)<350 and actor.position.y+actor.collision_height<=320.02,"Boundary retains character at %s / %d m/s"%[start,speed])
	# Six simultaneous team members receive six initial contributions only;
	# repeated spawns/team changes never add another contribution for that slot.
	rules.reset();s.team=0
	for id in range(21,26):g._add_player(id,"Teammate");g.players[id].team=0
	g._spawn(1);var funded: int=rules.funded_slots[0]
	check(funded==6 and rules.energy[0]==30000-700,"Six-player team receives six initial energy contributions")
	var positions: Array=[]
	for id in [1,21,22,23,24,25]:
		g._spawn(id);positions.append(g.fighters[id].position)
	check(positions.all(func(p):return positions.count(p)==1),"Six simultaneous team spawns use distinct clear points")
	check(rules.funded_slots[0]==funded,"Respawns cannot mint joining energy")
	for id in range(21,26):g._peer_left(id)
	var reserve: int=rules.energy[0]
	g._add_player(45,"Replacement");g.players[45].team=0;g._spawn(45)
	check(rules.energy[0]==reserve-700 and rules.funded_slots[0]==6,"Reconnecting into a previously funded slot adds no energy")
	g._peer_left(45)
	# Repeat the simultaneous drop for the opposite team.
	s.team=1
	for id in range(31,36):g._add_player(id,"Blue teammate");g.players[id].team=1
	positions.clear()
	for id in [1,31,32,33,34,35]:
		g._spawn(id);positions.append(g.fighters[id].position)
	check(positions.all(func(p):return positions.count(p)==1 and g.ctf_spawns[1].has(p)),"Six blue players spawn distinctly at blue drop points")
	for id in range(31,36):g._peer_left(id)
	var snapshot: Dictionary=rules.snapshot();check(rules.valid_snapshot(snapshot),"Station economy validates for network snapshots and demos")
	var bad: Dictionary=snapshot.duplicate(true);bad.players[1].paid=-1;check(not rules.valid_snapshot(bad),"Invalid trade credit rejected")
	var result:={"checks":checks,"failures":failures,"bsp_sha256":FileAccess.get_sha256("res://maps/ctf_stonehenge.bsp")}
	FileAccess.open("res://test-results/stonehenge-ctf/mechanics.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TRIBES_STATIONS ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
