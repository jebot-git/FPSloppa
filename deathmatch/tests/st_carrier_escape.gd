extends SceneTree
## Replays recorded post-grab movement states with ordinary physics and no
## opponents. This isolates escape control from combat accuracy or health.
var g
var failures: Array=[]
var results: Array=[]
func _initialize():run.call_deferred()
func run():
	seed(9287)
	for map in ["ctf_raindance","ctf_stonehenge"]:
		g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
		g.selected_map=map;g.start_host("Recorded carrier escape",0,100,60,true,"st")
		g.set_process(false);g.set_physics_process(false)
		g.players[1].spectator=true;g.players[1].team=-1;g._spawn(1)
		for id in g.players.keys():
			if id<0:g._peer_left(id)
		g._add_player(-1,"Carrier")
		while not g.bots.navigation.ready():await physics_frame
		var fixtures: Array=[
			{"team":0,"position":Vector3(-91.79443,53.17551,-305.5364),"velocity":Vector3(7.822645,.315999,10.19014),"energy":29.2833,"pack":"energy"},
			{"team":1,"position":Vector3(66.87256,39.16949,314.9139),"velocity":Vector3(-9.605795,.218604,-8.660787),"energy":13.7833,"pack":"none"}
		] if map=="ctf_raindance" else [
			{"team":1,"position":Vector3(-176.2695,124.9121,148.7558),"velocity":Vector3(9.845667,0,4.904374),"energy":7.6833,"pack":"none"},
			{"team":0,"position":Vector3(168.5696,142.3278,-139.1795),"velocity":Vector3(-12.7013,-.057664,-2.365861),"energy":12.4,"pack":"none"}]
		for fixture in fixtures:
			var s: Dictionary=g.players[-1];var actor=g.fighters[-1];var ai=g.bots
			s.team=fixture.team;s.serial+=1;s.dead=false;s.yaw=0;s.pitch=0;s.jump=false;s.jet_held=false;s.ski=false
			g.match_mode.tribes.apply_equipment(-1,"light",[0,2,3],fixture.pack)
			actor.position=fixture.position;actor.velocity=fixture.velocity;actor.jump_held=false;actor.tribes_state.energy=fixture.energy
			g.match_mode.return_flag(0);g.match_mode.return_flag(1);g.match_mode.flags[1-s.team].carrier=-1
			ai.brains[-1]=ai.new_brain(-1);ai.tribes.assignments.clear();ai.tribes.assignment_state.clear()
			var stalled:=0.0;var worst_stall:=0.0;var escape_at:=-1.0;var samples: Array=[]
			for frame in 1800:
				g.clock+=1.0/60;ai.tick(1.0/60);g._configure_tribes(-1,s)
				actor.simulate(s.move,s.yaw,false,1.0/60,s.jump,Vector3.ZERO);g.match_mode.tick(1.0/60)
				var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
				stalled=stalled+1.0/60 if speed<2 else 0.0;worst_stall=maxf(worst_stall,stalled)
				if frame%30==0:samples.append({"seconds":frame/60.0,"position":actor.position,"velocity":actor.velocity,"energy":actor.tribes_state.energy,"phase":ai.brains[-1].get("travel_phase",""),"waypoint":ai.brains[-1].path[ai.brains[-1].step] if ai.brains[-1].step<ai.brains[-1].path.size() else ai.brains[-1].goal,"step":ai.brains[-1].step,"path":ai.brains[-1].path})
				if actor.position.distance_to(g.match_mode.bases[1-s.team])>100:escape_at=frame/60.0;break
				if frame%300==0:await process_frame
			var passed: bool=escape_at>=0 and worst_stall<4
			results.append({"map":map,"team":s.team,"pass":passed,"escape_100m_seconds":escape_at,"longest_slow_interval_seconds":worst_stall,"samples":samples})
			if not passed:failures.append(map+":"+str(s.team))
			print("ST_CARRIER_ESCAPE ",map," team=",s.team," escape=",escape_at," stall=",worst_stall," pass=",passed)
		g.disconnect_game();g.free();await process_frame
	FileAccess.open("res://test-results/st-raindance/carrier-escape.json",FileAccess.WRITE).store_string(JSON.stringify({"results":results,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
