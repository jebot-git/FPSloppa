extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,850);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("28323a");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);world.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;world.add_child(camera);camera.current=true
	for name in ["pistol","scout_pistol","designator","carbine","massacre","smg","assault_rifle","beam_pistol","guided_launcher","burst_pistol"]:
		var model:Node3D=load("res://deathmatch/weapons/cq/"+name+".glb").instantiate();world.add_child(model);model.rotation.y=-PI/2
		var bounds:=AABB();var started:=false
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var box:AABB=mesh.get_aabb()
			for i in 8:
				var point:Vector3=mesh.global_transform*box.get_endpoint(i)
				if not started:bounds=AABB(point,Vector3.ZERO);started=true
				else:bounds=bounds.expand(point)
		var center:=bounds.get_center();camera.position=center+Vector3(.15,.30,1.5);camera.look_at(center)
		camera.size=maxf(.25,maxf(bounds.size.y,bounds.size.x/(1440.0/850.0))*1.65)
		for i in 15:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/weapon-sources/tier2-"+name+"-closeup.png")
		model.free()
	world.free();quit()
