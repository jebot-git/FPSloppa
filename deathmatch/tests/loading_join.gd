extends "res://deathmatch/tests/network_runner.gd"
var blocked_ticks:=0
var premature:=false
var progress_seen:=false
func run() -> void:
	var args:=OS.get_cmdline_user_args();role=args[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	await process_frame
	if role=="server":
		var imported:Dictionary=game.Maps.import_custom(args[1]);check(not imported.has("error"),"Custom map imports")
		game.map_catalog=game.Maps.catalog();game.selected_map=imported.id
		game.avatars.library.entries.clear();game.avatars.library.scenes.clear()
		game.avatars.library.register_file(args[2]);game.avatars.library.register_file(args[3])
		game.avatars.library.selected=game.avatars.library.entries.keys()[0]
		game.start_host("Asset readiness",27790,100,60,false);game._add_player(-1,"Second model")
		check(await wait_for(func():return game.players.size()==3,80),"Client admitted after map and both models")
		check(game.loading.pending.is_empty(),"Completed admission ticket cleared")
		await pause(1);game._announcement.rpc("TEST_DONE");await pause(1)
	else:
		game.start_join("Receiver","127.0.0.1",27790)
		var deadline:=Time.get_ticks_msec()+80000
		while not game.active and Time.get_ticks_msec()<deadline:
			await process_frame
			if game.loading.blocking:
				blocked_ticks+=1
				if game.players.has(game.multiplayer.get_unique_id()):premature=true
				var progress:Dictionary=game.loading.snapshot()
				if progress.done>0 and progress.done<progress.total:progress_seen=true
		check(game.active,"Initial loading gate completes")
		check(blocked_ticks>30 and not premature,"No player spawned while assets are pending")
		check(progress_seen,"Byte progress visible while receiving")
		check(not game.loading.blocking and game.avatars.incoming.is_empty() and game.avatars.expected.is_empty(),"No pending model downloads when entering match")
		check(game.map_sha==FileAccess.get_sha256(args[1]),"Downloaded map verified before entry")
		for path in [args[2],args[3]]:
			var hash:=FileAccess.get_sha256(path)
			check(game.avatars.library.entries.has(hash),"Required model present at entry")
			if game.avatars.library.entries.has(hash):check(FileAccess.get_sha256(game.avatars.library.entries[hash].path)==hash,"Required model bytes verified")
		check(await wait_for(func():return game.feed.any(func(row):return row.text=="TEST_DONE"),8),"Server completes scenario")
	print("LOADING_JOIN_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();await pause(.1);quit(0 if failures.is_empty() else 1)
