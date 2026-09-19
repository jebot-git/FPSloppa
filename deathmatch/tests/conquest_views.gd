extends SceneTree
var game
func _initialize():run.call_deferred()
func run() -> void:
	Engine.max_fps=60
	create_timer(60).timeout.connect(func():quit(2))
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.dedicated=true;game.max_clients=64;game.selected_map=game.match_mode.conquest.MAP_ID
	game.start_host("CQ view",0,100,30,true)
	if not game.active:push_error("CQ visual host did not start");quit(2);return
	game.set_physics_process(false)
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	if game.hud:game.hud.hide()
	var camera: Camera3D=game.get_node("Overview");camera.make_current();camera.fov=75
	DirAccess.make_dir_recursive_absolute("res://test-results/conquest")
	for zone in [0,3,1]:
		var center: Vector3=game.match_mode.conquest.Rules.center(zone)
		camera.position=center+Vector3(11,6,15);camera.look_at(center+Vector3.UP*1.3)
		for frame in 30:await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://test-results/conquest/district-%02d.png"%zone)
	print("CQ_VIEWS_COMPLETE")
	game.disconnect_game();game.queue_free();await process_frame;quit()
