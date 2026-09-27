extends SceneTree
func _initialize():run.call_deferred()
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.selected_map="de_dust2_rebuilt";game.start_host("Dust2 local audit",0,100,10,true,"dm")
	assert(game.active and game.current_map=="de_dust2_rebuilt")
	assert(game.bots.ready_to_walk)
	assert(game.spawn_points.size()>=21)
	print("DUST2_HOST map=",game.current_map," spawns=",game.spawn_points.size()," players=",game.players.size()," pickups=",game.pickups.size())
	await physics_frame;await physics_frame
	if "--views" in OS.get_cmdline_user_args():
		if game.hud:game.hud.hide()
		game.set_process(false);game.set_physics_process(false)
		root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
		var camera: Camera3D=game.get_node("Overview");camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=78;camera.make_current()
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Dust2Rebuilt/manifest.json"))
		for view in data.views:
			camera.position=p(view.eye);camera.look_at(p(view.look))
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/dust2/game-"+view.name+".png")
	else:
		for frame in 120:await physics_frame
	print("DUST2_HOST_PASS")
	game.free();quit()
func p(a: Array) -> Vector3:return Vector3((a[1]-300)*6,a[2],(400-a[0])*6)/32.0+Vector3.UP*.05
