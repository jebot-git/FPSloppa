extends SceneTree
func _initialize():run.call_deferred()
func run():
	root.title="Tribes deployable review";root.size=Vector2i(1280,720);root.position=Vector2i(6000,6000)
	var scene:=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("16212a");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("bccfdd");env.ambient_light_energy=.7;world.environment=env;scene.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-20,0);light.light_energy=1.5;scene.add_child(light)
	var data=preload("res://deathmatch/tribes/deployable_data.gd");var model=preload("res://deathmatch/tribes/deployable_model.gd");var i:=0
	for kind in data.KINDS:
		var item=model.make(kind,i%2);scene.add_child(item);item.position=Vector3((i%4-1.5)*2.6,0,(i/4)*2.7)
		var label:=Label3D.new();label.text=kind.to_upper().replace("_"," ");label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=36;label.pixel_size=.008;scene.add_child(label);label.position=item.position+Vector3(0,1.8,0)
		i+=1
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=11;scene.add_child(camera);camera.position=Vector3(2,11,-12);camera.look_at(Vector3(0,.55,1.1));camera.current=true
	for frame in 20:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/st-tribes/research/deployables-preview.png")
	print("DEPLOYABLE_PREVIEW_DONE");quit()
