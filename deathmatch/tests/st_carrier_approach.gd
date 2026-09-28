extends SceneTree
## Replay the Raindance return hill used by live Medium carrier -1008.
## A capture is insufficient if the approach first falls into the bunker.
var g
var failures: Array=[]
var results: Array=[]
func _initialize():run.call_deferred()
func run():
	seed(9300);g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("Carrier flag approach",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Carrier")
	while not g.bots.navigation.ready():await physics_frame
	var ai=g.bots;var st=ai.tribes;var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	# This is the recorded Medium run-up. Heavy uses a higher ballistic
	# approach, covered separately by st_adaptive_tactics' real foothill replay.
	for armour in ["light","medium"]:
		for drift in [false,true]:
			s.team=0;s.serial+=1;s.dead=false;s.yaw=0;s.pitch=0;s.jump=false;s.ski=false;s.jet_held=false
			g.match_mode.tribes.apply_equipment(-1,armour,[3,2,0],"energy")
			g.match_mode.return_flag(0);g.match_mode.return_flag(1);g.match_mode.flags[1].carrier=-1;g.match_mode.scores=[0,0]
			actor.position=Vector3(42.22372,33.66972,272.6165);actor.velocity=Vector3.ZERO;actor.jump_held=false
			ai.brains[-1]=ai.new_brain(-1);st.tactics.memory.clear();st.assignments.clear();st.assignment_state.clear()
			await physics_frame;await physics_frame
			for frame in 5:g._configure_tribes(-1,s);actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
			if drift:actor.velocity=Vector3(-.6,-1.5,5)
			var b: Dictionary=ai.brains[-1];b.goal=g.match_mode.bases[0];b.goal_key="st:capture";b.goal_kind="capture";b.role="capper"
			b.path=st.routes.path(actor.position,b.goal);b.step=0;b.route_at=g.clock+10;b.stage_goal=b.goal
			b.tower={"goal":b.goal,"stage":Vector3(42.22372,33.66972,272.6165),"phase":"run","at":g.clock,"path":PackedVector3Array(),"step":0}
			var entered:=false;var seconds:=0.0;var snapshots: Array=[]
			for frame in 7200:
				g.clock+=1.0/60;seconds+=1.0/60;s.last_input=g.clock
				if frame%30==0:st.tactics.watch(-1,b,st.tactics.record(-1))
				st.steer(-1,b);g._configure_tribes(-1,s);actor.simulate(s.move,s.yaw,false,1.0/60,s.jump);g.match_mode.tick(1.0/60)
				var p: Vector3=actor.position
				if p.x>15 and p.x<49 and p.z>313 and p.z<356 and p.y<27:entered=true
				if frame%30==0:snapshots.append({"seconds":seconds,"position":p,"velocity":actor.velocity,"phase":b.get("travel_phase",""),"energy":actor.tribes_state.energy,"tower":b.get("tower",{}).get("phase","")})
				if g.match_mode.scores[0]>0:break
				if frame%300==0:await process_frame
			var passed: bool=g.match_mode.scores[0]>0 and not entered
			results.append({"armour":armour,"initial_drift":drift,"captured":g.match_mode.scores[0]>0,"entered_bunker":entered,"seconds":seconds,"passed":passed,"samples":snapshots})
			if not passed:failures.append(armour+str(drift))
			print("ST_CARRIER_APPROACH ",armour," drift=",drift," capture=",g.match_mode.scores[0]>0," entered=",entered," seconds=",seconds," pass=",passed)
	FileAccess.open("res://test-results/st-speed/carrier-approach.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":results,"failures":failures},"  "))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
