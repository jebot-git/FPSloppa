extends SceneTree
## Diagnostic only: fixed camera, no network, 32 remote rigs as a conservative
## client load. Compare maps, placeholder bodies, VRM rendering and springs.
var world: Node3D
var camera: Camera3D
var library
var rows: Array=[]
var rigs: Array=[]
var output_dir:="res://test-results/district-performance/after-main"
var level: Node3D
var viewport: RID
func _initialize() -> void:run.call_deferred()
func summary(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)]}
func measure(label: String, warmup: int=90, samples: int=240) -> void:
	for i in warmup:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir+"/"+label+".png")
	var frame: Array=[];var cpu: Array=[];var gpu: Array=[];var draws: Array=[]
	var previous:=Time.get_ticks_usec()
	for i in samples:
		await process_frame
		var now:=Time.get_ticks_usec();frame.append((now-previous)/1000.0);previous=now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var row:={"case":label,"frames":samples,"frame_ms":summary(frame),"render_cpu_ms":summary(cpu),"gpu_ms":summary(gpu),"draws":summary(draws)}
	rows.append(row);print("DISTRICT_PERFORMANCE ",JSON.stringify(row))
func clear_rigs() -> void:
	for rig in rigs:rig.get_parent().free()
	rigs.clear()
func spawn(hash: String,count: int) -> bool:
	clear_rigs()
	VRMSecondary.springs_enabled=true
	for i in count:
		var rig=library.create_avatar(hash)
		if rig==null:push_error(library.last_error);return false
		var holder:=Node3D.new();world.add_child(holder);holder.add_child(rig)
		holder.position=Vector3((i%8-3.5)*1.4,0,-floori(i/8.0)*2.0)
		rig.preview_mode=2;rig.enable_distance_lod();rigs.append(rig)
	springs(true)
	return true
func springs(enabled: bool) -> void:
	VRMSecondary.springs_enabled=enabled
	for rig in rigs:
		rig.secondary_motion_enabled=enabled
		for secondary in rig.secondary_nodes:
			secondary.local_body_disabled=not enabled
			secondary.update_native_state()
func freeze(node: Node) -> void:
	node.process_mode=Node.PROCESS_MODE_DISABLED
	if node is SkeletonModifier3D:node.active=false
	for child in node.get_children(true):freeze(child)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	VRMSecondary.springs_enabled=true
	if DisplayServer.get_name()=="headless":push_error("Real renderer required");quit(2);return
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	world=Node3D.new();root.add_child(world)
	camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,3.0,12);camera.look_at(Vector3(0,1,-3));camera.make_current()
	library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	viewport=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	if OS.get_cmdline_user_args().has("--scaling"):
		await scaling();return
	await measure("empty")
	for map_id in [0,13,40]:
		level=load("res://maps/CampaignDistricts/district_%02d/presentation.scn"%map_id).instantiate();world.add_child(level)
		preload("res://deathmatch/conquest/presentation.gd").apply(world)
		await measure("map_%02d_only"%map_id)
		level.free()
	var avatar_stats: Array=[]
	for sample in ["sample_d","sample_f","sample_g"]:
		var hash:=FileAccess.get_sha256("res://vrm/"+sample+".vrm")
		if not spawn(hash,32):quit(3);return
		var rig=rigs[0];var vertices:=0;var surfaces:=0;var joints:=0;var colliders:=0
		for mesh in rig.visual_meshes:
			if not mesh.visible:continue
			surfaces+=mesh.mesh.get_surface_count()
			for s in mesh.mesh.get_surface_count():vertices+=mesh.mesh.surface_get_array_len(s)
		for secondary in rig.secondary_nodes:
			for spring in secondary.spring_bones_internal:joints+=spring.verlets.size()
			colliders+=secondary.colliders_internal.size()
		avatar_stats.append({"sample":sample,"bones":rig.skeleton.get_bone_count(),"vertices":vertices,"surfaces":surfaces,"spring_joints":joints,"colliders":colliders,"native_spring_settings":rig.secondary_nodes[0].spring_chain_count() if not rig.secondary_nodes.is_empty() else 0})
		await measure(sample+"_32_empty_full")
		level=load("res://maps/CampaignDistricts/district_40/presentation.scn").instantiate();world.add_child(level)
		preload("res://deathmatch/conquest/presentation.gd").apply(world)
		for repeat in 2:
			for enabled in ([true,false] if repeat==0 else [false,true]):
				springs(enabled);await measure(sample+"_32_map40_"+("full" if enabled else "no_springs")+"_r"+str(repeat))
		springs(false)
		for item in rigs:freeze(item)
		await measure(sample+"_32_map40_frozen")
		for item in rigs:
			item.process_mode=Node.PROCESS_MODE_INHERIT
		clear_rigs()
		if not spawn(hash,32):quit(3);return
		for item in rigs:item.preview_mode=-1;item.speed=9.4;item.movement=Vector3.FORWARD*9.4
		springs(false);await measure(sample+"_32_map40_production_lod")
		clear_rigs();level.free()
	var report:={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1440,900],"remote_rigs":32,"msaa":root.msaa_3d,"avatar_stats":avatar_stats,"rows":rows,"scope":"Fixed desktop camera, no networking/combat, shared copies of each bundled VRM; not a headset or unique-avatar certification."}
	FileAccess.open(output_dir+"/client.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
func scaling() -> void:
	var hash:=FileAccess.get_sha256("res://vrm/sample_d.vrm")
	level=load("res://maps/CampaignDistricts/district_40/presentation.scn").instantiate();world.add_child(level)
	for count in [8,16]:
		if not spawn(hash,count):quit(3);return
		for enabled in [true,false]:
			springs(enabled);await measure("sample_d_"+str(count)+"_map40_"+("full" if enabled else "no_springs"))
	clear_rigs();level.free()
	if not spawn(hash,32):quit(3);return
	for rig in rigs:rig.get_parent().position.z-=100
	await measure("sample_d_32_beyond65m_full")
	springs(false);await measure("sample_d_32_beyond65m_no_springs")
	for rig in rigs:freeze(rig)
	await measure("sample_d_32_beyond65m_frozen")
	clear_rigs()
	if not spawn(hash,32):quit(3);return
	for rig in rigs:
		rig.get_parent().position.z-=100
		rig.preview_mode=-1;rig.speed=9.4;rig.movement=Vector3.FORWARD*9.4
	springs(false);await measure("sample_d_32_beyond65m_production_lod")
	FileAccess.open(output_dir+"/scaling.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows},"  "))
	quit()
