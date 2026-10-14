extends SceneTree
const Test=preload("res://deathmatch/tests/cq_jungle_features.gd")
func _initialize():run.call_deferred()
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1280,900)
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.start_host("Loadout preview",0,100,10,false);game.menu_open=true;game.hud.show_menu(true)
	game.hud.menu_pages.navigate("cq_classes")
	DirAccess.make_dir_recursive_absolute("res://test-results/baked-jungle")
	await create_timer(.7).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/baked-jungle/class-menu.png")
	game.loadout_menu.choose_class("scout")
	await create_timer(.7).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/baked-jungle/scout-loadout-locked.png")
	game._spawn(1);game.classes.award(1,5000);game.loadout_menu.refresh()
	await create_timer(.7).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/baked-jungle/scout-loadout-unlocked.png")
	print("CQ_LOADOUT_CAPTURE_COMPLETE");game.disconnect_game();game.free();quit()
