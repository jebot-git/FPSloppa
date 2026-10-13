extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,1100);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("222e38");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-35,0);world.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.4;camera.position=Vector3(0,3.7,3.8);world.add_child(camera);camera.look_at(Vector3(0,0,0));camera.current=true
	var names=["pistol","scout_pistol","carbine","designator","massacre","health_box","ammo_box","injector","repair_kit","grenade"]
	for i in names.size():
		var ids:Dictionary={"pistol":2,"scout_pistol":9,"carbine":4,"designator":8,"massacre":5,"injector":7,"repair_kit":7,"health_box":6,"ammo_box":6}
		var model:Node3D=preload("res://deathmatch/conquest/classes/models.gd").weapon(ids[names[i]],"cq_medic" if names[i] in ["injector","health_box"] else "cq_technician") if ids.has(names[i]) else load("res://deathmatch/weapons/cq/"+names[i]+".glb").instantiate();world.add_child(model);model.position=Vector3((i%3-1)*1.5,0,(i/3-1.5)*1.1);model.rotation.y=-PI/2 if i<5 or names[i] in ["repair_kit","ammo_box","injector"] else 0.0
		var label:=Label3D.new();label.text=names[i].replace("_"," ").to_upper();label.position=model.position+Vector3(0,.03,.3);label.font_size=36;label.pixel_size=.0015;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;world.add_child(label)
	for i in 20:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/weapon-sources/gallery.png")
	world.free();quit()
