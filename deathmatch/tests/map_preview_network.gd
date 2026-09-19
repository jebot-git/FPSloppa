extends SceneTree
const Preview=preload("res://deathmatch/maps/previews.gd")
var game
var failures: Array=[]
var checks: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(condition: Callable,seconds: float=35) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call():return true
		await create_timer(.05).timeout
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args();var role:=args[0];var source:=args[1];var hash:=args[2];var id:="custom_"+hash
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	if role=="prepare":
		var imported: Dictionary=game.Maps.import_custom(source)
		check(not imported.has("error"),"Graphical client imports the BSP")
		if not imported.has("error"):
			await game.map_previews.ensure(imported)
			check(Preview.decode(Preview.bytes_for(hash))!=null,"Importer generates a real rendered preview for the new map")
	elif role=="server":
		game.dedicated=true;game.votes.allowed_modes=["dm","tdm","tf","ig","if","ft"];game.start_host("Preview server",28775,20,10,false)
		check(await wait_for(func():return game.map_catalog.any(func(row):return row.sha256==hash)),"Dedicated server receives a connected client's BSP")
		var rows: Array=game.map_catalog.filter(func(row):return row.sha256==hash)
		if not rows.is_empty():
			var row: Dictionary=rows[0];var expected: Array=game.Maps.ImportPolicy.modes(source)
			check(row.modes==expected,"Server derives classification from the source filename")
			check(expected.all(func(mode):return id in game.mode_maplists.get(mode,[])),"Uploaded map enters every correct server maplist")
			check(game.match_mode.NAMES.keys().all(func(mode):return mode in expected or not id in game.mode_maplists.get(mode,[])),"Upload does not leak into other mode maplists")
			check(await wait_for(func():return expected.all(func(mode):return FileAccess.file_exists(game.Maps.Paths.folder("maps")+mode+"_maplist.txt") and FileAccess.get_file_as_string(game.Maps.Paths.folder("maps")+mode+"_maplist.txt").contains(id))),"Server persists the correct maplists")
			check(game.Maps.catalog().filter(func(entry):return entry.sha256==hash)[0].modes==expected,"Server catalog reload retains classification")
			check(Preview.decode(Preview.bytes_for(hash))!=null,"Headless server stores the uploaded preview without a renderer")
			check(await wait_for(func():return game.feed.any(func(row):return row.text.contains("PREVIEW_REUSE_OK"))),"Second client receives the preview before downloading any BSP")
			check(await wait_for(func():return game.feed.any(func(row):return row.text.contains("PREVIEW_DEDUP_OK"))),"Client can reimport known content without duplicate maps")
			check(game._rotate_map(id),"Server can select the uploaded map")
			check(await wait_for(func():return game.feed.any(func(row):return row.text.contains("PREVIEW_MAP_PLAYABLE"))),"Second client subsequently downloads and loads the BSP")
		game._announcement.rpc("PREVIEW_TEST_DONE");await create_timer(1).timeout
	else:
		game.start_join(role,"127.0.0.1",28775,role=="uploader")
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins the dedicated server")
		if role=="uploader":
			game.hud=preload("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
			game.menu_open=true;game.hud.show_menu(true);game.hud._process(0)
			check(game.hud.session_map_import.visible and not game.hud.session_map_import.disabled,"Connected spectator can import from the pause menu")
			await game.hud._import_bsp(source)
			check(await wait_for(func():return game.uploads.offered.is_empty()),"Pause-menu import finishes upload while connected")
			await game.hud._import_bsp(source)
			check(await wait_for(func():return game.uploads.offered.is_empty()) and game.map_catalog.filter(func(row):return row.sha256==hash).size()==1,"Reimport reuses the cached map and preview")
			game._chat_request.rpc_id(1,"PREVIEW_DEDUP_OK")
		else:
			check(await wait_for(func():return game.votes.allowed_matches.any(func(row):return row.map==id)),"Server announces uploaded map as a vote choice")
			check(not game.map_catalog.any(func(row):return row.sha256==hash),"Preview viewer has not downloaded the candidate BSP")
			game.map_previews.texture(id,hash)
			check(await wait_for(func():return Preview.decode(Preview.bytes_for(hash))!=null),"Client receives a bounded preview image from dedicated server")
			check(not game.map_catalog.any(func(row):return row.sha256==hash),"Thumbnail transfer does not trigger a full map download")
			game._chat_request.rpc_id(1,"PREVIEW_REUSE_OK")
		check(await wait_for(func():return game.map_sha==hash and game.active and not game.map_loading),"Uploaded map loads through the ordinary host transfer")
		if role=="receiver":
			var local: Dictionary=game.map_catalog.filter(func(row):return row.sha256==hash)[0]
			check(local.modes==game.Maps.ImportPolicy.modes(source),"Map download retains original mode classification")
			game._chat_request.rpc_id(1,"PREVIEW_MAP_PLAYABLE")
		check(await wait_for(func():return game.feed.any(func(row):return row.text=="PREVIEW_TEST_DONE")),"Network scenario completes")
	var output:=args[3]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"failures":failures},"  "))
	print("MAP_PREVIEW_NETWORK_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
