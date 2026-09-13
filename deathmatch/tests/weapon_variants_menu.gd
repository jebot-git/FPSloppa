extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
func _initialize():run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,800)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.hud.show_menu(true);game.hud.host_panel.show()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/weapon-variants/host-menu.png")
	var failures: Array=[]
	for button in game.hud.host_panel.find_children("*","Button",true,false):
		if button.text in ["START HOST","PRACTICE VS BOTS","BACK"] and not game.hud.host_panel.get_global_rect().encloses(button.get_global_rect()):failures.append("Host button clipped: "+button.text)
	Fixture.setup(game);game.start_host("Visual weapon audit",0,100,60,true,"dm","ut99")
	game.bots.free();game.bots=null;game.set_physics_process(false)
	game.menu_open=false;game.hud.show_menu(false)
	for rules in ["quake","ut99"]:
		game.armory.select(rules);game.model_weapon=-1
		for slot in game.armory.table.size():
			var s: Dictionary=game.players[1]
			s.weapon=slot;s.owned=range(game.armory.table.size());s.hp=2000;s.dead=false;s.invulnerable=0;s.input_blocked=false;s.cooldown=0;s.ammo=[200,100,100,300]
			game.fighters[1].position=Fixture.point();game.desired_weapon=slot
			for alt in [false,true]:
				s.cooldown=0
				game.variant_combat.fire(1,alt)
				for i in 2:await process_frame
				game._update_projectiles(.04)
				for id in game.projectiles.keys():game._projectile_end(id,game.projectiles[id].position,slot)
	print("VARIANT_MENU_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	game.disconnect_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
