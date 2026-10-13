extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1920,1440);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("28323a");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);world.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.25;camera.position=Vector3(0,.5,5);world.add_child(camera);camera.look_at(Vector3.ZERO);camera.current=true
	var rows=[[4,1,"SHOCKTROOP · CARBINE → SERVICE RIFLE"],[4,3,"MEDIC · CARBINE → HIGH ROF SMG"],[9,10,"SCOUT · SCOPED PISTOL → BEAM PISTOL"],[5,11,"TECHNICIAN · SALVO LAUNCHER → GUIDED LAUNCHER"],[2,0,"SECONDARY · FIELD PISTOL → BURST ENERGY PISTOL"]]
	for column in 2:
		var header:=Label3D.new();header.text="T1 · STARTER" if column==0 else "T2 · PROGRESSION";header.font_size=40;header.pixel_size=.0018;header.position=Vector3(-.95 if column==0 else 1.15,1.47,.05);header.billboard=BaseMaterial3D.BILLBOARD_ENABLED;world.add_child(header)
	for row in rows.size():
		for column in 2:
			var model:Node3D=preload("res://deathmatch/conquest/classes/models.gd").weapon(rows[row][column],"cq_shocktroop");world.add_child(model);model.position=Vector3(-1.35 if column==0 else .75,1.12-row*.53,0);model.rotation.y=-PI/2
		var label:=Label3D.new();label.text=rows[row][2];label.font_size=32;label.pixel_size=.0018;label.position=Vector3(0,1.12-row*.53-.23,.05);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;world.add_child(label)
	for i in 25:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/weapon-sources/modular-family.png")
	world.free();quit()
