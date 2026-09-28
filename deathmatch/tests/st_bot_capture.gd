extends SceneTree
## Integrated planner + ordinary movement + real swept flag touches. No opponents,
## teleports during a run, bonus energy, or preselected route/role.
var g
func _initialize():run.call_deferred()
func run():
	seed(7129)
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST capture regression",0,100,60,true,"st")
	g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1;g._spawn(1)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Route runner")
	if not is_instance_valid(g.bots):g.bots=load("res://deathmatch/bots.gd").new();g.add_child(g.bots);g.bots.setup(g)
	while not g.bots.navigation.ready():await physics_frame
	var report: Array=[];var ai=g.bots;var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	var args:=OS.get_cmdline_user_args();var all_spawns: bool="all-spawns" in args
	for team in [0,1]:
		if ("team=0" in args and team!=0) or ("team=1" in args and team!=1):continue
		for spawn in (range(g.ctf_spawns[team].size()) if all_spawns else [0]):
			var selected: Array=Array(args).filter(func(arg):return arg.begins_with("spawn="))
			if not selected.is_empty() and spawn!=int(selected[0].trim_prefix("spawn=")):continue
			g.match_mode.return_flag(0);g.match_mode.return_flag(1);g.match_mode.scores=[0,0]
			s.serial+=1;s.team=team;s.dead=false;s.yaw=0;s.pitch=0;s.jump=false;s.ski=false;s.jet_held=false
			g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"none")
			actor.position=g.ctf_spawns[team][spawn];actor.velocity=Vector3.ZERO;actor.jump_held=false
			ai.brains[-1]=ai.new_brain(-1);ai.tribes.assignments.clear();ai.tribes.assignment_state.clear()
			var samples: Array=[];var take_at:=-1.0;var seconds:=0.0;var peak:=0.0
			for frame in 18000:
				g.clock+=1.0/60;seconds+=1.0/60
				ai.tick(1.0/60);g._configure_tribes(-1,s)
				actor.simulate(s.move,s.yaw,false,1.0/60,s.jump,Vector3.ZERO)
				g.match_mode.tick(1.0/60)
				peak=maxf(peak,Vector2(actor.velocity.x,actor.velocity.z).length()*3.6)
				if take_at<0 and g.match_mode.flags[1-team].carrier==-1:take_at=seconds
				if frame%300==0:
					var b: Dictionary=ai.brains[-1]
					var tower: Dictionary=b.get("tower",{}).duplicate();tower.erase("controller")
					samples.append({"time":seconds,"at":actor.position,"velocity":actor.velocity,"move":s.move,"jet":s.jet_held,"ski":s.ski,"jump":s.jump,"grounded":actor.is_supported(),"goal":b.goal_key,"step":b.step,"target":b.path[b.step] if b.step<b.path.size() else b.goal,"phase":b.get("travel_phase",""),"energy":actor.tribes_state.energy,"tower":tower})
				if g.match_mode.scores[team]>0:break
				if frame%600==0:await process_frame
			var passed: bool=g.match_mode.scores[team]>0
			report.append({"team":team,"spawn":spawn,"passed":passed,"take_seconds":take_at,"seconds":seconds,"peak_kmh":peak,"samples":samples})
			FileAccess.open("res://test-results/st-tribes/research/captures.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
			print("ST_CAPTURE team=",team," spawn=",spawn," passed=",passed," take=",take_at," seconds=",seconds," at=",actor.position)
	FileAccess.open("res://test-results/st-tribes/research/captures.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	g.disconnect_game();g.free();quit(0 if report.all(func(r):return r.passed) else 1)
