extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,850);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("28323a");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);world.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;world.add_child(camera);camera.current=true
	for name in ["pistol","scout_pistol","beam_pistol","burst_pistol","designator","massacre","guided_launcher"]:
		var id:int={"pistol":2,"scout_pistol":9,"beam_pistol":10,"burst_pistol":0,"designator":8,"massacre":5,"guided_launcher":11}[name]
		var model:Node3D=preload("res://deathmatch/conquest/classes/models.gd").weapon(id,"cq_shocktroop");world.add_child(model)
		var bounds:=AABB();var started:=false
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var box:AABB=mesh.get_aabb()
			for i in 8:
				var point:Vector3=mesh.global_transform*box.get_endpoint(i)
				if not started:bounds=AABB(point,Vector3.ZERO);started=true
				else:bounds=bounds.expand(point)
		var center:=bounds.get_center();camera.size=maxf(.35,bounds.size.length()*.85)
		for view in ["rear","bottom"]:
			camera.position=center+Vector3(-.7,.45,1.0) if view=="rear" else center+Vector3(-.7,-.35,.8);camera.look_at(center)
			for i in 15:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/weapon-sources/fittings-"+name+"-"+view+".png")
		model.free()
	world.free();quit()
