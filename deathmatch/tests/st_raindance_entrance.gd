extends SceneTree
## Real imported BSP collision: every armour must walk through both entrances
## from the centre and both sides without needing jets or jumping the doorstep.
var g
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("Raindance entrances",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Entry runner")
	while not g.bots.navigation.ready():await physics_frame
	var origins: Array=[Vector3(32,19,312),Vector3(-56,26.4375,-275.397)]
	for team in [0,1]:
		var sign_value: float=1 if team==0 else -1
		for armour in ["light","medium","heavy"]:
			for lane in [-4.0,0.0,4.0]:
				var actor=g.fighters[-1];var s: Dictionary=g.players[-1];s.team=team
				g.match_mode.tribes.apply_equipment(-1,armour,[0,2,3],"none")
				var start: Vector3=origins[team]+Vector3(lane*sign_value,0,-18*sign_value)
				var hit: Dictionary=g.bots.navigation.ray(start+Vector3.UP*15,start-Vector3.UP*12)
				actor.position=hit.get("position",start)+Vector3.UP*.02;actor.velocity=Vector3.ZERO;actor.jump_held=false
				actor.configure_tribes(true);actor.ski_held=false;actor.jet_held=false
				for frame in 420:actor.simulate(Vector2(0,sign_value),0,false,1.0/60,false)
				var inside: float=(actor.position.z-origins[team].z)*sign_value
				var passed: bool=inside>3 and actor.position.y>=origins[team].y-1.1
				checks+=1
				var label:="team=%d armour=%s lane=%.0f"%[team,armour,lane]
				if not passed:failures.append(label)
				print("PASS " if passed else "FAIL ",label," position=",actor.position)
	# Six ordinary bot controllers share each entrance. Once a bot is inside,
	# remove its collision body from the doorway test, as its station visit is
	# a separate interaction; this isolates entrance congestion from pad queues.
	for id in range(-2,-7,-1):g._add_player(id,"Entry group %d"%id)
	for team in [0,1]:
		var sign_value: float=1 if team==0 else -1
		var pending: Array=[]
		var station: Dictionary=g.match_mode.tribes.stations().rows.filter(func(row):return row.team==team and row.kind=="inventory")[0]
		for index in 6:
			var id: int=-index-1;var actor=g.fighters[id];var s: Dictionary=g.players[id]
			s.team=team;s.dead=false;s.yaw=0;s.jump=false;s.jet_held=false;s.ski=false
			g.match_mode.tribes.apply_equipment(id,"light",[0,2,3],"none")
			var start: Vector3=origins[team]+Vector3((index%3-1)*4*sign_value,0,-(18+index/3*4)*sign_value)
			var hit: Dictionary=g.bots.navigation.ray(start+Vector3.UP*15,start-Vector3.UP*12)
			actor.position=hit.get("position",start)+Vector3.UP*.02;actor.velocity=Vector3.ZERO;actor.jump_held=false
			var brain: Dictionary=g.bots.new_brain(id);g.bots.brains[id]=brain
			brain.goal=station.position;brain.goal_kind="supply";brain.goal_key="entry-group";brain.path=g.bots.tribes.routes.path(actor.position,brain.goal);brain.step=0
			pending.append(id)
		await physics_frame;await physics_frame
		for frame in 1200:
			g.clock+=1.0/60
			for id in pending.duplicate():
				var actor=g.fighters[id];var s: Dictionary=g.players[id];s.last_input=g.clock
				g.bots.tribes.steer(id,g.bots.brains[id]);g._configure_tribes(id,s)
				actor.simulate(s.move,s.yaw,false,1.0/60,s.jump)
				if (actor.position.z-origins[team].z)*sign_value>3 and actor.position.y>=origins[team].y-1.1:
					pending.erase(id);s.dead=true;actor.position=Vector3(1000+abs(id)*3,100,1000)
			if pending.is_empty():break
			await physics_frame # Synchronize moved/removed body contacts for the group.
		checks+=1
		var label:="Six-bot entrance group clears team %d"%team
		if not pending.is_empty():failures.append(label)
		print("PASS " if pending.is_empty() else "FAIL ",label," remaining=",pending)
		for id in pending:
			var brain: Dictionary=g.bots.brains[id]
			print("ENTRY_PENDING ",id," at=",g.fighters[id].position," velocity=",g.fighters[id].velocity," input=",g.players[id].move," jet=",g.players[id].jet_held," blocked=",g.fighters[id].tribes_blocked," energy=",g.fighters[id].tribes_state.energy," floor=",g.fighters[id].is_supported()," phase=",brain.get("travel_phase","")," step=",brain.step," path=",brain.path)
	print("ST_RAINDANCE_ENTRANCE ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
