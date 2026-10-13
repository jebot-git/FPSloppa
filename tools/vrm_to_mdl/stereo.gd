extends "res://tools/voxel_battle/stereo_render.gd"
## Desktop stereo simulation: two perspective cameras, no XR runtime or AI.
const Models=preload("res://tools/vrm_to_mdl/model.gd")
const ACCEPTED=["sample_d_darkness","sample_e","sample_f","sample_g","hairsample_female","hairsample_male"]
var eyes: Array[SubViewport]=[]
var cameras: Array[Camera3D]=[]
var series: Dictionary={}
var csv: FileAccess
var instances: Array=[]
var animation_elapsed:=0.0
var info: Label
func _process(delta: float) -> bool:
	if not ready:return false
	animation_elapsed+=delta
	for instance in instances:
		instance.material.set_shader_parameter("animation_clock",animation_elapsed+instance.phase)
	map.update_view(cameras[0])
	if measured:
		elapsed+=delta
		var values:={"frame_ms":delta*1000,"stereo_gpu_ms":0.0,"stereo_render_cpu_ms":0.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"static_memory_mb":OS.get_static_memory_usage()/1048576.0}
		for eye in eyes:
			values.stereo_gpu_ms+=RenderingServer.viewport_get_measured_render_time_gpu(eye.get_viewport_rid())
			values.stereo_render_cpu_ms+=RenderingServer.viewport_get_measured_render_time_cpu(eye.get_viewport_rid())
		var row:=PackedStringArray([str(elapsed)])
		for key in values:
			if not series.has(key):series[key]=[]
			series[key].append(values[key]);row.append(str(values[key]))
		csv.store_csv_line(row)
		if series.frame_ms.size()%120==0:csv.flush()
		info.text="Simulated stereo · 32 animated MDLs · AI 0 · %.1f / %.0f seconds"%[elapsed,duration]
	return false
func run() -> void:
	output="res://test-results/mdl-stereo"
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--seconds" and i+1<args.size():duration=maxf(1,float(args[i+1]))
	DirAccess.make_dir_recursive_absolute(output)
	root.title="FPSloppa — 32 MDL avatars, simulated stereo"
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	root.add_child(crowd)
	var assets: Dictionary={}
	for name in ACCEPTED:assets[name]=Models.load_model("res://experimental-assets/mdl/"+name+".mdl")
	for i in 32:
		var name: String=ACCEPTED[i%ACCEPTED.size()]
		var source: Array=assets[name]
		var holder:=Holder.new();crowd.add_child(holder);holder.rotation.y=PI;crowd.fighters[i]=holder
		var mesh:=MeshInstance3D.new();holder.add_child(mesh);mesh.mesh=source[0];mesh.material_override=source[1].duplicate();mesh.custom_aabb=AABB(Vector3(-1,0,-1),Vector3(2,2,2))
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://experimental-assets/mdl/"+name+".json"))
		var clip: Dictionary=data.clips[i%3]
		var material: ShaderMaterial=mesh.material_override
		material.set_shader_parameter("clip_start",int(clip.start));material.set_shader_parameter("clip_count",int(clip.count));material.set_shader_parameter("clip_fps",float(clip.fps));material.set_shader_parameter("clip_loop",true)
		instances.append({"model":name,"clip":clip.name,"material":material,"phase":i*.137})
	map=Map.new();root.add_child(map);map.build(true)
	var env:=WorldEnvironment.new();root.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.53,.67,.75)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.48,.57,.7);env.environment.ambient_light_energy=.6
	var sun:=DirectionalLight3D.new();root.add_child(sun);sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.2;sun.shadow_enabled=false
	await physics_frame;await physics_frame
	point=choose_point()
	var view_position:=Vector3(point.x,Landscape.surface(point.x,point.z+10).x+1.7,point.z+10)
	var layer:=CanvasLayer.new();root.add_child(layer)
	for index in 2:
		var eye:=SubViewport.new();root.add_child(eye);eye.size=Vector2i(2160,2376);eye.world_3d=root.world_3d;eye.render_target_update_mode=SubViewport.UPDATE_ALWAYS;eye.msaa_3d=Viewport.MSAA_DISABLED
		var eye_camera:=Camera3D.new();eye.add_child(eye_camera);eye_camera.position=view_position+Vector3((index-.5)*.064,0,0);eye_camera.near=.08;eye_camera.far=1000;eye_camera.fov=90;eye_camera.current=true
		cameras.append(eye_camera);eyes.append(eye)
		var view:=TextureRect.new();layer.add_child(view);view.texture=eye.get_texture();view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;view.position=Vector2(index*720,0);view.size=Vector2(720,900)
		RenderingServer.viewport_set_measure_render_time(eye.get_viewport_rid(),true)
	info=Label.new();layer.add_child(info);info.position=Vector2(20,20);info.text="Streaming terrain and warming shaders…"
	ready=true
	var deadline:=Time.get_ticks_msec()+90000
	while not map.terrain.settled():
		if Time.get_ticks_msec()>deadline:push_error("MDL stereo warmup timed out");quit(1);return
		await process_frame
	for frame in 180:await process_frame
	var visible: Array=[]
	for eye_camera in cameras:
		var count:=0
		for holder in crowd.fighters.values():
			if eye_camera.is_position_in_frustum(holder.global_position+Vector3.UP*.85):count+=1
		visible.append(count)
	assert(visible==[32,32],"All 32 avatar centres must be in both eye frusta")
	csv=FileAccess.open(output+"/frames.csv",FileAccess.WRITE);csv.store_csv_line(PackedStringArray(["seconds","frame_ms","stereo_gpu_ms","stereo_render_cpu_ms","draw_calls","primitives","static_memory_mb"]))
	print("MDL_STEREO_READY avatars=32 visible=",visible," per_eye=2160x2376 IPD=0.064 AI=0")
	measured=true
	while elapsed<duration:await process_frame
	measured=false;csv.flush()
	var performance: Dictionary={}
	for key in series:performance[key]=Probe.summary(series[key])
	var models: Dictionary={};var clips: Dictionary={}
	for instance in instances:models[instance.model]=models.get(instance.model,0)+1;clips[instance.clip]=clips.get(instance.clip,0)+1
	var report:={"mode":"simulated stereo, independent camera viewports","engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"avatars":32,"models":models,"clips":clips,"per_eye_size":[2160,2376],"ipd_m":.064,"fov_degrees":90,"avatar_centers_in_each_frustum":visible,"point_m":[point.x,point.y,point.z],"seconds":elapsed,"ai_nodes":0,"skeletons":0,"springs":0,"tracking":false,"animation":"GPU vertex interpolation; independent per-instance phases","performance":performance,"limits":"Desktop two-pass stereo simulation, not native OpenXR multiview, runtime pacing, foveation or headset latency. Sum of measured eye viewport GPU times, including terrain and scenery; not avatar-only time."}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await RenderingServer.frame_post_draw
	for i in eyes.size():eyes[i].get_texture().get_image().save_png(output+("/left.png" if i==0 else "/right.png"))
	root.get_texture().get_image().save_png(output+"/preview.png")
	info.text="Completed simulated stereo test · 32 animated MDLs · GPU %.2f ms · frame %.2f ms"%[performance.stereo_gpu_ms.p50,performance.frame_ms.p50]
	print("MDL_STEREO_RESULT ",JSON.stringify(report))
	if not args.has("--keep-open"):ready=false;quit()
