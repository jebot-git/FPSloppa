extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	var extra:=OS.get_cmdline_user_args().has("extra")
	game.start_join("Extra" if extra else "Config check","127.0.0.1",28889)
	var end:=Time.get_ticks_msec()+(2000 if extra else 8000)
	while Time.get_ticks_msec()<end:
		if extra and game.last_event.contains("server full"): break
		if not extra and game.active: break
		await create_timer(.05).timeout
	var ok: bool
	if extra:
		ok=not game.active
	else:
		await create_timer(.2).timeout
		ok=game.active and game.current_map=="lqdm2" and game.server_name=="Config Test Arena" and not game.voice_enabled and game.frag_limit==7 and game.time_limit==180
		print("CONFIG_CLIENT_READY ",ok)
		await create_timer(4).timeout
	print("SERVER_CONFIG_CLIENT_RESULT ",ok)
	game.disconnect_game()
	quit(0 if ok else 1)
