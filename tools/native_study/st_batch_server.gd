extends SceneTree
## Production dependency graph. Isolated authority, no remote human clients.
var game
func _initialize():run.call_deferred()
func stats(rows:Array) -> Dictionary:
	rows.sort();return {"mean_ms":rows.reduce(func(a,b):return a+b,0.)/rows.size(),"p95_ms":rows[ceili(rows.size()*.95)-1],"p99_ms":rows[ceili(rows.size()*.99)-1],"max_ms":rows.back(),"over_60hz_budget":rows.filter(func(x):return x>1000./60).size()}
func run() -> void:
	var args:=OS.get_cmdline_user_args();var map_id:=args[0];var count:=int(args[1]);var ticks:=int(args[2]);var warmup:=int(args[3])
	seed(9400);game=load("res://deathmatch/arena.tscn").instantiate();game.set_script(preload("res://tools/native_study/st_batch_arena.gd"));root.add_child(game)
	game.dedicated=true;game.bind_address="127.0.0.1";game.max_clients=64;game.bot_population.count_target=count
	game.match_mode.configure({"sv_gametype":"st","capturelimit":100});game.selected_map=map_id;game.lobby.enabled=false
	game.start_host("ST batch benchmark",0,100,60,false)
	if not game.active:push_error("FAIL host");quit(1);return
	game.set_process(false);game.set_physics_process(false);game.voice_enabled=false
	var deadline:=Time.get_ticks_msec()+120000
	while not game.bots.navigation.ready():
		if Time.get_ticks_msec()>deadline:push_error("FAIL navigation timeout");quit(1);return
		await physics_frame
	var times:Array=[];var cold:Array=[];var peak:=0;var shots:=0
	for tick in warmup+ticks:
		await physics_frame;game.clock+=1./60
		var started:=Time.get_ticks_usec();game._server_tick(1./60);game._record_history();var elapsed:=(Time.get_ticks_usec()-started)/1000.
		if tick>=warmup:times.append(elapsed)
		else:cold.append(elapsed)
		peak=maxi(peak,game.projectiles.size())
	for state in game.players.values():shots+=state.shots
	if game.players.size()!=count:push_error("FAIL actor count");quit(1);return
	print("ST_BATCH_RESULT ",JSON.stringify({"kind":"server","map":map_id,"actors":count,"ticks":ticks,"warmup":warmup,"simulation":stats(times),"cold":stats(cold),"shots":shots,"peak_projectiles":peak,"scores":game.match_mode.scores,"native_st":game.bots.native_ai!=null and game.bots.native_ai.has_method("st_route") and game.bots.tribes.native_steering,"nav_cache":game.bots.navigation.batch_queries,"mine_index":game.match_mode.tribes.combat.indexed_mines,"engine":Engine.get_version_info().string}))
	game.disconnect_game();game.free();await process_frame;quit()
