extends SceneTree
## Recorded launch hills: compare admission forecasts to actual flag touches.
var g
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_stonehenge"
	g.start_host("Capture entry physics",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Entry")
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var actor=g.fighters[-1];var s: Dictionary=g.players[-1];var results: Array=[]
	for trial in [{"team":0,"stage":Vector3(211.2705,135.8317,-119.3382)},{"team":0,"stage":Vector3(213.9348,134.3807,-126.6895)},{"team":1,"stage":Vector3(-153.5807,104.0604,191.9471)},{"team":1,"stage":Vector3(-182.6974,101.196,196.6324)}]:
		s.team=trial.team;s.dead=false;s.serial+=1;s.yaw=0;s.pitch=0;s.jump=false;s.jet_held=false;s.ski=false
		g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"energy")
		actor.position=trial.stage;actor.velocity=Vector3.ZERO;actor.jump_held=false
		await physics_frame
		for frame in 5:g._configure_tribes(-1,s);actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
		actor.tribes_state.energy=56.4
		g.match_mode.return_flag(0);g.match_mode.return_flag(1)
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.goal=g.match_mode.bases[1-s.team];b.goal_key="st:flag";b.goal_kind="objective";b.capture_preparing=true;b.travel_focus=true
		b.path=PackedVector3Array([b.goal]);b.step=0;b.tower={"goal":b.goal,"stage":actor.position,"phase":"run","at":g.clock}
		var prediction=ai.tribes.capture.forecast(actor.position,b.goal,11,75.0/9,56.4,g.match_mode.tribes.definition(-1),"energy")
		var elapsed:=0.0;var picked:=false
		for frame in 1500:
			g.clock+=1.0/60;elapsed+=1.0/60;s.last_input=g.clock
			ai.tribes.steer(-1,b);g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump);g.match_mode.tick(1.0/60)
			if ai.tribes.carrier(-1):picked=true;break
		var row:={"team":s.team,"stage":trial.stage,"prediction":prediction,"picked_up":picked,"seconds":elapsed,"speed_kmh":Vector2(actor.velocity.x,actor.velocity.z).length()*3.6,"energy":actor.tribes_state.energy,"position":actor.position}
		results.append(row);print("ST_CAPTURE_ENTRY ",JSON.stringify(row))
	if not OS.get_cmdline_user_args().is_empty():FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	g.disconnect_game();g.free();quit(0)
