extends "res://deathmatch/tests/network_runner.gd"
func run() -> void:
	var args:=OS.get_cmdline_user_args();role=args[0]
	var path: String=args[1];var port:=int(args[2]);var hash:=FileAccess.get_sha256(path)
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	await process_frame
	if role=="server":
		var row: Dictionary=game.Maps.import_custom(path)
		check(not row.has("error") and row.get("modes")==["de"],"Host imports converted DE map")
		if row.has("error"):quit(1);return
		game.map_catalog=game.Maps.catalog();game.selected_map=row.id
		game.start_host("Conversion network",port,16,10,false,"de","cs16")
		check(await wait_for(func():return game.players.size()==2,40),"Client downloads and joins converted DE map")
		check(await wait_for(func():return game.match_mode.defusal.phase=="prepare",5),"Both teams enter DE preparation")
		game._announcement.rpc("CS_CONVERSION_DONE")
		await pause(2)
	else:
		check(not game.map_catalog.any(func(row):return row.sha256==hash),"Client starts without converted map")
		game.start_join("Conversion client","127.0.0.1",port)
		check(await wait_for(func():return game.active,45),"Automatic BSP download completes")
		check(game.map_sha==hash and game.match_mode.kind=="de" and game.armory.effective()=="cs16","Mode, loadout and BSP hash agree with host")
		check(game.match_mode.defusal.supported() and game.match_mode.defusal.site_bounds.size()==2,"Downloaded BSP registers local plant bounds")
		check(await wait_for(func():return game.feed.any(func(entry):return entry.text=="CS_CONVERSION_DONE"),10),"Server observes successful DE preparation")
		var row: Dictionary=game.map_catalog.filter(func(entry):return entry.sha256==hash)[0]
		check(row.modes==["de"] and game.Maps.catalog().any(func(entry):return entry.sha256==hash and entry.modes==["de"]),"Downloaded DE classification survives catalog reload")
	print("CS_MAP_NETWORK_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game("Conversion test complete");await pause(.1);quit(0 if failures.is_empty() else 1)
