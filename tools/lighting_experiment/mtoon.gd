extends SceneTree
## Real VRMs in RGB/grayscale BSP scenes, plus isolated live-light response.
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const OUT="res://test-results/lighting-coverage/"
const KEYS=["_ArenaLightingEnabled","_ArenaFill","_ArenaDirect","_ArenaLightLimit"]
var failures: Array=[]
var records: Array=[]
var output: String
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func shot(label: String) -> Image:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image();picture.save_png(output+label+".png");return picture
func pixels(im: Image) -> Dictionary:
	var sum:=Vector3.ZERO;var count:=0;var clipped:=0
	for y in range(0,im.get_height(),2):
		for x in range(0,im.get_width(),2):
			var c:=im.get_pixel(x,y)
			if maxf(c.r,maxf(c.g,c.b))<.01:continue
			count+=1;sum+=Vector3(c.r,c.g,c.b)
			if minf(c.r,minf(c.g,c.b))>.96:clipped+=1
	var mean:=sum/maxi(count,1)
	return {"pixels":count,"rgb":[mean.x,mean.y,mean.z],"luma":mean.dot(Vector3(.2126,.7152,.0722)),"clipped_fraction":float(clipped)/maxi(1,count)}
func median(values: Array) -> float:
	values.sort();return values[values.size()/2]
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	output=OUT+"mtoon-"+RenderingServer.get_current_rendering_method()+"/"
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(800,800);root.content_scale_size=root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false);game.hud.hide();game.voice.set_mode(0)
	game.presentation.texture_filter=2;game.presentation.contrast_lighting=false
	root.msaa_3d=Viewport.MSAA_4X;root.scaling_3d_scale=1
	var library=preload("res://deathmatch/avatars/library.gd").new();root.add_child(library)
	var camera: Camera3D=game.get_node("Overview");game.camera=camera
	var environment: Environment=game.get_node("Environment").environment
	var isolated: Environment=environment.duplicate();isolated.background_mode=Environment.BG_COLOR;isolated.background_color=Color.BLACK
	var sun: DirectionalLight3D=game.get_node("DuskSun")
	var lamp:=OmniLight3D.new();lamp.omni_range=5;lamp.shadow_enabled=false;game.add_child(lamp)
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	for map in ["as_frigate","tf_vesper","external-optin"]:
		var path: String=OUT+"sources/"+map+".bsp"
		if map=="external-optin":path=OUT+map+".bsp"
		if map=="tf_vesper":path="res://test-results/lighting/tf_vesper-candidate.bsp"
		var hash:=FileAccess.get_sha256(path)
		game.match_mode.kind="dm";game.map_catalog=[{"id":map,"title":map,"path":path,"sha256":hash,"scene":OUT+"mtoon-cache/"+hash+".scn"}]
		check(game._load_map(map),map+": load")
		var level: Node=game.get_node("Map").get_child(0)
		check(level.get_meta("baked_light_faces",0)>0,map+": baked environment")
		for node in game.get_node("Map").find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
		await physics_frame;await physics_frame
		var origin: Vector3=game.spawn_points[0]
		var open:=Vector3.FORWARD;var reach:=-1.0
		for n in 24:
			var direction:=Vector3(sin(n*TAU/24),0,cos(n*TAU/24))
			var eye:=origin+Vector3.UP
			var ray: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye+direction*5,1))
			var distance: float=5.0 if ray.is_empty() else eye.distance_to(ray.position)
			if distance>reach:reach=distance;open=direction
		camera.position=origin+open*minf(3.0,maxf(1.0,reach-.4))+Vector3.UP
		camera.look_at(origin+Vector3.UP*.87);camera.fov=43;camera.make_current()
		game.get_node("Map/MapRuntime")._process(1.0)
		lamp.position=origin+open*1.5+Vector3.UP*1.3
		var map_lamps: Array=game.get_node("Map/MapRuntime").lights
		var lamp_visibility: Array=[]
		for light in map_lamps:lamp_visibility.append(light.visible)
		var hideable: Array=[]
		for node in game.find_children("*","GeometryInstance3D",true,false):
			if node.visible:hideable.append(node)
		for sample in ["sample_d","sample_f","sample_g"]:
			var avatar=library.create_avatar(FileAccess.get_sha256(library.Paths.folder("vrm")+sample+".vrm"))
			check(avatar!=null,sample+": load avatar")
			if not avatar:continue
			game.add_child(avatar);avatar.position=origin;avatar.rotation.y=PI+atan2(open.x,open.z)
			avatar.process_mode=Node.PROCESS_MODE_DISABLED
			if avatar.gun:avatar.gun.hide()
			if avatar.offhand_gun:avatar.offhand_gun.hide()
			Filtering.new().apply(avatar,2,true)
			var materials: Dictionary={}
			for mesh in avatar.visual_meshes:
				for i in mesh.mesh.get_surface_count():
					var mat: Material=mesh.get_active_material(i)
					if mat is ShaderMaterial and mat.get_shader_parameter("_ArenaLightingEnabled")==true:
						var values: Array=[mat.shader,mat.next_pass]
						for key in KEYS:values.append(mat.get_shader_parameter(key))
						materials[mat]=values
			check(not materials.is_empty(),sample+": MToon arena materials active")
			var natural: Array=[];var stages: Array=[]
			for mode in [0,1]:
				Filtering.new().apply(game,2,false,mode)
				for mat in materials:
					var values: Array=[mat.shader,mat.next_pass]
					for key in KEYS:values.append(mat.get_shader_parameter(key))
					check(values==materials[mat],sample+": map toggle leaves MToon shader/fill/direct/clamp/passes unchanged")
				for node in hideable:node.show()
				camera.environment=null;sun.light_energy=.25;lamp.light_energy=0
				for i in map_lamps.size():map_lamps[i].visible=lamp_visibility[i]
				var label: String=map+"-"+sample+("-contrast" if mode else "-classic")
				await shot(label+"-scene")
				var gpu: Array=[];var draws: Array=[]
				for i in 90:
					await process_frame;gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				natural.append({"gpu_ms":median(gpu),"draws":median(draws),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)})
				for node in hideable:node.hide()
				camera.environment=isolated
				for light in map_lamps:light.hide()
				var response: Dictionary={}
				for stage in ["dim","warm","cool","flash"]:
					isolated.ambient_light_energy=.02 if stage=="dim" else .15
					sun.light_energy=0 if stage=="dim" else .1
					lamp.light_energy=0 if stage=="dim" else 8 if stage=="flash" else 2
					lamp.light_color=Color(1,.12,.04) if stage=="warm" else Color(.05,.2,1) if stage=="cool" else Color.WHITE
					response[stage]=pixels(await shot(label+"-"+stage))
				check(response.dim.pixels>1500 and response.dim.luma>.04,label+": readable dim silhouette")
				check(response.flash.luma>response.dim.luma and response.flash.clipped_fraction<.03,label+": bounded flash response")
				check(response.warm.rgb[0]-response.warm.rgb[2]>response.cool.rgb[0]-response.cool.rgb[2]+.025,label+": warm/cool response")
				stages.append(response)
			check(natural[0].draws==natural[1].draws and natural[0].texture_bytes==natural[1].texture_bytes,map+sample+": no extra draws or textures")
			for stage in stages[0]:check(absf(stages[0][stage].luma-stages[1][stage].luma)<.002,map+sample+stage+": avatar illumination independent of map contrast")
			records.append({"map":map,"model":sample,"mtoon_materials":materials.size(),"natural":natural,"stages":stages})
			print("MTOON_COVERAGE ",map," ",sample)
			avatar.queue_free();await process_frame
		for node in hideable:node.show()
		camera.environment=null
	FileAccess.open(output+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"records":records,"failures":failures},"  "))
	game.queue_free();library.queue_free();for i in 3:await process_frame
	print("MTOON_COVERAGE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
