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
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.mode_maplists["tb"]=["qsrc_dm1"];g.selected_map="qsrc_dm1";g.start_host("Payload",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():if id<0 and id!=-1:g._peer_left(id)
	Fixture.build(g);g.match_mode.titanball.advance_time(60.);w=g.match_mode.fortress.walkers;tb=g.match_mode.titanball
	for id in g.players:
		g.players[id].team=0 if id==1 else 1;g.players[id].dead=false;g.players[id].spectator=false;g.players[id].input_blocked=false;g.fighters[id].position=Vector3(1000,0,0)
	await physics_frame;await physics_frame
	var r: Dictionary=w.robots.test
	g.fighters[-1].position=w.transform(r)*w.LADDER
	check(not w.try_board(-1,"test") and r.pilot==0,"Defenders cannot pilot or steal an empty robot")
	g.fighters[-1].position=Vector3(1000,0,0);g.fighters[1].position=w.transform(r)*w.LADDER
	check(w.try_board(1,"test"),"Attacker can pilot the payload")
	g.players[1].team=1;w.tick(1./60.)
	check(r.pilot==0,"Changing to defender releases the pilot seat")
	g.players[1].team=0;w.reset();r=w.robots.test
	g._spawn(1);g._spawn(-1)
	check(tb.attacker_spawns[0].any(func(p):return p.distance_to(g.fighters[1].position)<.1),"Attackers initially spawn near route start")
	check(tb.defender_spawns.any(func(p):return p.distance_to(g.fighters[-1].position)<.1),"Defenders spawn at their base")
	var defender_positions: Array=tb.spawns(1).duplicate()
	for stage in [1,2]:
		var live: Vector3=g.fighters[1].position;r.distance=tb.CHECKPOINTS[stage-1]+tb.CLEARANCE_METRES;tb.observe("test",r)
		check(g.fighters[1].position==live,"Checkpoint %d does not teleport living attackers"%stage)
		g._spawn(1)
		check(tb.spawns(0)==tb.attacker_spawns[stage] and tb.attacker_spawns[stage].any(func(p):return p.distance_to(g.fighters[1].position)<.1),"Checkpoint %d advances actual attacker respawns"%stage)
		check(tb.spawns(1)==defender_positions,"Checkpoint %d retains defender base spawns"%stage)
	# Every stage's bays have usable standing space and real floor collision.
	for id in g.fighters:g.fighters[id].position=Vector3(1000,0,0)
	await physics_frame
	var space=g.get_world_3d().direct_space_state
	var clear:=true
	for point in g.spawn_points:
		var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,point-Vector3.UP*.5,1))
		if hit.is_empty() or hit.normal.y<.9:print("SPAWN_FLOOR ",point," ",hit);clear=false;continue
		var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.65;capsule.radius=.3;query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.83);query.collision_mask=1
		var occupied: Array=space.intersect_shape(query,1)
		if not occupied.is_empty():print("SPAWN_BLOCKED ",point," ",occupied[0].collider.name);clear=false
	check(clear,"All sixteen initial, forward and defender spawn positions have floor and standing clearance")
	var lane_clear:=true
	for i in range(0,int(tb.ROUTE_METRES)+1):
		var pose: Transform3D=w.Route.sample(r.path,float(i))
		if w.bodies.test.test_move(pose,Vector3.ZERO):lane_clear=false;break
	check(lane_clear,"Defensive structures leave the complete robot collision route clear")
	r.distance=tb.ROUTE_METRES-1.;r.speed=.8;tb.observe("test",r)
	check(tb.winner==-1 and g.intermission==0,"Final approach is not an early attacker victory")
	r.distance=tb.ROUTE_METRES;r.speed=0;tb.observe("test",r)
	check(tb.winner==0 and g.intermission>0 and g.match_mode.scores==[1,0] and g.round_message.contains("ATTACKERS WIN"),"Delivery awards attacker victory and ends the round")
	tb.timeout();check(tb.winner==0 and g.match_mode.scores==[1,0],"Timeout cannot overwrite a delivered payload's result")
	g._restart_round();g.match_mode.titanball.advance_time(60.);r=w.robots.test
	check(tb.winner==-1 and tb.cleared==0 and tb.spawns(0)==tb.attacker_spawns[0],"New round restores initial attacker spawns and clears winner")
	g.round_left=.005;g._server_tick(.01)
	check(tb.winner==1 and g.match_mode.scores==[0,1] and g.round_message.contains("DEFENDERS WIN"),"Timer expiration awards defender victory")
	r.distance=tb.ROUTE_METRES;r.speed=0;tb.observe("test",r)
	check(tb.winner==1,"Late delivery cannot overwrite defender victory")
	check(tb.snapshot().winner==1 and tb.snapshot().attack_spawns.size()==3,"Objective snapshot contains result and all forward spawn groups")
	FileAccess.open("res://test-results/ba2/gameplay/payload.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BA2_PAYLOAD_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
