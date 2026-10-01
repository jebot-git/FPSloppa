extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const OUT="res://test-results/avatar-cache/"
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();camera.position=Vector3(0,1.05,-4);world.add_child(camera);camera.look_at(Vector3(0,1.05,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.4;camera.current=true
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("202630");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);world.add_child(light)
	var samples=["sample_d","sample_f","sample_g","sakurada_fumiriya"]
	var metrics:Array=[]
	for phase in ["fresh","cached"]:
		var library=Library.new();root.add_child(library);library.entries.clear();library.runtime_cache().directory="/tmp/fps-avatar-cache-gpu"
		var actors:Array=[]
		for i in samples.size():
			var path:String="res://vrm/"+samples[i]+".vrm";var hash:String=FileAccess.get_sha256(path) if phase=="cached" else samples[i]
			library.entries[hash]={"path":path}
			while not library.prepare_avatar(hash):assert(library.last_error.is_empty());await process_frame
			var actor:=Node3D.new();actor.position.x=(i-1.5)*.88;world.add_child(actor);actors.append(actor)
			var rig=library.create_avatar(hash);assert(rig);actor.add_child(rig);rig.set_weapon(-1);rig.set_process(false);rig.solver.active=false;rig.eyes.active=false;rig.motion.pause();rig.mouth.set_process(false)
			var surfaces:=0;var triangles:=0;var morphs:=0
			for mesh in rig.visual_meshes:
				surfaces+=mesh.mesh.get_surface_count();morphs+=mesh.mesh.get_blend_shape_count()
				for surface in mesh.mesh.get_surface_count():triangles+=mesh.mesh.surface_get_array_index_len(surface)/3
			metrics.append({"phase":phase,"sample":samples[i],"surfaces":surfaces,"triangles":triangles,"morphs":morphs,"bones":rig.skeleton.get_bone_count(),"scale":rig.scale_factor})
		for frame in 40:await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+phase+".png")
		for actor in actors:actor.free()
		library.free();await process_frame
	FileAccess.open(OUT+"geometry.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	world.free();quit()
