extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1440,720);root.content_scale_size=Vector2i(1440,720)
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("151a24");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=1.2;world.add_child(light)
	var camera:=Camera3D.new();camera.position=Vector3(0,2.0,7);world.add_child(camera);camera.look_at(Vector3(0,1,0));camera.current=true
	var lib=load("res://deathmatch/avatars/library.gd").new();root.add_child(lib)
	var index:=0
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json")):
		var hash: String=row.hash
		if not lib.entries.has(hash):continue
		for frozen in [false,true]:
			var actor=preload("res://deathmatch/fighter.gd").new();actor.setup(index+1,"",Color.WHITE);world.add_child(actor);actor.set_process(false)
			actor.position=Vector3(-3.5+index*1.4,0,0);actor.rotation.y=PI
			actor.set_avatar(lib.create_avatar(hash),hash);actor.set_frozen(frozen)
			if actor.label:actor.label.text="NORMAL" if not frozen else "";actor.label.font_size=24
			index+=1
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/frozen-avatars.png")
	world.free();lib.free();quit()
