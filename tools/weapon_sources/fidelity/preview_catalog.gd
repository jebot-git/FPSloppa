extends SceneTree
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1800,1100)
	var stage=Node3D.new();root.add_child(stage)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color('202732');env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;stage.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-35,0);light.light_energy=1.5;stage.add_child(light)
	var camera=Camera3D.new();camera.position=Vector3(0,0,10);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.4;stage.add_child(camera)
	var folder='res://tools/weapon_sources/fidelity/catalog';var files=DirAccess.get_files_at(folder);var index=0;var gallery=Node3D.new();stage.add_child(gallery)
	for file in files:
		if not file.ends_with('.glb'):continue
		if not OS.get_cmdline_user_args().is_empty() and not file.begins_with(OS.get_cmdline_user_args()[0]):continue
		var doc=GLTFDocument.new();var state=GLTFState.new();assert(doc.append_from_file(folder.path_join(file),state)==OK)
		var node=doc.generate_scene(state);gallery.add_child(node);node.position=Vector3((index%4-1.5)*1.6,1.3-((index%12)/4)*1.2,0);node.rotation_degrees=Vector3(5,75,-6)
		var label=Label3D.new();label.text=file.trim_suffix('.glb');label.font_size=24;label.pixel_size=.0025;label.position=node.position+Vector3(-.3,-.4,1);gallery.add_child(label)
		index+=1
		if index%12==0:
			for i in 6:await process_frame
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png('res://test-results/weapon-fidelity/catalog-%d.png'%(index/12));gallery.free();gallery=Node3D.new();stage.add_child(gallery)
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png('res://test-results/weapon-fidelity/catalog-last.png');stage.free();quit()
