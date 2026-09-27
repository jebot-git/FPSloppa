extends SceneTree
const Models=preload("res://deathmatch/counterstrike/models.gd")
func _initialize():run.call_deferred()
func capture(path: String):
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cs16/"+path+".png")
func run():
	root.size=Vector2i(1280,800);AudioServer.set_bus_mute(0,true)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.hud.show_menu(true);game.hud.host_panel.show()
	game.hud.preferred_host_weapons="cs16";game.hud.weapon_choice.choose("cs16")
	await capture("host-menu")
	game.selected_map="de_dust2_rebuilt"
	game.start_host("Weapon visual audit",0,100,60,true,"dm","cs16")
	assert(game.active and game.armory.effective()=="cs16")
	game.bots.free();game.bots=null;game.set_physics_process(false)
	game.menu_open=false;game.hud.show_menu(false)
	game.local_pitch=-.04
	for slot in 12:
		var s: Dictionary=game.players[1]
		s.weapon=slot;s.owned=range(12);s.hp=100;s.dead=false;s.invulnerable=0;s.input_blocked=false;s.cooldown=0;s.ammo=[240,64,300,40]
		game.desired_weapon=slot;game.model_weapon=-1
		await capture("game-"+Models.NAMES[slot])
	print("CS16_GAME_PREVIEW_OK");game.disconnect_game();game.queue_free()
	for i in 8:await process_frame
	Models.cache.clear();quit()
