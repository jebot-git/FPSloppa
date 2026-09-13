extends SceneTree
var game
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var opts: Dictionary=JSON.parse_string(OS.get_cmdline_user_args()[0])
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.dedicated=true;game.max_clients=16;game.selected_map=opts.map
	game.match_mode.configure({"sv_gametype":opts.mode,"capturelimit":1000,"hilllimit":1000});game.armory.select(opts.rules)
	game.start_host("AI study",opts.port,100000,30,false,opts.mode,opts.rules)
	game.set_process(false);game.votes.allowed_modes=game.match_mode.NAMES.keys()
	var last:=""
	var deadline:=Time.get_ticks_msec()+600000
	while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(opts.stop):
		if FileAccess.file_exists(opts.control):
			var content:=FileAccess.get_file_as_string(opts.control)
			if content!=last:
				last=content;var row: Dictionary=JSON.parse_string(content)
				if row.get("restart",false):game._restart_round()
				else:
					game.armory.select(row.rules);game.current_map="";game.votes.change_match(row.mode+"|"+row.map)
		await create_timer(.2).timeout
	game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
