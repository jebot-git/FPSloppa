extends SceneTree
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
var rigs: Array=[]
var output:="/tmp/cq-lod-benchmark"
var actor_count:=16
var map_name:=""
func _initialize() -> void:run.call_deferred()
func summary(values: Array) -> Dictionary:
	values.sort();var total:=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"p95":values[ceili(values.size()*.95)-1]}
func measure() -> Dictionary:
	await create_timer(2.1).timeout # Let shader work and the one-second monitor window settle.
	for frame in 120:await process_frame
	var cpu: Array=[];var gpu: Array=[];var render_cpu: Array=[];var primitives: Array=[];var draws: Array=[];var wall: Array=[]
	var last:=Time.get_ticks_usec()
	for frame in 300:
		await process_frame
		var now:=Time.get_ticks_usec();wall.append((now-last)/1000.0);last=now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return {"process_window_max_ms":summary(cpu),"gpu_ms":summary(gpu),"render_cpu_ms":summary(render_cpu),"wall_frame_ms":summary(wall),"primitives":summary(primitives),"draw_calls":summary(draws)}
func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size()>1:actor_count=int(OS.get_cmdline_user_args()[1])
	if OS.get_cmdline_user_args().size()>2:map_name=OS.get_cmdline_user_args()[2]
	if map_name not in ["","qsrc_dm6"]:push_error("Unsupported benchmark map");quit(2);return
	if actor_count<1 or actor_count>64:push_error("Use 1–64 render-only actors");quit(2);return
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.position=Vector3(0,2,30);camera.fov=85
	var environment:=WorldEnvironment.new();world.add_child(environment);environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.03,.04,.06)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-40,-25,0)
	var positions: Array[Vector3]=[]
	if map_name=="qsrc_dm6":
		light.free()
		positions=await preload("res://tools/avatar_lod/dm6_scene.gd").setup(self,world,camera,actor_count)
		if positions.size()!=actor_count:quit(2);return
	var library:=Library.new()
	for name_here in ["sample_d","sample_f","sample_g"]:library.entries[name_here]={"path":"res://vrm/"+name_here+".vrm"}
	for index in actor_count:
		var actor:=Node3D.new();world.add_child(actor);actor.position=Vector3((index%8-3.5)*2.2,0,-floori(index/8.0)*4)
		if not positions.is_empty():actor.position=positions[index]
		var rig=Loader.create_avatar(library,["sample_d","sample_f","sample_g"][index%3]);actor.add_child(rig)
		rig.set_weapon(2,"ut99");rig.speed=4;rig.movement=Vector3(0,0,-4);rigs.append(rig)
	var baseline:=await measure()
	for rig in rigs:rig.enable_distance_lod()
	var deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		var ready:=true
		for rig in rigs:
			ready=ready and (rig.distance_lod.using_generic or not map_name.is_empty())
			for mesh in rig.visual_meshes:ready=ready and mesh.mesh.get_meta("cq_mesh_lod","")=="ready"
		if ready:break
		await process_frame
	var optimized:=await measure()
	var enabled:=0
	var tiers: Dictionary={}
	for rig in rigs:
		if rig.distance_lod.using_generic:enabled+=1
		var tier: String=str(rig.distance_lod.tier);tiers[tier]=int(tiers.get(tier,0))+1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+".png")
	var report:={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"actors":actor_count,"generic_actors":enabled,"frames":300,"baseline":baseline,"lod":optimized,"scope":"%d rendered VRMs in eight-column rows starting at 30 m, four metres between rows; three shared models. Same scene/motion, baseline then LOD; no map/network or XR headset. Vsync disabled. Rendering stress only: district admission remains capped at 16. Wall-frame timing includes face/hair and skinning. process_window_max_ms samples Godot's one-second maximum monitor, NOT per-frame CPU durations."%actor_count}
	if not map_name.is_empty():
		report.map=map_name;report.tiers=tiers;report.positions=positions.map(func(p):return [p.x,p.y,p.z])
		report.scope="Q1DM6 baked BC7 scene with %d static-position moving-pose VRMs, three shared models. Clear placements sampled across camera-visible floors; natural near/mid/far LOD selection. Map geometry included, no gameplay/network or XR. 1440x900 Vulkan Mobile, vsync off; baseline then LOD. Render-only stress, district admission stays 16."%actor_count
	FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CQ_LOD_BENCHMARK ",JSON.stringify(report));world.free();library.free();quit(0 if enabled==actor_count or not map_name.is_empty() else 1)
