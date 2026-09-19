extends SceneTree
## Ready players must keep simulating when another peer stalls during rotation.
var game
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("Loading progress",0,100,30,true)
	game.set_physics_process(false)
	game.lobby.build();game.lobby.until=game.clock+45
	game.round_left=45
	game.lobby.offered=[{"mode":"ig","map":"qsrc_dm6","rules":"doom"}]
	game.lobby.fallback={"mode":"ig","map":"qsrc_dm6","rules":"doom"}
	game.votes.allowed_modes=["dm","ig"]
	game.intermission=0
	# Seven admitted players plus one connected peer still preparing assets.
	for id in range(1,8):
		if not game.players.has(id):
			game.players[id]=game._new_state("Ready "+str(id),id)
			game._create_fighter(id)
		game.fighters[id].position=Vector3((id-4)*2,.05,4)
		game.players[id].serial=1
	game.pending_names[8]="Slow loader"
	game.pending_joins[8]=game.clock+240
	game.map_loading=true
	var admitted: Dictionary=game.players
	game.players={}
	game._server_tick(1.0/60)
	check(game.map_loading and game.round_left==45,"Transition still waits when no player is ready")
	game.players=admitted
	var origin:Vector3=game.fighters[1].position
	await physics_frame
	for seq in range(1,61):
		game.clock+=1.0/60
		for id in range(1,8):
			game._accept_input(id,{"seq":seq,"move":Vector2(0,-1),"yaw":0.0,"pitch":0.0,"fire":false,"weapon":2,"slow":false,"respawn":false})
		game._server_tick(1.0/60)
		await physics_frame
	check(game.players[1].last_seq==60,"Ready players' input continues arriving during delayed join")
	check(game.fighters[1].position.distance_to(origin)>3,"Ready players move while eighth player is loading")
	check(game.round_left<45,"Lobby countdown advances while eighth player is loading")
	check(game.lobby.cast(1,"ig","qsrc_dm6"),"Ready player can select a lobby card during delayed join")
	for id in [2,3,4]:game.lobby.cast(id,"ig","qsrc_dm6")
	check(game.lobby.tally()[0]==4,"Ready players can vote directly during delayed join")
	check(game.pending_names.has(8),"Delayed peer retains its individual admission gate")
	# Also exercise the ordinary match branch, including its round timer.
	game.current_map="qsrc_dm1";game.match_mode.kind="dm"
	game.map_loading=true;game.round_left=600
	origin=game.fighters[1].position
	for seq in range(61,91):
		game.clock+=1.0/60
		game._accept_input(1,{"seq":seq,"move":Vector2(1,0),"yaw":0.0,"pitch":0.0,"fire":false,"weapon":2,"slow":false,"respawn":false})
		game._server_tick(1.0/60)
		await physics_frame
	check(game.fighters[1].position.distance_to(origin)>1,"Ready player moves on match entry during delayed join")
	check(game.round_left<600,"Match starts for admitted players during delayed join")
	print("MAP_LOADING_PROGRESS_RESULT ",JSON.stringify(failures))
	game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
