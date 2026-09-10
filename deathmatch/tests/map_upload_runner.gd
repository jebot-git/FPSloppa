extends SceneTree
var game
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(condition: Callable,seconds: float=40) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call():return true
		await create_timer(.05).timeout
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args();var role:=args[0];var hash:=args[2];var id:="custom_"+hash
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	if role=="server":
		game.dedicated=true;game.start_host("Upload server",28774,20,10,false)
		check(await wait_for(func():return game.map_catalog.any(func(row):return row.sha256==hash)),"Server receives and validates raw BSP upload")
		check(FileAccess.file_exists(game.Maps.Paths.folder("maps")+id+".bsp"),"Uploaded BSP persists in server maps folder")
		check(game.Maps.catalog().any(func(row):return row.sha256==hash),"Fresh catalog rediscovers server upload")
		check(FileAccess.get_file_as_string(game.Maps.Paths.folder("maps")+"dm_maplist.txt").contains(id),"Upload added to receiving mode maplist")
		check(not FileAccess.get_file_as_string(game.Maps.Paths.folder("maps")+"ctf_maplist.txt").contains(id),"Other mode maplist stays separate")
		check(game._rotate_map(id),"Server can select the uploaded BSP")
		check(await wait_for(func():return game.players.size()==2 and game.feed.any(func(row):return row.text.contains("MAP_REUSE_OK"))),"Another client downloads and plays the stored map")
		game._announcement.rpc("UPLOAD_TEST_DONE");await create_timer(1).timeout
	else:
		game.start_join(role,"127.0.0.1",28774)
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins")
		if role=="uploader":
			var row: Dictionary=game.Maps.import_custom(args[1]);check(not row.has("error"),"Client imports map")
			if not row.has("error"):game.map_catalog=game.Maps.catalog();game.uploads.upload(row)
		check(await wait_for(func():return game.active and game.map_sha==hash and not game.local_state().is_empty()),"Client loads uploaded map through host transfer")
		if role=="receiver":game._chat_request.rpc_id(1,"MAP_REUSE_OK")
		check(await wait_for(func():return game.feed.any(func(row):return row.text=="UPLOAD_TEST_DONE")),"Upload scenario completes")
	print("MAP_UPLOAD_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
