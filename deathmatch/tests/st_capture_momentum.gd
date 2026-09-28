extends SceneTree
## Physical flag-deck approaches: normal inputs, swept touches and real planning.
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	seed(7129);g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST flag momentum",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1;g._spawn(1)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Runner")
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var st=ai.tribes;var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	for team in [0,1]:
		for angle in [0.0,PI*.5,PI,PI*1.5]:
			g.match_mode.return_flag(0);g.match_mode.return_flag(1)
			s.team=team;s.serial+=1;s.dead=false;s.yaw=0;s.pitch=0;s.jet_held=false;s.ski=false;s.jump=false
			g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"energy")
			var flag: Vector3=g.match_mode.bases[1-team];var direction:=Vector3.FORWARD.rotated(Vector3.UP,angle)
			actor.position=flag-direction*5+Vector3.UP*.06;actor.velocity=direction*11;actor.jump_held=false
			ai.brains[-1]=ai.new_brain(-1);var b: Dictionary=ai.brains[-1]
			b.goal=flag;b.goal_key="st:flag";b.goal_kind="objective";b.path=PackedVector3Array([flag]);b.plan_at=g.clock+100;b.next=g.clock+100
			st.flag_changed(-1,b);var speed_at_touch:=-1.0;var immediate:=false
			for frame in 180:
				g.clock+=1.0/60;ai.tick(1.0/60);g._configure_tribes(-1,s)
				actor.simulate(s.move,s.yaw,false,1.0/60,s.jump);g.match_mode.tick(1.0/60)
				if g.match_mode.flags[1-team].carrier==-1:
					speed_at_touch=Vector2(actor.velocity.x,actor.velocity.z).length()
					g.clock+=1.0/60;ai.tick(1.0/60)
					immediate=b.goal_key=="st:capture" and not b.has("tower")
					break
			check(speed_at_touch>=8,"Deck %d heading %.2f takes the flag without stopping"%[team,angle])
			check(immediate,"Flag touch overrides the ordinary thinking/planning delay")
	var rows: Array=[];g.match_mode.flags[s.team].carrier=123;actor.position=g.match_mode.bases[s.team]
	st.tactics.carrier_goal(-1,ai.brains[-1],rows)
	check(rows.size()==1 and rows[0].key=="st:hold","Missing home flag sends the arrived carrier to cover")
	# Station approaches retain the precision controller.
	var b: Dictionary=ai.brains[-1];b.goal_key="tribes:inventory:0"
	check(not st.offense.flag_run(-1,b),"Passing a flag does not change station stopping")
	# These recorded positions reproduced a walking-mesh corridor error in a
	# contested run. The full planner must select an ordinary terrain route.
	g.match_mode.return_flag(0);g.match_mode.return_flag(1);s.team=1;s.hp=100
	for origin in [Vector3(125.7372,44.10091,-242.1176),Vector3(111.7371,38.8322,-259.2536)]:
		actor.position=origin;actor.velocity=Vector3.ZERO;b=ai.new_brain(-1);ai.brains[-1]=b
		ai.plan(-1,b)
		check(b.goal_key=="st:flag" and not b.path.is_empty() and b.path[-1].distance_to(g.match_mode.bases[0])<.01,"Full planner routes from the recorded disconnected terrain patch")
	print("ST_CAPTURE_MOMENTUM ",JSON.stringify({"checks":checks,"failures":failures}));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
