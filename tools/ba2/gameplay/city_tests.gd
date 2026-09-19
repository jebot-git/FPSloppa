extends SceneTree
const Fixture=preload("res://tools/ba2/gameplay/fixture.gd")
var g
var w
var tb
var failures: Array=[]
var checks: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.mode_maplists["tb"]=["qsrc_dm1"];g.selected_map="qsrc_dm1";g.start_host("City",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():if id<0 and id!=-1:g._peer_left(id)
	Fixture.build(g);w=g.match_mode.fortress.walkers;tb=g.match_mode.titanball
	for id in g.players:
		g.players[id].team=0 if id==1 else 1;g.players[id].dead=false;g.players[id].spectator=false;g.players[id].input_blocked=false;g.fighters[id].position=Vector3(90,0,0)
	await physics_frame;await physics_frame
	check(tb.preparing() and tb.preparation_left==60 and g.round_left==600,"New round starts with sixty seconds preparation outside the match budget")
	check(g.pickups.is_empty(),"Ruined city has no natural pickups")
	var tf=g.match_mode.fortress
	check(tb.stations.size()==6 and tf.buildings.size()==6 and tf.buildings.values().all(func(b):return b.kind=="dispenser" and b.universal and b.map_owned),"Six permanent universal dispensers serve bases and both sides of each checkpoint")
	for index in tb.stations.size():
		var station: Vector3=tb.stations[index]
		for id in [1,-1]:
			g.fighters[id].position=station+Vector3(.7,0,0);var state: Dictionary=g.players[id];state.hp=1;state.armor=0;state.ammo=[0,0,0,0]
			g.clock+=1.1;tf.tick_sentries()
			check(state.hp>1 and state.armor>0 and state.ammo[0]>0,"Station %d restores health armour and ammunition for team %d"%[index,state.team])
			g.fighters[id].position=Vector3(90,0,0)
	tf.damage_building(-9000,-1,9999);check(tf.buildings.has(-9000),"Map resupply cannot be permanently destroyed")
	var space=g.get_world_3d().direct_space_state
	var slit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(18,1.45,16),Vector3(18,1.45,20),1))
	var reverse: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(18,1.45,20),Vector3(18,1.45,16),1))
	check(slit.is_empty() and reverse.is_empty(),"Hangar slits permit fire in both directions during preparation")
	var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=.6
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,Vector3(18,1.45,16));query.motion=Vector3(0,0,4)
	check(space.cast_motion(query)[0]<1.,"Even a prone-sized player cannot pass through a firing slit")
	var gate: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,16),Vector3(0,1,20),1))
	check(not gate.is_empty(),"Hangar gate blocks direct approach in preparation")
	var sealed:=true
	for target in [Vector3(24,1,0),Vector3(-24,1,0),Vector3(0,1,-10),Vector3(0,18,0)]:
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,0),target,1)).is_empty():sealed=false
	check(sealed,"Hangar side walls rear wall and roof prevent preparation bypass")
	var r: Dictionary=w.robots.test;g.fighters[1].position=w.transform(r)*w.LADDER
	check(w.try_board(1,"test"),"Attacker may occupy cockpit during preparation")
	for i in 3599:g.clock+=1./60.;g._server_tick(1./60.)
	check(tb.preparing() and g.round_left==600 and r.distance==0 and r.speed==0,"Players simulate for preparation while match clock and piloted robot remain stopped")
	g.clock+=.1;g._server_tick(.1);await physics_frame;await physics_frame
	check(not tb.preparing() and absf(g.round_left-599.9166667)<.01,"Only time after the exact preparation boundary consumes the match timer")
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,16),Vector3(0,1,20),1)).is_empty(),"Gate physically opens at the end of preparation")
	for i in 300:g.clock+=1./60.;w.tick(1./60.)
	check(r.speed>.799 and r.distance>1.9,"Piloted robot reaches full speed after the five-second start with the hangar open")
	g._restart_round();await physics_frame
	check(tb.preparing() and tb.preparation_left==60 and g.round_left==600 and tf.buildings.size()==6,"Round restart restores preparation closed gate and universal stations")
	check(tb.snapshot().preparation==60 and tb.snapshot().stations.size()==6,"Preparation and resupply positions are included in authoritative snapshots")
	FileAccess.open("res://test-results/ba2/gameplay/city.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BA2_CITY_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
