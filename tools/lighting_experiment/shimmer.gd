extends SceneTree
## Isolate Compatibility depth precision with the same VRM and light setup.
const COMMON="res://addons/Godot-MToon-Shader/mtoon_common.gdshaderinc"
var records: Array=[]
var failures: Array=[]
func _initialize():run.call_deferred()
func translation_difference(a: Image,b: Image) -> Dictionary:
	var foreground:=0;var changed:=0;var total:=0.0
	for y in a.get_height():
		for x in a.get_width():
			var aa:=a.get_pixel(x,y);var bb:=b.get_pixel(x,y)
			if maxf(aa.r,maxf(aa.g,aa.b))<.04 and maxf(bb.r,maxf(bb.g,bb.b))<.04:continue
			foreground+=1
			var delta:=maxf(absf(aa.r-bb.r),maxf(absf(aa.g-bb.g),absf(aa.b-bb.b)))
			total+=delta
			if delta>.05:changed+=1
	return {"foreground_pixels":foreground,"changed_fraction":float(changed)/maxi(1,foreground),"mean_max_channel_change":total/maxi(1,foreground)}
func run() -> void:
	var output:="res://test-results/lighting-coverage/shimmer-"+RenderingServer.get_current_rendering_method()+"/"
	var args:=OS.get_cmdline_user_args()
	if "--depth-prepass" in args:output=output.trim_suffix("/")+"-prepass-"+args[args.find("--depth-prepass")+1]+"/"
	print("DEPTH_PREPASS ",ProjectSettings.get_setting("rendering/driver/depth_prepass/enable"))
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(800,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	var world:=Node3D.new();root.add_child(world)
	world.position=Vector3(20,2,-60);world.rotation.y=.8
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();world.add_child(environment)
	var env:=environment.environment;env.background_mode=Environment.BG_COLOR;env.background_color=Color(.025,.03,.04)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.48,.57,.7);env.ambient_light_energy=.6;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1,2.8);camera.look_at(world.to_global(Vector3(0,.87,0)));camera.fov=43;camera.make_current()
	var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-35,-20,0);sun.light_energy=.25
	var lamp:=OmniLight3D.new();world.add_child(lamp);lamp.position=Vector3(-1,1.5,1);lamp.omni_range=5;lamp.light_energy=1.5
	var library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	var fixed: String=FileAccess.get_file_as_string(COMMON).replace("render_mode skip_vertex_transform;","#ifdef IS_OUTLINE\nrender_mode skip_vertex_transform;\n#endif")
	fixed=fixed.replace("\t} else {\n\t\tVERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\t}","\t}")
	for sample in ["sample_d","sample_f","sample_g"]:
		var avatar=library.create_avatar(FileAccess.get_sha256(library.Paths.folder("vrm")+sample+".vrm"));world.add_child(avatar)
		avatar.rotation.y=PI;avatar.process_mode=Node.PROCESS_MODE_DISABLED;avatar.gun.hide();avatar.offhand_gun.hide()
		var materials: Dictionary={};var geometry: Array=[];var normals: Array=[]
		var translations: Array=[]
		for mesh in avatar.visual_meshes:
			geometry.append({"name":str(mesh.get_path()),"visible":mesh.is_visible_in_tree(),"first":mesh.get_meta("arena_first_person"),"third":mesh.get_meta("arena_third_person"),"surfaces":mesh.mesh.get_surface_count()})
			for i in mesh.mesh.get_surface_count():
				var mat: Material=mesh.get_active_material(i)
				if mat is ShaderMaterial and not materials.has(mat):
					materials[mat]=mat.shader
					var texture=mat.get_shader_parameter("_BumpMap")
					if texture is Texture2D:normals.append({"material":mat.resource_name,"size":[texture.get_width(),texture.get_height()],"mips":texture.has_mipmaps()})
		for variant in ["baseline","native-transform"]:
			if variant=="native-transform":
				for mat in materials:
					var shader:=Shader.new();shader.code=materials[mat].code.replace('#include "./mtoon_common.gdshaderinc"',fixed);mat.shader=shader
			for stage in ["ambient","sun","lamp","both"]:
				sun.light_energy=.25 if stage in ["sun","both"] else 0
				lamp.light_energy=1.5 if stage in ["lamp","both"] else 0
				for i in 12:await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+sample+"-"+variant+"-"+stage+".png")
				if stage=="ambient" and variant=="baseline":
					var translated:=root.get_texture().get_image()
					world.position=Vector3.ZERO
					for i in 12:await process_frame
					await RenderingServer.frame_post_draw
					var reference:=root.get_texture().get_image()
					reference.save_png(output+sample+"-origin-ambient.png")
					var delta:=translation_difference(reference,translated);translations.append(delta)
					if delta.changed_fraction>.03:failures.append(sample+": translation-dependent surface artifacts")
					world.position=Vector3(20,2,-60)
			# Identical small movement reveals depth sparkle while keeping the
			# comparison close enough to inspect the same clothing/hair patches.
			var frames: String=output+sample+"-"+variant+"/";DirAccess.make_dir_recursive_absolute(frames)
			for i in 48:
				camera.position.x=.04*sin(i*TAU/48);camera.look_at(world.to_global(Vector3(0,.87,0)))
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(frames+"%03d.png"%i)
			camera.position.x=0;camera.look_at(world.to_global(Vector3(0,.87,0)))
			for mat in materials:mat.shader=materials[mat]
		records.append({"model":sample,"geometry":geometry,"normal_maps":normals,"translation_comparisons":translations});print("SHIMMER_PROBE ",sample)
		avatar.queue_free();await process_frame
	FileAccess.open(output+"probe.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"depth_prepass":ProjectSettings.get_setting("rendering/driver/depth_prepass/enable"),"records":records,"failures":failures},"  "))
	world.queue_free();for i in 3:await process_frame
	print("SHIMMER_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
