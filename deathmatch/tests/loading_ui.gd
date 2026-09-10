extends SceneTree
var failures:Array=[]
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.loading.begin();game.loading.phase="Downloading map · Iron Foundry"
	game.loading.begin_item("map:test",10000000,"Iron Foundry");game.loading.advance("map:test",4200000)
	await create_timer(.4).timeout
	game.loading.started=Time.get_ticks_msec()-300
	var snapshot:Dictionary=game.loading.snapshot()
	check(absf(snapshot.fraction-.42)<.001 and snapshot.eta.begins_with("About "),"Progress and estimated time use received bytes")
	var overlay=preload("res://deathmatch/network/loading_overlay.gd").new();root.add_child(overlay);overlay.setup(game)
	await process_frame;await process_frame
	check(overlay.mouse_filter==Control.MOUSE_FILTER_STOP and overlay.cancel.visible,"Loading screen blocks underlying menu and offers cancellation")
	if not DisplayServer.get_name()=="headless":
		await create_timer(.3).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/loading/screen.png")
	game.loading.complete("map:test");game.loading.blocking=false
	await process_frame;await process_frame
	check(overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE and not overlay.cancel.visible,"Corner indicator does not capture pointer input")
	if not DisplayServer.get_name()=="headless":
		game.active=true;game.practice=false
		await create_timer(.3).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/loading/corners.png")
	game.loading.begin();game.loading.ticket=3
	game.loading._manifest(game.map_epoch,2,{})
	check(game.loading.ticket==3,"Stale manifest cannot replace current admission ticket")
	game.loading.begin_item("model:bad",100,"Bad model");game.loading.fail("model:bad","Required model checksum failed.")
	check(not game.active and not game.loading.blocking and game.loading.items.is_empty(),"Required model failure prevents entry and clears loading state")
	overlay.free();game.free()
	for frame in 60:await process_frame
	print("LOADING_UI_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
