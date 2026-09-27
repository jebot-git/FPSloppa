extends SceneTree
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1200,900);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var scene:=load("res://deathmatch/weapons/cs16/magazine_pouch.scn") as PackedScene
	var pouch=scene.instantiate();world.add_child(pouch)
	var magazine=load("res://deathmatch/counterstrike/models.gd").ammunition(2);magazine.scale=Vector3.ONE*.65;magazine.position=Vector3(-.025,.065,0);pouch.add_child(magazine)
	var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.40
	camera.position=Vector3(.36,.23,-.50);camera.look_at(Vector3(0,-.02,0));camera.near=.01;camera.make_current()
	camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color("202b32");camera.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;camera.environment.ambient_light_color=Color.WHITE;camera.environment.ambient_light_energy=.7
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.8
	var rim:=DirectionalLight3D.new();world.add_child(rim);rim.rotation_degrees=Vector3(-30,130,0);rim.light_energy=.7
	var label:=Label.new();root.add_child(label);label.text="CONTEXTUAL MAGAZINE POUCH";label.position=Vector2(32,28);label.add_theme_font_size_override("font_size",26)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/images")
	root.get_texture().get_image().save_png("res://docs/images/magazine-pouch.png")
	print("POUCH_PREVIEW_RENDERED");world.free();label.free();load("res://deathmatch/counterstrike/models.gd").cache.clear();quit()
