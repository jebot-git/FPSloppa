extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,800)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.hud.show_menu(true);game.hud.open_host()
	game.hud.weapon_choice.choose("quake")
	for mode in ["tf","as","dm"]:
		game.hud.host_mode.choose(mode)
		for i in 5:await process_frame
		var expected: String="quake" if mode in ["tf","dm"] else "ut99"
		check(game.hud.weapon_choice.value==expected,mode+" shows the correct arsenal")
		check(game.hud.weapon_choice.trigger.disabled==(mode!="dm"),mode+" locks only required arsenals")
		check(game.hud.weapon_choice.items.size()==(3 if mode=="dm" else 1),mode+" offers only valid choices")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/assault-pickups/host-"+mode+".png")
	game.hud.host_panel.hide();game.hud.show_menu(false)
	game.match_mode.kind="as";game._load_map("as_frigate")
	game.get_node("Overview").position=Vector3(1104.0*1.3/32,2.6,1280.0*1.6/32)
	game.get_node("Overview").look_at(Vector3(1104.0*1.3/32,1.1,1000.0*1.6/32))
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/assault-pickups/frigate-armory.png")
	game._load_map("as_hislop");game.match_mode.reset();game.match_mode.fortress.draw()
	game.get_node("Overview").position=Vector3(0,13,-1664.0*1.75/32)
	game.get_node("Overview").look_at(Vector3(0,10.5,-1840.0*1.75/32))
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/assault-pickups/hislop-roof.png")
	print("MODE_WEAPON_MENU_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
