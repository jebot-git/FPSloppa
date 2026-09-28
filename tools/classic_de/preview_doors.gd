extends SceneTree
func _initialize():run.call_deferred()
func p(u: float,v: float,z: float) -> Vector3:return Vector3((v-300)*6,z,(400-u)*6)/32.0
func run():
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;AudioServer.set_bus_mute(0,true)
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="de_nuke_rebuilt";g.start_host("Door preview",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false);g.hud.hide()
	if is_instance_valid(g.viewmodel):g.viewmodel.hide()
	for actor in g.fighters.values():actor.hide()
	g.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	g.camera.position=p(453,319,-194);g.camera.look_at(p(435,320,-194));g.camera.fov=78
	for state in ["closed","open"]:
		if state=="open":g.get_node("Map/MapRuntime").triggers.use_target("GlassDoor2",1);await create_timer(1.5).timeout
		for frame in 12:await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://test-results/de-restoration/nuke-door-"+state+".png")==OK)
	g.disconnect_game();g.free();quit()
