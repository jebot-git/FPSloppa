extends "res://tools/voxelspace/optimization.gd"
## Index-only candidates; same scene, triangles, poses and production avatar LOD.
var case_hash:=""
const IndexCache=preload("res://tools/meshoptimizer/index_cache.gd")
var preparation: Array=[]
func run() -> void:
	output="res://test-results/meshoptimizer/rendering"
	if DisplayServer.get_name()=="headless":quit(2);return
	root.size=Vector2i(1440,900);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	root.add_child(world);world.add_child(camera);camera.current=true;camera.fov=70;camera.near=.1;camera.far=300;camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.position=Vector3(0,5,60)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.38,.54,.65);world.add_child(environment)
	map.generate(output);switch_mode("baseline");library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.shadow_enabled=false;world.add_child(light)
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	for name in ["d","f","g"]:
		var original_hash:=FileAccess.get_sha256("res://vrm/sample_"+name+".vrm")
		library.visual_loader.prepare_avatar(library,original_hash,true)
		var candidate_hash: String=(original_hash+"index-cache-probe-v1").sha256_text()
		for variant in ["original","cache_only","cache_only","original"]:
			if variant=="cache_only" and not library.scenes.has(candidate_hash):
				# Copy after the first original case completes LOD generation. Both
				# variants retain the exact same LOD index buffers and ready metadata.
				var model: Node=library.scenes[original_hash].instantiate();var started:=Time.get_ticks_usec();var changes:=IndexCache.model(model)
				changes.model=name;changes.optimization_ms=(Time.get_ticks_usec()-started)/1000.0;preparation.append(changes)
				var packed:=PackedScene.new();packed.pack(model);model.free()
				library.entries[candidate_hash]=library.entries[original_hash].duplicate();library.remember_scene(candidate_hash,packed)
			case_hash=original_hash if variant=="original" else candidate_hash
			if case_hash.is_empty():push_error(library.last_error);quit(3);return
			spawn_avatars("")
			# Let the existing background LOD service finish outside timed frames.
			var lod_service=root.get_node_or_null("AvatarMeshLOD")
			if lod_service!=null:
				while lod_service.task>=0 or not lod_service.pending.is_empty():await process_frame
			await sample(name+"_"+variant+"_"+str(rows.size()),viewport);clear_avatars();await process_frame
	var result:={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"resolution":[1440,900],"renderer":RenderingServer.get_current_rendering_method(),"rows":rows,"preparation":preparation,"scope":"32 animated copies per bundled model; original/cache/cache/original, springs off, existing distance and mesh LOD. Identical map. Candidate copies retain completed original LOD buffers. Post-decode local scene candidates change only opaque/cutout base index buffers using Godot built-in meshoptimizer. No networking, combat or XR."}
	FileAccess.open(output+"/benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));clear_scene();world.free();await process_frame;await process_frame;quit()
func spawn_avatars(_sample: String) -> void:
	VRMSecondary.springs_enabled=false
	for i in 32:
		var rig=library.create_avatar(case_hash)
		if rig==null:push_error(library.last_error);quit(4);return
		var holder:=Node3D.new();world.add_child(holder);holder.add_child(rig);holder.position=Vector3((i%8-3.5)*2.0,map.BASE,48-floori(i/8.0)*2.0)
		rig.preview_mode=-1;rig.speed=9.4;rig.movement=Vector3.FORWARD*9.4;rig.enable_distance_lod();rig.secondary_motion_enabled=false
		for secondary in rig.secondary_nodes:secondary.local_body_disabled=true;secondary.update_native_state()
		rigs.append(rig)
