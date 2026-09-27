extends SceneTree
const Models=preload("res://deathmatch/counterstrike/models.gd")
var examples:=[
	[9,"AWP · Raise",11,0,0,100,0],
	[9,"AWP · Pull",11,100,0,100,0],
	[9,"AWP · Close, still unlocked",11,0,0,100,0],
	[9,"AWP · Lock",7,0,0,0,0],
	[5,"MP5 · Handle latched for slap",67,100,0,100,0],
	[8,"M249 · Belt held over open tray",259,0,100,0,55]]
func _initialize():run.call_deferred()
func panel(index: int) -> SubViewportContainer:
	var data: Array=examples[index];var slot: int=data[0]
	var box:=SubViewportContainer.new();box.position=Vector2((index%2)*640,(index/2)*360);box.size=Vector2(640,360)
	var vp:=SubViewport.new();vp.size=Vector2i(640,360);vp.own_world_3d=true;box.add_child(vp)
	var stage:=Node3D.new();vp.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("263441");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("b8c9d9");env.environment.ambient_light_energy=.7;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.2;stage.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(10,145,0);fill.light_energy=.65;stage.add_child(fill)
	var model:=Models.make(slot);stage.add_child(model)
	var action=model.get_node("ChamberAction");action.sync([1,slot,30,0,false,data[2],data[3],data[4],3 if slot==8 else 0,data[5],data[6]])
	if slot==8:action.belt_endpoint=Vector3(-.19,.25,-.335);action.pose(1)
	var center:=Vector3(0,.08,-.24)
	var camera:=Camera3D.new();stage.add_child(camera);camera.near=.005;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.60 if slot==9 else .70
	camera.position=center+Vector3(1 if slot==9 else -1,.6,.6);camera.basis=Basis.looking_at(center-camera.position);camera.make_current()
	var label:=Label.new();label.position=Vector2(16,12);label.add_theme_font_size_override("font_size",21);label.text=data[1];box.add_child(label)
	return box
func run():
	DirAccess.make_dir_recursive_absolute("res://test-results/cs16/actions")
	root.size=Vector2i(1280,1080);root.content_scale_size=root.size
	var ui:=Control.new();root.add_child(ui)
	for i in examples.size():ui.add_child(panel(i))
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cs16/actions/action-stages.png")
	print("CS16_ACTION_STAGES_RENDERED");ui.free();Models.cache.clear();quit()
