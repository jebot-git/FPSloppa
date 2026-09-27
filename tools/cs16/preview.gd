extends SceneTree
const Models=preload("res://deathmatch/counterstrike/models.gd")
const Arsenal=preload("res://deathmatch/counterstrike/arsenal.gd")
func _initialize():run.call_deferred()
func run():
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("1b232e");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.6;stage.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(10,160,0);fill.light_color=Color(.6,.75,1);fill.light_energy=.8;stage.add_child(fill)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,0,10);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.2;camera.make_current()
	root.size=Vector2i(1800,1100);root.content_scale_size=root.size
	var proof: Array=[]
	for slot in 12:
		var model:=Models.make(slot);stage.add_child(model);model.position=Vector3((slot%4-1.5)*1.85,(1-slot/4)*1.45,0);model.rotation_degrees=Vector3(5,80,-8);model.scale=Vector3.ONE*1.15
		var label:=Label3D.new();stage.add_child(label);label.position=model.position+Vector3(0,-.52,.2);label.text=Arsenal.NAMES[slot];label.font_size=32;label.pixel_size=.006;label.no_depth_test=true;label.modulate=Color("ead2a2")
		var triangles:=0
		for node in model.find_children("*","MeshInstance3D",true,false):
			for surface in node.mesh.get_surface_count():triangles+=node.mesh.surface_get_array_index_len(surface)/3
		proof.append({"weapon":Arsenal.NAMES[slot],"triangles":triangles})
	FileAccess.open("res://test-results/cs16/models.json",FileAccess.WRITE).store_string(JSON.stringify(proof,"  "))
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/cs16/arsenal.png")
	stage.free();quit()
