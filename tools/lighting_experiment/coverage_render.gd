extends SceneTree
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const OUT="res://test-results/lighting-coverage/"
var records: Array=[]
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func stats(values: Array) -> Dictionary:
	values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)]}
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"input.json"))
	var output: String=OUT+RenderingServer.get_current_rendering_method()+"/"
	var args:=OS.get_cmdline_user_args();var only_index:=args.find("--only-map")
	if "--depth-prepass" in args:output=output.trim_suffix("/")+"-prepass-"+args[args.find("--depth-prepass")+1]+"/"
	DirAccess.make_dir_recursive_absolute(output)
	var only:=args[only_index+1].split(",") if only_index>=0 else PackedStringArray()
	if not only.is_empty() and FileAccess.file_exists(output+"render.json"):
		var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output+"render.json"))
		records=prior.records.filter(func(r):return r.id not in only)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false);game.hud.hide();game.voice.set_mode(0)
	game.presentation.texture_filter=2;game.presentation.contrast_lighting=true
	root.msaa_3d=Viewport.MSAA_4X;root.scaling_3d_scale=1.0
	var viewport:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
	for row in input.rows:
		if not only.is_empty() and row.id not in only:continue
		var map_row: Dictionary=row.duplicate();map_row.scene=OUT+"render-cache/"+row.id+".scn";map_row.title=row.id
		game.match_mode.kind="dm";game.map_catalog=[map_row]
		check(game._load_map(row.id),row.id+": game map load")
		if game.current_map!=row.id:continue
		var level: Node=game.get_node("Map").get_child(0)
		var initial:=Filtering.new();initial.apply(level,2,false)
		for mat in initial.materials:
			if mat is ShaderMaterial and mat.shader==Filtering.BAKED:check(mat.get_shader_parameter("contrast_lighting")==true,row.id+": map change inherits saved setting")
		# Disable callbacks individually: PROCESS_MODE_DISABLED removes collider
		# bodies from the physics space and makes every view-selection ray miss.
		for node in game.get_node("Map").find_children("*","Node",true,false):
			node.set_process(false);node.set_physics_process(false)
		var camera: Camera3D=game.get_node("Overview");game.camera=camera
		await physics_frame;await physics_frame
		var usable: Array=[]
		for point in game.spawn_points:
			var eye: Vector3=point+Vector3.UP*1.48
			if game.get_node("Map/MapRuntime").contents.at(eye)==-2:continue
			var floor_hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye-Vector3.UP*64,1))
			if not floor_hit.is_empty():usable.append(point)
		check(usable.size()>=2,row.id+": two usable camera positions")
		if usable.size()<2:continue
		var first: Vector3=usable[0]
		var farthest: Vector3=first
		for point in usable:
			if point.distance_squared_to(first)>farthest.distance_squared_to(first):farthest=point
		for view in 2:
			camera.position=(first if view==0 else farthest)+Vector3.UP*1.48
			var best:=Vector3.FORWARD;var distance:=-1.0
			for n in 24:
				var direction:=Vector3(sin(n*TAU/24),-.12,cos(n*TAU/24)).normalized()
				var ray: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.position,camera.position+direction*40,1))
				# A miss may point out through the sky boundary; prefer actual
				# surfaces so open maps do not get a sky-only lighting comparison.
				var reach: float=-1.0 if ray.is_empty() else camera.position.distance_to(ray.position)
				if reach>distance:distance=reach;best=direction
			camera.look_at(camera.position+best*20);camera.make_current()
			game.get_node("Map/MapRuntime")._process(1.0)
			for pass_index in 4:
				var mode: int=[0,1,1,0][pass_index]
				var filter:=Filtering.new();filter.apply(level,2,false,mode)
				for i in 40:await process_frame
				var cpu: Array=[];var gpu: Array=[];var draws: Array=[];var textures: Array=[]
				for i in 120:
					await process_frame
					cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
					draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
					textures.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
				var sample:={"id":row.id,"view":view,"pass":pass_index,"contrast":mode==1,"expected_baked":row.expected_baked,"cpu_ms":stats(cpu),"gpu_ms":stats(gpu),"draws":stats(draws),"texture_bytes":stats(textures),"camera":[camera.position.x,camera.position.y,camera.position.z],"look":[best.x,best.y,best.z],"clearance":distance,"baked_faces":level.get_meta("baked_light_faces",0)}
				records.append(sample)
				if pass_index in [0,1,3]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output+row.id+"-"+str(view)+"-"+["classic","contrast","unused","restored"][pass_index]+".png")
			print("COVERAGE_RENDER ",row.id," view=",view)
	var result:={"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"measured_frames_per_block":120,"records":records,"failures":failures}
	result["depth_prepass"]=ProjectSettings.get_setting("rendering/driver/depth_prepass/enable")
	FileAccess.open(output+"render.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	game.queue_free();for i in 3:await process_frame
	print("COVERAGE_RENDER_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
