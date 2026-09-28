extends SceneTree
var g
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("ST physical route",0,20,30,true,"st")
	g.set_process(false);g.set_physics_process(false)
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	if not is_instance_valid(g.bots):g.bots=load("res://deathmatch/bots.gd").new();g.add_child(g.bots);g.bots.setup(g)
	while not g.bots.navigation.ready():await physics_frame
	var report: Array=[];var ai=g.bots;var actor=g.fighters[1];var s: Dictionary=g.players[1]
	var pads=g.match_mode.tribes.stations()
	var cases: Array=[]
	for team in [0,1]:
		for destination in [g.match_mode.bases[1-team],pads.rows.filter(func(r):return r.team==team)[0].position]:
			cases.append({"team":team,"start":g.match_mode.bases[team],"goal":destination,"station":destination!=g.match_mode.bases[1-team]})
		for spawn in g.ctf_spawns[team].slice(4):
			cases.append({"team":team,"start":spawn,"goal":pads.rows.filter(func(r):return r.team==team)[0].position,"station":true})
	ai.tribes.routes.build()
	# Long downhill corridor selected from actual BSP terrain, away from bases.
	var best_drop:=0.0;var descent: Dictionary={}
	for a in ai.tribes.routes.points:
		if g.match_mode.bases.any(func(b):return a.distance_to(b)<75):continue
		for b in ai.tribes.routes.points:
			var distance: float=Vector2(a.x-b.x,a.z-b.z).length()
			if distance<120 or distance>200 or a.y-b.y<=best_drop:continue
			if g.match_mode.bases.any(func(base):return b.distance_to(base)<75):continue
			best_drop=a.y-b.y;descent={"team":0,"start":a,"goal":b,"station":false,"descent":true}
	cases.append(descent)
	for team in [0,1]:
		var goal: Vector3=g.match_mode.bases[1-team]
		var below: Dictionary=ai.navigation.ray(goal-Vector3.UP*3,goal-Vector3.UP*80)
		if not below.is_empty():
			for armour in ["light","medium","heavy"]:cases.append({"team":team,"armour":armour,"start":below.position+Vector3.UP*.06,"goal":goal,"station":false,"tower_recovery":true})
	if "tower-only" in OS.get_cmdline_user_args():cases=cases.filter(func(row):return row.get("tower_recovery",false))
	for row in cases:
		var team: int=row.team;var destination: Vector3=row.goal
		actor.position=row.start;actor.velocity=Vector3.ZERO;actor.jump_held=false;s.team=team;s.jump=false;s.ski=false;s.jet_held=false
		s.yaw=0;s.pitch=0
		g.match_mode.tribes.apply_equipment(1,row.get("armour","light"),[3,2,4],"energy")
		var brain: Dictionary=ai.new_brain(1);brain.goal=destination;brain.goal_kind="objective";brain.path=ai.tribes.path(actor.position,destination)
		var positions: Array=[];var elapsed:=0.0;var ski_time:=0.0;var jet_time:=0.0;var max_speed:=0.0;var passed:=false;var launches: Array=[];var flight_was:=false
		for frame in 18000:
			g.clock+=1.0/60;elapsed+=1.0/60
			ai.tribes.steer(1,brain)
			var flight: bool=brain.get("travel_phase","")=="tower_flight"
			if flight and not flight_was:launches.append({"speed":Vector2(actor.velocity.x,actor.velocity.z).length(),"distance":Vector2(actor.position.x-destination.x,actor.position.z-destination.z).length(),"position":actor.position})
			flight_was=flight;s.last_input=g.clock;g._configure_tribes(1,s)
			actor.simulate(s.move,s.yaw,false,1.0/60,s.jump,Vector3.ZERO)
			ski_time+=(1.0/60 if s.ski else 0.0);jet_time+=(1.0/60 if s.jet_held else 0.0);max_speed=maxf(max_speed,Vector2(actor.velocity.x,actor.velocity.z).length())
			if frame%300==0:positions.append({"time":elapsed,"at":actor.position,"step":brain.step,"energy":actor.tribes_state.energy,"jet":s.jet_held,"move":s.move,"speed":Vector2(actor.velocity.x,actor.velocity.z).length(),"phase":brain.get("travel_phase",""),"tower":brain.get("tower",{}).duplicate(),"velocity":actor.velocity})
			passed=pads.at(1)>=0 if row.station else actor.position.distance_to(destination)<1.2
			if passed:break
			if frame%600==0:await process_frame
		report.append({"team":team,"armour":row.get("armour","light"),"start":row.start,"goal":destination,"descent":row.get("descent",false),"passed":passed,"seconds":elapsed,"ski_seconds":ski_time,"jet_seconds":jet_time,"max_speed":max_speed,"launches":launches,"path":brain.path,"samples":positions})
		print("ST_PHYSICAL_ROUTE team=",team," armour=",row.get("armour","light")," goal=",destination," passed=",passed," time=",elapsed," at=",actor.position," ski=",ski_time," jets=",jet_time," max_speed=",max_speed)
	FileAccess.open("res://test-results/st-tribes/research/routes.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	g.disconnect_game();g.free();quit(0 if report.all(func(r):return r.passed) else 1)
