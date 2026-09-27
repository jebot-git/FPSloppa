extends "res://tools/cs16/inspect_models.gd"
func cutter_panel(closed: bool) -> SubViewportContainer:
	var box:=SubViewportContainer.new();box.position=Vector2(640 if closed else 0,400);box.size=Vector2(640,400)
	var vp:=SubViewport.new();vp.size=Vector2i(640,400);vp.own_world_3d=true;box.add_child(vp)
	var stage:=Node3D.new();vp.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("263441");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.75;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);light.light_energy=1.2;stage.add_child(light)
	var model=preload("res://deathmatch/pickups/cutter_model.gd").new();stage.add_child(model);model.pose(1 if closed else 0)
	var camera:=Camera3D.new();stage.add_child(camera);camera.near=.005;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.30
	var center:=Vector3(0,0,-.075);camera.position=center+Vector3(.015,.30,.1);camera.basis=Basis.looking_at(center-camera.position);camera.make_current()
	var label:=Label.new();label.position=Vector2(16,12);label.add_theme_font_size_override("font_size",20);label.text="TWEEZERS / "+("SNIPPING" if closed else "OPEN");box.add_child(label)
	return box
func run():
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var ui:=Control.new();root.add_child(ui)
	ui.add_child(panel(3,0));var open:=panel(3,3);open.position=Vector2(640,0);ui.add_child(open)
	ui.add_child(cutter_panel(false));ui.add_child(cutter_panel(true))
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cs16/snip/models.png")
	print("CS16_SNIP_PREVIEW_RENDERED");ui.free();Models.cache.clear();quit()
