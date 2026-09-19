extends SceneTree
var game
func _initialize():run.call_deferred()
func run() -> void:
	Engine.max_fps=60
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var args:=OS.get_cmdline_user_args()
	var expected: String=game._arg_value(args,"--expect","accepted")
	var port: int=game._arg_int(args,"--test-port",28987)
	game.start_join("CQ network test","127.0.0.1",port)
	var deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		await create_timer(.05).timeout
		if game.active or game.last_event.contains("launcher") or game.last_event.contains("Server full"):break
	var ok:=false
	if expected=="accepted":
		await create_timer(.5).timeout
		ok=game.active and game.match_mode.kind=="cq" and game.armory.effective()=="ut99" and game.match_mode.conquest.rules.owners.size()==16 and game.players.has(game.multiplayer.get_unique_id())
		var required: int=game._arg_int(args,"--roster-size",0)
		if required>0:
			while game.players.size()!=required and Time.get_ticks_msec()<deadline:await create_timer(.1).timeout
			ok=ok and game.players.size()==required and game.avatars.choices.size()==required
		print("CQ_CLIENT_READY ",ok)
		var hold: String=game._arg_value(args,"--hold-file","")
		while ok and not hold.is_empty() and not FileAccess.file_exists(hold) and Time.get_ticks_msec()<deadline:await create_timer(.1).timeout
	elif expected=="full":ok=not game.active and game.last_event.contains("Server full")
	else:ok=not game.active and game.last_event.contains("launcher")
	print("CQ_NETWORK_CLIENT ",JSON.stringify({"ok":ok,"expected":expected,"last_event":game.last_event,"mode":game.match_mode.kind,"players":game.players.size(),"capacity_limit":game.network_player_limit()}))
	game.disconnect_game();game.queue_free();await process_frame;quit(0 if ok else 1)
