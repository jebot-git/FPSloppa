extends SceneTree
## Normal Medium movement from the inventory pad to a chosen defence site.
var g
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("ST construction routes",0,100,60,true,"st")
	g.set_process(false);g.set_physics_process(false);g.players[1].spectator=true
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Builder")
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var rules=g.match_mode.tribes;var actor=g.fighters[-1];var s: Dictionary=g.players[-1];var reports: Array=[]
	for team in [0,1]:
		s.team=team;s.dead=false;s.yaw=0;s.pitch=0;s.jump=false;s.ski=false;s.jet_held=false
		rules.apply_equipment(-1,"medium",[3,2,4,1],"turret");actor.position=rules.stations().rows.filter(func(row):return row.team==team)[0].position;actor.velocity=Vector3.ZERO;actor.jump_held=false
		ai.tribes.construction.plans.clear();ai.tribes.construction.retry.clear()
		var plan: Dictionary=ai.tribes.construction.plan(-1)
		var brain: Dictionary=ai.new_brain(-1);ai.brains[-1]=brain
		var elapsed:=0.0;var placed:=false;var samples: Array=[]
		if not plan.is_empty():
			brain.goal=plan.stand;brain.goal_key="st:build:turret";brain.goal_kind="st_build";brain.path=ai.tribes.path(actor.position,brain.goal)
			for frame in 9000:
				g.clock+=1.0/60;elapsed+=1.0/60
				ai.tribes.steer(-1,brain);s.last_input=g.clock;g._configure_tribes(-1,s)
				actor.simulate(s.move,s.yaw,false,1.0/60,s.jump,Vector3.ZERO)
				ai.tribes.construction.build(-1,brain)
				if rules.deployables.count(team,"turret")>0:placed=true;break
				if frame%300==0:samples.append({"seconds":elapsed,"position":actor.position,"phase":brain.get("travel_phase","")})
				if frame%600==0:await process_frame
		reports.append({"team":team,"passed":placed,"seconds":elapsed,"site":plan,"samples":samples})
		print("ST_CONSTRUCTION_ROUTE ",team," passed=",placed," seconds=",elapsed," site=",plan," at=",actor.position)
	FileAccess.open("res://test-results/st-tribes/parity123/construction-routes.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	g.disconnect_game();g.free();quit(0 if reports.all(func(row):return row.passed) else 1)
