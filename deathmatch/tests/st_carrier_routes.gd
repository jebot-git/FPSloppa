extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("Carrier travel time",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Carrier");g.players[-1].team=0
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(300,1,300))
	Fixture.box(g,Fixture.ORIGIN+Vector3(40,3,-1),Vector3(30,6,18))
	Fixture.box(g,Fixture.ORIGIN+Vector3(40,2.8,12),Vector3(42,.8,7))
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame;await physics_frame
	var ai=g.bots;var st=ai.tribes;var routes=st.routes;var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	# Two clear physical corridors, explicitly connected: the shorter one
	# has tight bends and low overhead clearance, the longer one stays outside.
	routes.built=true
	var vertices: Array=[Vector3.ZERO,Vector3(20,0,0),Vector3(20,0,12),Vector3(60,0,12),Vector3(60,0,0),Vector3(80,0,0),Vector3(20,0,-35),Vector3(60,0,-35)]
	for point in vertices:routes.add(Fixture.ORIGIN+point+Vector3.UP*.06)
	for lane in [[0,1,2,3,4,5],[0,6,7,5]]:
		for i in range(1,lane.size()):
			check(routes.clear(routes.points[lane[i-1]],routes.points[lane[i]]),"Fixture edge has real body-width clearance")
			routes.graph.connect_points(lane[i-1],lane[i])
	for index in routes.points.size():
		if routes.covered(routes.points[index]):routes.graph.covered[index]=true
	g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"energy")
	actor.position=routes.points[0];actor.velocity=Vector3.RIGHT*22
	var goal: Vector3=routes.points[5];var ordinary: PackedVector3Array=routes.path(actor.position,goal)
	var selected: PackedVector3Array=st.travel.path(-1,actor.position,goal,[],false)
	check(routes.route_length(selected)>routes.route_length(ordinary)+10,"Carrier chooses a longer open route over the short covered bends")
	var receipts: Array=[]
	for path in [ordinary,selected]:
		g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"energy")
		actor.position=routes.points[0];actor.velocity=Vector3.ZERO;actor.jump_held=false;s.yaw=0;s.jump=false;s.ski=false;s.jet_held=false
		await physics_frame;await physics_frame
		for frame in 5:g._configure_tribes(-1,s);actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
		actor.velocity=Vector3.RIGHT*22
		var estimate: float=st.travel.seconds(-1,path)
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.goal=goal;b.goal_key="route-time";b.goal_kind="capture";b.path=path;b.step=0;b.route_at=g.clock+60
		var elapsed:=0.0;var arrived:=false
		for frame in 2400:
			g.clock+=1.0/60;elapsed+=1.0/60;s.last_input=g.clock
			st.steer(-1,b);g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
			if actor.position.distance_to(goal)<2:arrived=true;break
		check(arrived,"Chosen corridor completes with ordinary movement and collision")
		receipts.append({"distance":routes.route_length(path),"estimated_seconds":estimate,"actual_seconds":elapsed,"arrived":arrived})
	check(receipts[1].actual_seconds<receipts[0].actual_seconds,"Longer selected corridor actually delivers sooner in real physics")
	actor.position=routes.points[0];actor.velocity=Vector3.RIGHT*22
	var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.goal=goal;b.path=selected;b.step=1
	check(st.travel.path(-1,actor.position,goal,[])==selected,"Replanning retains the fast route without needless lane changes")
	check(routes.path(actor.position,goal)==ordinary,"Carrier query leaves ordinary route costs unchanged")
	print("ST_CARRIER_ROUTES ",JSON.stringify({"checks":checks,"failures":failures,"timings":receipts}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
