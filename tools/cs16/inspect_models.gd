extends SceneTree
const Models=preload("res://deathmatch/counterstrike/models.gd")
const Arsenal=preload("res://deathmatch/counterstrike/arsenal.gd")
func _initialize():run.call_deferred()
func panel(slot: int,mode: int) -> SubViewportContainer:
	var box:=SubViewportContainer.new();box.position=Vector2((mode%2)*640,(mode/2)*400);box.size=Vector2(640,400)
	var vp:=SubViewport.new();vp.size=Vector2i(640,400);vp.own_world_3d=true;box.add_child(vp)
	var stage:=Node3D.new();vp.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("263441");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("b8c9d9");env.environment.ambient_light_energy=.7;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.2;stage.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(10,145,0);fill.light_energy=.65;stage.add_child(fill)
	var model:=Models.make(slot);stage.add_child(model)
	var camera:=Camera3D.new();stage.add_child(camera);camera.near=.005;camera.make_current()
	var center:=Vector3(0,.02,-Models.LENGTHS[slot]*.27)
	if mode==2 and slot>0:
		var rear: Vector3=model.get_meta("sight_rear");camera.position=rear+Vector3.BACK*.13;camera.fov=50
		camera.basis=Basis.looking_at(Vector3(model.get_meta("sight_front"))-camera.position)
	else:
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=(Models.LENGTHS[slot]+.55)*.72
		camera.position=center+Vector3(2 if mode in [0,3] else -2,.15,.5 if mode==3 else -.2);camera.basis=Basis.looking_at(center-camera.position)
	if mode==3 and slot>0:model.get_node("ChamberAction").pose(.43)
	var label:=Label.new();label.position=Vector2(16,12);label.add_theme_font_size_override("font_size",20);label.text=Arsenal.NAMES[slot]+" / "+["RIGHT","LEFT","SIGHT LINE","ACTION OPEN"][mode];box.add_child(label)
	return box
func run():
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	DirAccess.make_dir_recursive_absolute("res://test-results/cs16/inspection")
	for slot in 12:
		var ui:=Control.new();root.add_child(ui)
		for mode in 4:ui.add_child(panel(slot,mode))
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/cs16/inspection/"+Models.NAMES[slot]+".png")
		ui.free()
	print("CS16_INSPECTION_RENDERED");quit()
