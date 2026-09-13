extends SceneTree
## Isolated, repeatable renderer experiment. No hosts, bots or config writes.
const Filtering=preload("res://deathmatch/maps/filtering.gd")
var rows: Array=[]
var output: String
func _initialize():run.call_deferred()
func summary(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)]}
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("A real renderer is required");quit(1);return
	output="res://test-results/lighting/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false);game.hud.hide();game.voice.set_mode(0)
	game.presentation.texture_filter=2;game.presentation.contrast_lighting=false
	root.msaa_3d=Viewport.MSAA_4X;root.scaling_3d_scale=1.0
	var viewport:=root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	for map in ["tf_pressureworks","tf_vesper"]:
		var views: Array=[[Vector3(16.25,2.2,23.75),Vector3(0,5.6,-9.4),"turbine"],[Vector3(-15,1.88,-31.75),Vector3(0,2.5,-56),"hall"],[Vector3(-7.5,1.7,-51.25),Vector3(0,1.25,-55.5),"flag"]] if map=="tf_pressureworks" else [[Vector3(18,2.2,24),Vector3(-8,12,-28),"nave"],[Vector3(7,9.7,-50),Vector3(9.5,9.2,-58.5),"sanctuary"],[Vector3(2,1.8,-34),Vector3(14,13,-44),"lifts"]]
		for bake in ["baseline","candidate"]:
			var key: String=map+"-"+bake
			var path: String="res://test-results/lighting/"+key+".bsp"
			var hash:=FileAccess.get_sha256(path)
			game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"res://test-results/lighting/cache/"+hash+".scn","sha256":hash}]
			if not game._load_map(key):quit(1);return
			var level: Node=game.get_node("Map").get_child(0)
			assert(level.get_meta("baked_light_faces",0)>100)
			assert(level.get_meta("baked_light_invalid_faces",-1)==0 and level.get_meta("baked_light_overflow_faces",-1)==0)
			assert(level.get_meta("baked_light_rgb",false))
			game.match_mode.kind="tf";game.match_mode.reset();game.match_mode.draw_objectives()
			var camera: Camera3D=game.get_node("Overview");game.camera=camera
			game.get_node("Map").process_mode=Node.PROCESS_MODE_DISABLED
			for view in views:
				camera.position=view[0];camera.look_at(view[1]);camera.make_current()
				game.get_node("Map/MapRuntime")._process(1.0)
				for pass_index in 4:
					var mode: int=[0,1,1,0][pass_index]
					var begin:=Time.get_ticks_usec()
					var filter:=Filtering.new();filter.apply(level,2,false,mode)
					var switch_ms:=(Time.get_ticks_usec()-begin)/1000.0
					for i in 45:await process_frame
					var cpu: Array=[];var gpu: Array=[];var wall: Array=[];var draws: Array=[]
					var previous:=Time.get_ticks_usec()
					for i in 180:
						await process_frame
						var now:=Time.get_ticks_usec();wall.append((now-previous)/1000.0);previous=now
						cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
						gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
						draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
					var row:={"map":map,"bake":bake,"view":view[2],"contrast":mode==1,"pass":pass_index,"samples":180,"switch_ms":switch_ms,"cpu_ms":summary(cpu),"gpu_ms":summary(gpu),"frame_ms":summary(wall),"draw_calls":summary(draws),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"baked_faces":level.get_meta("baked_light_faces")}
					rows.append(row);print("LIGHTING_SAMPLE ",JSON.stringify(row))
					if pass_index<2:
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(output+"/"+key+"-"+view[2]+("-contrast" if mode else "-classic")+".png")
	var report:={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":[1280,800],"msaa":4,"vsync":false,"actors":0,"samples":rows}
	FileAccess.open(output+"/profile.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.queue_free()
	for i in 3:await process_frame
	quit()
