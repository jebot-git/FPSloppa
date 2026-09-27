extends SceneTree
func _initialize():run.call_deferred()
func run():
	Engine.max_fps=60;root.size=Vector2i(1400,900)
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
	var world:=Node3D.new();root.add_child(world);world.position=Vector3(1000,20,1000)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(2.7,1.6,4.2);camera.look_at(world.position+Vector3(.25,1,0));camera.fov=44;camera.make_current()
	camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color("172631");camera.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;camera.environment.ambient_light_color=Color("bdcddb");camera.environment.ambient_light_energy=.7
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-40,-130,0);light.light_energy=1.4
	var actor=preload("res://deathmatch/fighter.gd").new();actor.setup(1,"",Color("a24245"));world.add_child(actor);actor.set_process(false);actor.configure_jetpack(true)
	actor.avatar.animate(.016,Vector3.ZERO,"stand",1.65,true,{},false)
	var pickup: Dictionary={"kind":"jetpack","item":0,"position":world.position+Vector3(1.4,0,0)}
	var node: Node3D=g._pickup_art(pickup);node.reparent(world);node.position=Vector3(1.4,0,0)
	var hud=preload("res://deathmatch/vr/status_hud.gd").new();root.add_child(hud);hud.position=Vector2(40,655);hud.size=Vector2(1320,220)
	var title:=Label.new();root.add_child(title);title.text="OPTIONAL ARENA JETPACK · BACKPACK + MAP PICKUP";title.position=Vector2(32,28);title.add_theme_font_size_override("font_size",28)
	for active in [false,true]:
		actor.jetpack_state.mode=1 if active else 0;actor._update_jetpack_visual()
		hud.update_player_status({"team":0,"team_text":"RED TEAM","ability":actor.Jetpack.status(actor.jetpack_state),"carrier":"","flag_team":-1})
		for i in 10:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/jetpacks/"+("active" if active else "idle")+".png")
	print("JETPACK_RENDERED");g.disconnect_game();g.queue_free();world.queue_free();hud.queue_free();title.queue_free()
	for i in 8:await process_frame
	quit()
