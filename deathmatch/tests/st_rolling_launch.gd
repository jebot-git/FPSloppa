extends SceneTree
## Recorded Raindance hill, incoming ski speed and a partly charged pack.
var g
var results: Array=[]
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("ST moving launches",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Carrier")
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	for trial in [{"speed":18.0,"angle":0.0},{"speed":22.0,"angle":0.0},{"speed":18.0,"angle":-12.0},{"speed":18.0,"angle":12.0},{"speed":22.0,"angle":-12.0},{"speed":22.0,"angle":12.0},{"speed":18.0,"angle":-7.0},{"speed":18.0,"angle":7.0}]:
		var speed: float=trial.speed
		s.team=0;s.dead=false;s.serial+=1;s.yaw=0;s.pitch=0;s.jump=false;s.jet_held=false;s.ski=true
		g.match_mode.tribes.apply_equipment(-1,"light",[3,2,0],"energy")
		actor.position=Vector3(42.22372,33.66972,272.6165);actor.velocity=Vector3.ZERO;actor.jump_held=false
		await physics_frame
		for frame in 5:g._configure_tribes(-1,s);actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
		var goal: Vector3=g.match_mode.bases[0];var direction:=Vector3(goal.x-actor.position.x,0,goal.z-actor.position.z).normalized()
		actor.velocity=direction.rotated(Vector3.UP,deg_to_rad(trial.angle))*speed;actor.tribes_state.energy=35
		g.match_mode.return_flag(0);g.match_mode.return_flag(1);g.match_mode.flags[1].carrier=-1;g.match_mode.scores=[0,0]
		var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.goal=goal;b.goal_key="st:capture";b.goal_kind="capture"
		b.path=ai.tribes.path(actor.position,goal,-1);b.step=0
		var elapsed:=0.0;var start_rolls: int=ai.tribes.tactics.stats.get("rolling_launches",0)
		for frame in 3600:
			g.clock+=1.0/60;elapsed+=1.0/60;s.last_input=g.clock
			ai.tribes.steer(-1,b);g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump);g.match_mode.tick(1.0/60)
			if g.match_mode.scores[0]>0:break
		var rolling: int=ai.tribes.tactics.stats.get("rolling_launches",0)-start_rolls
		var staged: bool=speed==22 and absf(trial.angle)==12
		# A hard lateral correction consumes the lift reserved for this approach.
		# Preserve the established staged route instead of accepting a marginal flight.
		var passed: bool=g.match_mode.scores[0]>0 and (elapsed<15 and rolling==0 if staged else elapsed<3 and rolling>0)
		results.append({"speed":speed,"angle":trial.angle,"staged":staged,"energy":35,"seconds":elapsed,"rolling_launches":rolling,"captured":g.match_mode.scores[0]>0,"passed":passed})
		print("ST_ROLLING_LAUNCH ",JSON.stringify(results[-1]))
	FileAccess.open("res://test-results/st-routing/rolling-launch.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	g.disconnect_game();g.free();quit(0 if results.all(func(r):return r.passed) else 1)
