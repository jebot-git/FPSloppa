extends SceneTree
func _initialize():run.call_deferred()
func run() -> void:
	Engine.max_fps=60;root.size=Vector2i(1280,720)
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("14202d");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("a8bdce");env.environment.ambient_light_energy=.7;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-130,0);light.light_energy=1.4;world.add_child(light)
	var camera:=Camera3D.new();camera.position=Vector3(2.1,1.7,3.4);camera.fov=43;world.add_child(camera);camera.look_at(Vector3(0,.85,0));camera.current=true
	var actor=preload("res://deathmatch/fighter.gd").new();actor.setup(1,"",Color("a24245"));actor.configure_jetpack(true);world.add_child(actor);actor.set_process(false)
	actor.avatar.animate(.016,Vector3.ZERO,"stand",1.65,true,{},false)
	var hud=preload("res://deathmatch/vr/status_hud.gd").new();root.add_child(hud);hud.position=Vector2(50,490);hud.size=Vector2(1180,210)
	DirAccess.make_dir_recursive_absolute("res://test-results/cq-jetpack")
	for active in [false,true]:
		actor.jetpack_state.mode=1 if active else 0;actor._update_jetpack_visual()
		hud.update_player_status({"team":0,"team_text":"RED TEAM","ability":actor.Jetpack.status(actor.jetpack_state),"carrier":"","flag_team":-1})
		for i in 10:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/cq-jetpack/%s.png"%("active" if active else "idle"))
	print("CQ_JETPACK_RENDERED");world.free();hud.free();quit()
