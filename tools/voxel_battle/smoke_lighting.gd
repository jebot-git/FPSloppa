extends SceneTree
var game
var errors:Array=[]
func _initialize():run.call_deferred()
func run():
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game)
	game.start_host("Baked Jungle smoke",0,100,10,false)
	assert(game.active and game.battle_map.lighting!=null)
	assert(game.match_mode.snapshot().class_mode.lighting_time>=0)
	if not game.headless:
		game.menu_open=false;game.hud.show_menu(false)
		game.battle_map.lighting.phase_override=0
		game.fighters[1].position=game.battle_map.Landscape.CENTERS[4]+Vector3(23,.3,-29)
		game.local_yaw=PI
		await create_timer(1).timeout
		var begin:=Time.get_ticks_msec()
		while not game.battle_map.terrain.settled():
			await process_frame
			assert(Time.get_ticks_msec()-begin<90000)
		await create_timer(1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/baked-jungle/playable-night.png")
		assert(game.battle_map.lighting.sky_environment!=null)
		assert(game.battle_map.lighting.sky_environment.ambient_light_energy==0)
		game.fighters[1].position=Vector3(-1000,game.battle_map.Landscape.surface(-1000,-300).x+.3,-300)
		game.local_yaw=-.6;game.local_pitch=-.08
		await create_timer(1).timeout
		var event:=InputEventKey.new();event.physical_keycode=KEY_N;event.pressed=true;game._unhandled_input(event)
		assert(game.night_vision.enabled_for(1),"Desktop N shortcut activates actual player's visor")
		begin=Time.get_ticks_msec()
		while not game.battle_map.terrain.settled():
			await process_frame
			assert(Time.get_ticks_msec()-begin<90000)
		await create_timer(1).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/staged-jungle/playable-nvg.png")
		assert(game.get_node("Environment").compositor.compositor_effects[0].enabled,"Player visor is attached to the active world compositor")
	await create_timer(.5).timeout
	print("CQ_PLAYABLE_LIGHTING_SMOKE_PASS ",game.battle_map.lighting.cycle_time())
	if game.battle_map.terrain:game.battle_map.terrain.shutdown()
	game.disconnect_game();game.free();quit()
