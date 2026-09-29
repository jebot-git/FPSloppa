extends SceneTree
var g
var results: Array=[]
func vector(value: String) -> Vector3:
	var parts:=value.trim_prefix("(").trim_suffix(")").split(",")
	return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("Stonehenge covered carrier",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Carrier")
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var st=ai.tribes;var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/tests/fixtures/st_stonehenge_carrier_hold.json"))
	for row in cases:
		s.team=row.team;s.dead=false;s.serial+=1;s.yaw=0;s.pitch=0;s.jump=false;s.jet_held=false;s.ski=false
		g.match_mode.tribes.apply_equipment(-1,row["class"],[3,2,0],row.pack)
		actor.position=vector(row.position);actor.velocity=vector(row.velocity);actor.tribes_state.energy=row.energy;actor.jump_held=false
		g.match_mode.return_flag(0);g.match_mode.return_flag(1);g.match_mode.flags[1-s.team].carrier=-1
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.goal=vector(row.target);b.goal_key="st:hold";b.goal_kind="st_hold";b.hold=true
		b.path=st.path(actor.position,b.goal,-1);b.step=0;b.route_at=g.clock+10;st.tactics.memory.clear()
		await physics_frame;await physics_frame
		var reached:=false;var elapsed:=0.0;var samples: Array=[]
		for frame in 7200:
			g.clock+=1.0/60;elapsed+=1.0/60;s.last_input=g.clock
			if frame%30==0:st.tactics.watch(-1,b,st.tactics.record(-1))
			if g.clock>=b.route_at and not b.has("st_recovery"):b.path=st.path(actor.position,b.goal,-1);b.step=0;b.route_at=g.clock+10
			st.steer(-1,b);g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
			if actor.position.distance_to(b.goal)<2:reached=true;break
			if frame%60==0:samples.append({"seconds":elapsed,"position":actor.position,"velocity":actor.velocity,"phase":b.get("travel_phase",""),"energy":actor.tribes_state.energy,"waypoint":b.path[b.step] if b.step<b.path.size() else b.goal})
			if frame%300==0:await process_frame
		print("ST_STONEHENGE_HOLD team=",row.team," seconds=",elapsed," reached=",reached)
		results.append({"team":row.team,"seconds":elapsed,"passed":reached,"samples":samples})
	FileAccess.open("res://test-results/st-speed/stonehenge-carrier-hold.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	g.disconnect_game();g.free();quit(0 if results.all(func(r):return r.passed) else 1)
