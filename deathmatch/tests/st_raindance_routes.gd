extends SceneTree
var g
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func vector(value: String) -> Vector3:
	var parts:=value.trim_prefix("(").trim_suffix(")").split(",")
	return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("Raindance recorded obstacles",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Replay")
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var st=ai.tribes;var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/tests/fixtures/st_raindance_obstacles.json"))
	for row in cases:
		s.team=row.team;s.dead=false;s.yaw=0;s.jump=false;s.jet_held=false;s.ski=false
		g.match_mode.return_flag(0);g.match_mode.return_flag(1)
		g.match_mode.tribes.apply_equipment(-1,row["class"],[3,2,0],row.pack)
		actor.position=vector(row.position);actor.velocity=vector(row.velocity);actor.jump_held=false;actor.tribes_state.energy=row.energy
		if row.goal=="st:capture":g.match_mode.flags[1-s.team].carrier=-1
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.goal=vector(row.target);b.goal_key=row.goal;b.goal_kind="capture" if row.goal=="st:capture" else "supply" if row.goal.begins_with("tribes:inventory") else "objective"
		var path:=PackedVector3Array()
		for point in row.path.trim_prefix("[").trim_suffix("]").split("), ("):path.append(vector(point.trim_prefix("(").trim_suffix(")")))
		b.path=path;b.step=row.step;b.route_at=g.clock+10
		await physics_frame;await physics_frame
		var start: Vector3=actor.position;var progressed:=false;var elapsed:=0.0
		for frame in 1800:
			g.clock+=1.0/60;elapsed+=1.0/60;s.last_input=g.clock
			if g.clock>=b.route_at:b.path=st.routes.path(actor.position,b.goal);b.step=0;b.route_at=g.clock+10
			st.steer(-1,b);g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
			if actor.position.distance_to(b.goal)<2 or actor.position.distance_to(b.goal)<start.distance_to(b.goal)-25:progressed=true;break
			if frame%60==0 and "detail" in OS.get_cmdline_user_args():print("ROUTE_DETAIL ",row.name," ",elapsed," ",actor.position," ",actor.velocity," ",b.get("travel_phase","")," jet ",s.jet_held," next ",b.path[b.step] if b.step<b.path.size() else b.goal)
		print("RAINDANCE_REPLAY ",row.name," seconds=",elapsed," at=",actor.position)
		check(progressed,"Recorded "+row.name+" resumes objective progress")
	# A roof fixture is a legitimate repair objective, but its approach must
	# leave the room first. Use both real imported bunker interiors.
	for team in [0,1]:
		var station: Dictionary=g.match_mode.tribes.stations().rows.filter(func(r):return r.team==team and r.kind=="inventory")[0]
		var turret: Dictionary=g.match_mode.tribes.stations().defences.rows.filter(func(r):return r.team==team and r.kind=="fusion" and absf(r.position.z-station.position.z)<50)[0]
		s.team=team;g.match_mode.return_flag(0);g.match_mode.return_flag(1);g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"repair")
		actor.position=station.position+Vector3.UP*.02;actor.velocity=Vector3.ZERO;actor.jump_held=false
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.goal=turret.position+Vector3(3.6,.06,0);b.goal_key="roof-test";b.goal_kind="st_fixed_repair"
		b.path=st.routes.path(actor.position,b.goal);b.step=0;b.route_at=g.clock+10
		await physics_frame;await physics_frame
		var exited:=false;var roof_push:=0.0;var arrived:=false;var exit_seconds:=-1.0
		for frame in 5400:
			g.clock+=1.0/60;s.last_input=g.clock
			if frame%30==0:st.tactics.watch(-1,b,st.tactics.record(-1))
			if g.clock>=b.route_at and not b.has("st_recovery"):b.path=st.routes.path(actor.position,b.goal);b.step=0;b.route_at=g.clock+10
			st.steer(-1,b);g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
			var ceiling: Dictionary=ai.navigation.ray(actor.position+Vector3.UP*1.7,Vector3(actor.position.x,b.goal.y+1.7,actor.position.z))
			if not exited and ceiling.is_empty():exited=true;exit_seconds=frame/60.0
			# Short jumps over floor equipment are legitimate; sustained thrust
			# against an actual overhead surface is the reported failure.
			var headroom: Dictionary=ai.navigation.ray(actor.position+Vector3.UP*1.7,actor.position+Vector3.UP*2.5)
			if s.jet_held and not headroom.is_empty() and headroom.normal.y<-.5:roof_push+=1.0/60
			if actor.position.distance_to(b.goal)<2:arrived=true;break
			if frame%60==0 and "detail" in OS.get_cmdline_user_args():print("ROOF_DETAIL ",team," ",frame/60.0," ",actor.position," ",b.path," step ",b.step)
		print("ROOF_REPLAY ",team," exit=",exit_seconds," contact_thrust=",roof_push," arrived=",arrived)
		check(exited and exit_seconds<15 and roof_push<.5,"Team %d roof approach leaves bunker without sustained thrust into its ceiling"%team)
		check(arrived,"Team %d reaches its roof fixture by an exterior approach"%team)
	print("ST_RAINDANCE_ROUTES ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
