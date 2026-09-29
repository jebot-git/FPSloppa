extends SceneTree
## Optional collision-height contours for plot_routing.py. No spectator.
func _initialize():run.call_deferred()
func run():
	var args:=OS.get_cmdline_user_args()
	var output: String=args[0] if not args.is_empty() else "res://test-results/st-routing"
	DirAccess.make_dir_recursive_absolute(output)
	for name in ["ctf_stonehenge","ctf_raindance"]:
		var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.selected_map=name
		game.start_host("ST route layout",0,100,60,true,"st");game.set_process(false);game.set_physics_process(false)
		while not game.bots.navigation.ready():await physics_frame
		game.bots.tribes.routes.build()
		var points: Array=[]
		for point in game.bots.tribes.routes.points:points.append([point.x,point.y,point.z])
		var row:={"map":name,"points":points,"bases":game.match_mode.bases,"generators":game.match_mode.tribes.stations().generators.map(func(r):return r.position)}
		var file:=FileAccess.open(output.path_join(name+"-layout.json"),FileAccess.WRITE)
		if file==null:push_error("Cannot write route layout to "+output);quit(1);return
		file.store_string(JSON.stringify(row));file.close()
		game.disconnect_game();game.free();await process_frame
	quit()
