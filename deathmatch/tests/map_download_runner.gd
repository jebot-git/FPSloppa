extends "res://deathmatch/tests/network_runner.gd"
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	role=args[0]
	game=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var hash: String=args[2]
	if role=="server":
		var result: Dictionary=game.Maps.import_custom(args[1])
		check(not result.has("error"),"Host custom map imported")
		if result.has("error"): quit(1); return
		game.map_catalog=game.Maps.catalog()
		game.selected_map=result.id
		game.dedicated=true
		game.start_host("Download test",27779,20,10,false)
		check(await wait_for(func(): return game.players.size()==2,40),"Two clients downloaded map and joined")
		check(await wait_for(func(): return game.players.values().any(func(s): return not s.xr.is_empty()),5),"Server accepts client tracked poses")
		for s in game.players.values(): check(s.owned==[2],"Multiplayer starts with only pistol")
		await pause(.5)
		game._announcement.rpc("TEST_DONE")
		await pause(1)
	else:
		check(not game.map_catalog.any(func(row): return row.sha256==hash),"Client starts without host map")
		game.start_join(role,"127.0.0.1",27779)
		check(await wait_for(func(): return game.active,45),"Automatic BSP download and load completed")
		check(game.map_sha==hash,"Downloaded BSP SHA256 agrees with host")
		check(FileAccess.file_exists("user://maps/custom_"+hash+".bsp"),"Raw map cached for future joins")
		if game.active:
			game.set_physics_process(false)
			var cmd: Dictionary=game._local_command()
			cmd.seq=100000
			cmd.xr=preload("res://deathmatch/vr/poses.gd").neutral()
			game._input_command.rpc_id(1,cmd)
			check(await wait_for(func(): return game.fighters.values().any(func(f): return not f.xr_pose.is_empty()),5),"Tracked head and hand poses replicate through snapshots")
			check(await wait_for(func(): return game.feed.any(func(entry): return entry.text=="TEST_DONE"),10),"Server scenario complete")
	print("MAP_DOWNLOAD_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game("Test complete")
	await pause(.1)
	quit(0 if failures.is_empty() else 1)
