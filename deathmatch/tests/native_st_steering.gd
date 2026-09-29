extends "res://deathmatch/tests/native_bots.gd"
## Complete player/brain/RNG comparisons around the two new ST route kernels.
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Native ST steering",0,100,60,true,"st");game.set_process(false);game.set_physics_process(false);bots=game.bots
	check(bots.native_ai!=null and bots.native_ai.has_method("st_route"),"Native ST kernels loaded")
	if bots.native_ai==null:quit(1);return
	Fixture.box(game,Fixture.ORIGIN-Vector3.UP*.5,Vector3(200,1,200))
	Fixture.box(game,Fixture.ORIGIN+Vector3(8,1,-8),Vector3(3,2,8))
	Fixture.box(game,Fixture.ORIGIN+Vector3(-8,3,-8),Vector3(8,.3,8))
	while not bots.navigation.ready():await physics_frame
	rng.seed=81274
	for id in game.players:
		game.players[id].team=0;game.players[id].dead=id not in [-1,-2];game.players[id].invulnerable=0
		game.fighters[id].position=Fixture.ORIGIN+Vector3(0,0,-1 if id==-2 else 0)
	var actor=game.fighters[-1];var cases:=0
	for trial in 360:
		var armour:String=["light","medium","heavy"][trial%3]
		game.match_mode.tribes.apply_equipment(-1,armour,[0,1,3],"energy")
		actor.position=Fixture.ORIGIN+Vector3(rng.randf_range(-12,12),0 if trial%2==0 else rng.randf_range(2,18),rng.randf_range(-12,12))
		actor.velocity=Vector3(rng.randf_range(-40,40),rng.randf_range(-12,12),rng.randf_range(-40,40));actor.tribes_state.grounded=trial%2==0
		actor.tribes_state.energy=[0.,1.9,3.,8.,25.,59.][trial%6];actor.tribes_state.normal=Vector3(rng.randf_range(-.6,.6),1,rng.randf_range(-.6,.6)).normalized();actor.jump_held=trial%4==0
		game.clock=40+trial*.1;game.players[-1].yaw=rng.randf_range(-PI,PI)
		var brain:Dictionary=bots.new_brain(-1);brain.goal=Fixture.ORIGIN+Vector3(rng.randf_range(-40,40),rng.randf_range(-5,35),rng.randf_range(-40,40));brain.goal_kind=["capture","supply","st_repair","st_destroy"][trial%4]
		brain.path=PackedVector3Array([actor.position,actor.position.lerp(brain.goal,.3),actor.position.lerp(brain.goal,.7),brain.goal]) if trial%5 else PackedVector3Array()
		brain.step=trial%4 if not brain.path.is_empty() else 0;brain.enemy=0;brain.equipment_aim_until=game.clock+1 if trial%7==0 else 0;brain.jet_recharge=trial%7==0
		# Route-rebuild callbacks are covered by the real-map regression suites;
		# isolate identical collision/steering states here without planner effects.
		brain.fall_replan_at=INF;brain.underpass_at=INF
		for precision in [false,true]:
			cases+=1
			var original:Dictionary=game.players.duplicate(true);var team:=team_snapshot();var ref:=clone_brain(brain);var native:=clone_brain(brain)
			seed(17000+cases)
			if precision:bots.tribes.precision_steer_reference(-1,ref)
			else:bots.tribes.steer_route_reference(-1,ref,trial%2==0)
			var expected:Dictionary=game.players.duplicate(true);var ref_team:=team_snapshot();var random:=randi()
			game.players=original.duplicate(true);restore_team(team);seed(17000+cases)
			if precision:bots.native_ai.st_precision(bots,-1,native)
			else:bots.native_ai.st_route(bots,-1,native,trial%2==0)
			var label:="trial=%d precision=%s"%[trial,precision]
			compare(ref,native,label+" brain");compare(expected,game.players,label+" players");compare(ref_team,team_snapshot(),label+" team");check(random==randi(),label+" RNG")
			game.players=original;restore_team(team)
	game.disconnect_game();game.free()
	print("NATIVE_ST_STEERING_RESULT ",JSON.stringify({"cases":cases,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
