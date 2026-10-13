extends SceneTree
const Preview=preload("res://tools/voxel_battle/jungle_preview.gd")
const Probe=preload("res://tools/voxel_battle/performance.gd")
var scene
var eyes: Array=[]
var ready:=false
var measuring:=false
var label:=""
var elapsed:=0.0
var probe:=Probe.new()
var counts: Dictionary={}
var output:="res://test-results/jungle-foliage"
var seconds:=15.0
var modes: Array=["mesh","billboard","svo","hybrid"]
var selected_views:Array=[]
var grass_test:=false
var grass_distances:Array=[24,64,96,144]
var phase_time:=0.0
var base_camera:=Transform3D.IDENTITY
var eye_height:=1.7
func _initialize() -> void:run.call_deferred()
func _process(delta: float) -> bool:
	if not ready:return false
	if grass_test:
		phase_time+=delta
		var p:=base_camera.origin+Vector3(sin(phase_time*TAU/5)*2,0,0)
		p.y=scene.Landscape.surface(p.x,p.z).x+eye_height
		scene.camera.global_transform=Transform3D(base_camera.basis*Basis(Vector3.UP,sin(phase_time*TAU/5)*.04),p)
	scene.map.update_view(scene.camera)
	for i in 2:eyes[i].get_child(0).global_transform=scene.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3((i-.5)*.064,0,0))
	if measuring:
		elapsed+=delta;probe.record(delta,root.get_viewport_rid(),scene.map,elapsed,label)
		if not counts.has(label):counts[label]={"visible":[],"resident":[],"triangles":[],"grass_visible":[],"grass_draws":[],"grass_triangles":[],"grass_update_ms":[],"grass_refresh_ms":[],"grass_max_distance":[],"grass_far":[]}
		counts[label].visible.append(scene.map.environment.visible_features);counts[label].resident.append(scene.map.environment.resident_features);counts[label].triangles.append(scene.map.environment.triangles)
		counts[label].grass_max_distance.append(scene.map.grass.max_submitted_distance);counts[label].grass_far.append(scene.map.grass.counts[2]+scene.map.grass.counts[5]+scene.map.grass.counts[8]+scene.map.grass.counts[11])
		counts[label].grass_visible.append(scene.map.grass.visible_tufts);counts[label].grass_draws.append(scene.map.grass.draw_calls);counts[label].grass_triangles.append(scene.map.grass.triangles)
		counts[label].grass_update_ms.append(scene.map.grass.update_ms)
		if scene.map.grass.update_ms>0:counts[label].grass_refresh_ms.append(scene.map.grass.update_ms)
	return false
func run() -> void:
	for i in OS.get_cmdline_user_args().size():
		var args:=OS.get_cmdline_user_args()
		if args[i]=="--seconds":seconds=float(args[i+1])
		if args[i]=="--output":output=args[i+1]
		if args[i]=="--modes":modes=Array(args[i+1].split(","))
		if args[i]=="--grass-test":grass_test=true
		if args[i]=="--views":
			for value in args[i+1].split(","):selected_views.append(int(value))
		if args[i]=="--grass-distances":grass_distances=Array(args[i+1].split(",")).map(func(v):return float(v))
	if DisplayServer.get_name()=="headless":push_error("Requires Vulkan rendering");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1440,900);root.disable_3d=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	scene=load("res://tools/voxel_battle/jungle_preview.tscn").instantiate();scene.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;scene.benchmarks=true;root.add_child(scene);scene.panel.visible=false;scene.camera.fov=94
	for i in 2:
		var eye:=SubViewport.new();eye.size=Vector2i(2160,2376);eye.world_3d=scene.get_world_3d();eye.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(eye)
		var camera:=Camera3D.new();camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.fov=92;camera.far=2200;camera.current=true;eye.add_child(camera);eyes.append(eye)
		var image:=TextureRect.new();image.texture=eye.get_texture();image.position=Vector2(i*720,0);image.size=Vector2(720,900);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;root.add_child(image)
		probe.measured_viewports.append(eye.get_viewport_rid())
	probe.setup(output,root.get_viewport_rid());ready=true
	for view in (selected_views if not selected_views.is_empty() else range(4 if grass_test else 3)):
		scene.set_view(view)
		eye_height=scene.points[view].get("eye_height",1.7)
		if not grass_test:scene.camera.position.y+=5.3 # Preserve original foliage-test camera height.
		base_camera=scene.camera.global_transform;phase_time=0
		var start:=Time.get_ticks_msec()
		await process_frame
		while not scene.map.terrain.settled():
			await process_frame
			if Time.get_ticks_msec()-start>120000:push_error("Streaming did not settle");quit(1);return
		var cases:Array=["off"] if grass_test else modes
		if grass_test:
			for distance in grass_distances:cases.append("hybrid-%dm"%distance)
		for mode in cases:
			scene.map.environment.set_mode("hybrid" if grass_test else mode)
			scene.map.grass.set_enabled(grass_test and mode!="off")
			if grass_test and mode!="off":scene.map.grass.set_distance(float(mode.trim_prefix("hybrid-").trim_suffix("m")))
			phase_time=0;label="%s/%s"%[scene.points[view].name,mode]
			await create_timer(6 if grass_test else 3).timeout
			phase_time=0
			measuring=true;await create_timer(seconds).timeout;measuring=false
			await RenderingServer.frame_post_draw
			eyes[0].get_texture().get_image().save_png(output+"/%d-%s.png"%[view,mode])
			print("Measured "+label)
	var result:=probe.result()
	for key in counts:
		result.by_view[key].visible_features=Probe.summary(counts[key].visible)
		result.by_view[key].resident_features=Probe.summary(counts[key].resident)
		result.by_view[key].foliage_triangles=Probe.summary(counts[key].triangles)
		for metric in ["grass_visible","grass_draws","grass_triangles","grass_update_ms","grass_refresh_ms","grass_max_distance","grass_far"]:result.by_view[key][metric]=Probe.summary(counts[key][metric])
	result.modes=["hybrid"] if grass_test else modes
	result.hardware=RenderingServer.get_video_adapter_name();result.renderer=RenderingServer.get_current_rendering_method();result.driver=RenderingServer.get_current_rendering_driver_name();result.stereo={"eyes":2,"eye_size":[2160,2376],"ipd_m":.064,"type":"simulated independent eye viewports"}
	result.svo=scene.map.environment.svo_stats
	result.svo_asset_streaming={"uploads":scene.map.environment.svo_uploads,"evictions":scene.map.environment.svo_evictions,"resident_bytes_at_end":scene.map.environment.svo_resident_bytes,"peak_uploads_per_frame":scene.map.environment.peak_svo_uploads_per_frame}
	result.streaming={"capacity":scene.map.terrain.CAPACITY,"peak_resident":scene.map.terrain.peak_resident,"peak_jobs":scene.map.terrain.peak_jobs,"evicted":scene.map.terrain.evicted_total,"generation_ms":Probe.summary(scene.map.terrain.generation_times),"uploads_ms":Probe.summary(scene.map.terrain.upload_times)}
	result.scope="Hybrid trees held constant; waist-high canopy and large bushes, near/mid meshes and far cutout cards, at matched render distances. Matched 5-second, ±2 m walking/yaw sweep at 1.7 m standing / 0.45 m prone height, shared terrain, no AI/physics/avatars, six-second warmups and screenshots excluded." if grass_test else "Foliage renderer comparison; identical shared terrain, sites, seeded instances, frustum and LOD policy. No physics, AI or avatars. Stationary, settled views, shader warmups and screenshots excluded."
	result.grass={"modes":["off"]+grass_distances if grass_test else ["off"],"tested":grass_test,"capacity_total":scene.map.grass.CAPACITY,"tested_distances_m":grass_distances,"refresh_hz":30,"max_draws_per_eye":12,"peak_resident_tufts":scene.map.grass.peak_resident_tufts,"refreshes":scene.map.grass.refreshes}
	var file:=FileAccess.open(output+"/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	scene.map.terrain.shutdown();quit()
