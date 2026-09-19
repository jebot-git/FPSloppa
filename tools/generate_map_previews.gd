extends SceneTree
## Prewarm screenshots before copying an asset folder to a headless server.
func _initialize():run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Map preview generation needs a graphical renderer.");quit(2);return
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var args:=OS.get_cmdline_user_args();var index:=args.find("--map")
	var selected: String=args[index+1] if index>=0 and index+1<args.size() else ""
	var failed: Array=[];var count:=0
	for row in game.map_catalog:
		if not selected.is_empty() and row.id!=selected:continue
		await game.map_previews.ensure(row)
		if game.map_previews.decode(game.map_previews.bytes_for(row.sha256))==null:failed.append(row.id)
		else:count+=1;print("MAP_PREVIEW_READY ",row.id)
	print("MAP_PREVIEW_BATCH ",JSON.stringify({"ready":count,"failed":failed}))
	game.queue_free();await process_frame;await process_frame;quit(0 if failed.is_empty() and count>0 else 1)
