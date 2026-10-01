extends SceneTree
const SOURCE='res://tools/weapon_sources/fidelity/refined'
const OUT='res://test-results/weapon-shared-reduction'
func _initialize():run.call_deferred()
func scene_at(path:String):
	var doc=GLTFDocument.new();var state=GLTFState.new();assert(doc.append_from_file(path,state)==OK);return doc.generate_scene(state)
func run():
	root.size=Vector2i(960,720);root.content_scale_size=root.size
	var stage=Node3D.new();root.add_child(stage)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color('172029');env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color('c8ced4');env.environment.ambient_light_energy=.7;stage.add_child(env)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-30,0);key.light_energy=1.2;stage.add_child(key)
	var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(20,140,0);fill.light_energy=.45;stage.add_child(fill)
	var camera=Camera3D.new();camera.position=Vector3(0,0,10);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
	var rows=JSON.parse_string(FileAccess.get_file_as_string(OUT+'/runtime-counts.json'))
	for row in rows:
		if not OS.get_cmdline_user_args().is_empty() and not row.key in OS.get_cmdline_user_args():continue
		for angle in 3:
			var origin=Vector3.ZERO
			for pass_index in 2:
				var folder=OUT+'/renders/'+('before' if pass_index==0 else 'after');DirAccess.make_dir_recursive_absolute(folder)
				var model=load((OUT+'/'+row.key+'-before.scn') if pass_index==0 else ('res://deathmatch/weapons/fidelity/'+row.key+'.scn')).instantiate();stage.add_child(model)
				model.rotation_degrees=[Vector3(12,65,-5),Vector3(-20,135,4),Vector3(25,-45,-5)][angle]
				if pass_index==0:
					var bounds=AABB();var first=true
					for m in model.find_children('*','MeshInstance3D',true,false):
						var b=m.global_transform*m.get_aabb();bounds=b if first else bounds.merge(b);first=false
					origin=-bounds.get_center();camera.size=maxf(bounds.size.x,bounds.size.y*4./3)*1.12
				model.position=origin
				for frame in 3:await process_frame
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+'/'+row.key+'_'+str(angle)+'.png');model.free()
		print('COMPARED ',row.key)
	stage.free();quit()
