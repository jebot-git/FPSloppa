extends SceneTree
const Art=preload('res://deathmatch/art.gd')
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1200,900);root.content_scale_size=root.size
	var stage=Node3D.new();root.add_child(stage)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color('172029');env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color('c8ced4');env.environment.ambient_light_energy=.7;stage.add_child(env)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-30,0);key.light_energy=1.2;stage.add_child(key)
	var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(20,140,0);fill.light_energy=.45;stage.add_child(fill)
	var camera=Camera3D.new();camera.position=Vector3(0,0,10);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
	var args=OS.get_cmdline_user_args();var folder=args[0] if args.size()>0 else 'res://test-results/weapon-fidelity/furniture/closeups';DirAccess.make_dir_recursive_absolute(folder)
	for name in (Array(args).slice(1) if args.size()>1 else ['tribes_1','tribes_2','tribes_3','tribes_4','tribes_5','tribes_7','cs16_1','cs16_2','cs16_10','cs16_11']):
		var split=name.rfind('_');var model=Art.weapon(int(name.substr(split+1)),2,name.substr(0,split));stage.add_child(model);model.rotation_degrees=Vector3(12,65,-5)
		var bounds=AABB();var first=true
		for m in model.find_children('*','MeshInstance3D',true,false):
			if m.has_meta('fpsloppa_filter_warmup'):continue
			var b=m.global_transform*m.get_aabb();bounds=b if first else bounds.merge(b);first=false
		model.position=-bounds.get_center();camera.size=maxf(bounds.size.x,bounds.size.y*4./3)*1.2
		for frame in 6:await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+'/'+name+'.png');model.free()
	stage.free();quit()
