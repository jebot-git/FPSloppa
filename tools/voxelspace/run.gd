extends SceneTree
const FactoryMap=preload("res://tools/voxelspace/factory_map.gd")
const PatchTerrain=preload("res://tools/voxelspace/patch_terrain.gd")
const ColumnRenderer=preload("res://tools/voxelspace/column_renderer.gd")
var map:=FactoryMap.new()
var world:=Node3D.new()
var scene: Node3D
var camera:=Camera3D.new()
var renderer
var patch
var raster: MeshInstance3D
var factory: MeshInstance3D
var rows: Array=[]
var output:="res://test-results/voxelspace"
var interactive:=false
var mode:="patch_lod"
var quality:=1.0
var hud: Label
var mouse_held:=false
var started_usec:=0
var setup_times: Dictionary={}
var library
var rigs: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Rendering benchmark requires Vulkan");quit(2);return
	interactive=OS.get_cmdline_user_args().has("--interactive")
	root.size=Vector2i(1440,900);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	root.add_child(world);world.add_child(camera);camera.current=true;camera.fov=70;camera.near=.1;camera.far=300
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.38,.54,.65);world.add_child(environment)
	var time:=Time.get_ticks_usec();map.generate(output);setup_times.map_generation_ms=(Time.get_ticks_usec()-time)/1000.0
	time=Time.get_ticks_usec();raster=map.raster_terrain();setup_times.raster_mesh_ms=(Time.get_ticks_usec()-time)/1000.0
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	camera.position=Vector3(0,10,68)
	if OS.get_cmdline_user_args().has("--visual-smoke"):
		camera.position=Vector3(66,14,68);camera.rotation.y=deg_to_rad(44)
		for variant in ["raster_full","patch_lod"]:
			await select(variant)
			for i in 60:await process_frame
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/"+variant+"_diagonal_smoke.png")
		clear_scene();raster.free();world.free();await process_frame;quit();return
	if interactive:
		hud=Label.new();hud.position=Vector2(20,20);hud.add_theme_font_size_override("font_size",18);root.add_child(hud);switch_mode("patch_lod");return
	for variant in ["raster_full","patch_lod","columns_solid","columns_hybrid","columns_hybrid_half","columns_hybrid_quarter"]:
		await select(variant)
		await measure(variant+"_front",viewport)
	# Reverse order reduces simple clock/thermal/order bias.
	for variant in ["columns_hybrid","patch_lod","raster_full"]:
		await select(variant);await measure(variant+"_front_repeat",viewport)
	camera.position=Vector3(66,14,68);camera.rotation.y=deg_to_rad(44)
	for variant in ["raster_full","patch_lod","columns_hybrid","columns_solid"]:
		await select(variant);await measure(variant+"_diagonal",viewport)
	camera.position=Vector3(0,8,5);camera.rotation.y=0
	for variant in ["patch_lod","columns_hybrid"]:
		await select(variant);await measure(variant+"_interior_storey2",viewport)
	for variant in ["raster_full","patch_lod","columns_hybrid"]:
		await select(variant);await measure(variant+"_flyby",viewport)
	# Matched map and moving/animated bundled-avatar loads at the 32-player target.
	camera.position=Vector3(0,5,60);camera.rotation=Vector3.ZERO
	for variant in ["raster_full","patch_lod","columns_hybrid"]:
		await select(variant);await measure(variant+"_avatar_camera_map_only",viewport)
	library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.shadow_enabled=false;world.add_child(light)
	for sample in ["sample_d","sample_f","sample_g"]:
		spawn_avatars(sample)
		for variant in ["raster_full","patch_lod","columns_hybrid"]:
			await select(variant);await measure(variant+"_32_"+sample,viewport)
		clear_avatars()
	# The BSP presentation mutates environment settings: keep this separate-content
	# context case last so it cannot change factory lighting or fog.
	clear_scene();camera.position=Vector3(0,3,12);camera.look_at(Vector3(0,1,-3))
	scene=load("res://maps/CampaignDistricts/district_40/presentation.scn").instantiate();world.add_child(scene);preload("res://deathmatch/conquest/presentation.gd").apply(world)
	await measure("existing_bsp_district40_context",viewport)
	var report:={"date":"2026-10-12","cpu":OS.get_processor_name(),"opennova_reference_commit":"a092ba28f3c7a729520f4d5014cfd6f5fed348b5","districts_base_commit":"9a3e9c8","engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"output_resolution":[1440,900],"map":map.metadata,"setup_times":setup_times,"rows":rows,"scope":"Generated factory terrain, static and deterministic moving camera; 32 animated copies per bundled VRM with springs off and production distance LOD. Matched raster/patch/column-hybrid input and factory geometry; BSP is a different-content context case. Mono, no networking/combat/XR; columns support yaw-only cameras."}
	FileAccess.open(output+"/rendering.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	clear_scene();raster.free();raster=null;world.free();await process_frame;await process_frame;quit()
func clear_scene() -> void:
	if is_instance_valid(scene):scene.free()
	scene=null;renderer=null;patch=null;factory=null
func switch_mode(variant: String) -> void:
	clear_scene();mode=variant;scene=Node3D.new();world.add_child(scene)
	if variant=="raster_full":
		var instance:=MeshInstance3D.new();instance.mesh=raster.mesh;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;scene.add_child(instance)
	elif variant=="patch_lod":
		patch=PatchTerrain.new();scene.add_child(patch);patch.setup(map);patch.update(camera)
	else:
		renderer=ColumnRenderer.new();scene.add_child(renderer)
		var scale:=.5 if variant.ends_with("half") else .25 if variant.ends_with("quarter") else quality
		renderer.setup(map,variant=="columns_solid",Vector2i(1440*scale,900*scale))
	if variant!="columns_solid":factory=map.factory_node();scene.add_child(factory)
func select(variant: String) -> void:
	var before:=Time.get_ticks_usec();switch_mode(variant)
	if renderer!=null:
		var deadline:=Time.get_ticks_msec()+15000
		while not renderer.ready_gpu and renderer.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
		if not renderer.ready_gpu:push_error(renderer.failure);quit(3);return
	setup_times[variant+"_ms"]=(Time.get_ticks_usec()-before)/1000.0
static func summary(values: Array) -> Dictionary:
	values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)]}
func measure(label: String,viewport: RID) -> void:
	for i in 120:
		if label.ends_with("flyby"):flyby(i)
		await process_frame
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/"+label+".png")
	var frame: Array=[];var gpu: Array=[];var cpu: Array=[];var compute: Array=[];var dispatch: Array=[];var draw_calls: Array=[];var primitives: Array=[]
	var previous:=Time.get_ticks_usec()
	for i in 360:
		if label.ends_with("flyby"):flyby(i)
		await process_frame
		var now:=Time.get_ticks_usec();frame.append((now-previous)/1000.0);previous=now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		compute.append(renderer.compute_gpu_ms if renderer!=null else 0);dispatch.append(renderer.dispatch_cpu_ms if renderer!=null else 0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var missed:=0
	for value in frame:
		if value>1000.0/60:missed+=1
	var row:={"case":label,"frames_over_60fps_budget_percent":missed*100.0/frame.size(),"samples":360,"frame_ms":summary(frame),"viewport_gpu_ms":summary(gpu),"render_cpu_ms":summary(cpu),"column_compute_gpu_ms":summary(compute),"column_dispatch_cpu_ms":summary(dispatch),"draw_calls":summary(draw_calls),"primitives":summary(primitives),"internal_resolution":[renderer.resolution.x,renderer.resolution.y] if renderer!=null else [1440,900],"lod_patch_counts":patch.counts if patch!=null else [],"lod_triangles":patch.triangles if patch!=null else 0}
	rows.append(row);print("VOXEL_FACTORY_RESULT ",JSON.stringify(row))
func flyby(frame: int) -> void:
	var phase:=float(frame)/360.0*TAU
	camera.position=Vector3(sin(phase)*55,10,68+cos(phase)*12)
	camera.rotation=Vector3(0,atan2(camera.position.x,camera.position.z),0)
func clear_avatars() -> void:
	for rig in rigs:rig.get_parent().free()
	rigs.clear()
func spawn_avatars(sample: String) -> void:
	VRMSecondary.springs_enabled=false
	var hash:=FileAccess.get_sha256("res://vrm/"+sample+".vrm")
	for i in 32:
		var rig=library.create_avatar(hash)
		if rig==null:push_error(library.last_error);quit(4);return
		var holder:=Node3D.new();world.add_child(holder);holder.add_child(rig)
		holder.position=Vector3((i%8-3.5)*2.0,map.BASE,48-floori(i/8.0)*2.0)
		rig.preview_mode=-1;rig.speed=9.4;rig.movement=Vector3.FORWARD*9.4;rig.enable_distance_lod()
		rig.secondary_motion_enabled=false
		for secondary in rig.secondary_nodes:secondary.local_body_disabled=true;secondary.update_native_state()
		rigs.append(rig)
func _process(delta: float) -> bool:
	if patch!=null:patch.update(camera)
	if renderer!=null:renderer.draw(camera)
	if interactive:
		var move:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		camera.position+=camera.basis*move*delta*18
		if hud:hud.text="FACTORY / "+mode+"\nWASD fly · Q/E height · hold RMB to turn · 1 mesh / 2 LOD / 3 classic solid / 4 classic hybrid\n%.1f FPS · yaw-only classic columns · hollow factory geometry in hybrid"%Engine.get_frames_per_second()
	return false
func _input(event: InputEvent) -> void:
	if not interactive:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:mouse_held=event.pressed
	if event is InputEventMouseMotion and mouse_held:camera.rotation.y-=event.relative.x*.004
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:switch_mode("raster_full")
			KEY_2:switch_mode("patch_lod")
			KEY_3:switch_mode("columns_solid")
			KEY_4:switch_mode("columns_hybrid")
			KEY_ESCAPE:quit()
