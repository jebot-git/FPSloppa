extends RefCounted
## Matched frozen scene: isolate rendering from varying bot combat.
const OUT="res://test-results/km-benchmark/"
static func stats(values: Array) -> Dictionary:
	values.sort();return {"mean":values.reduce(func(a,b):return a+b,0.0)/values.size(),"p50":values[values.size()/2],"p95":values[int(values.size()*.95)]}
static func run(tree: SceneTree,game,camera: Camera3D) -> void:
	game.process_mode=Node.PROCESS_MODE_DISABLED
	var root:=tree.root;root.use_occlusion_culling=false
	var zone_root: Node=game.get_node("Map").get_child(0)
	var zone_meshes:=zone_root.find_children("*","MeshInstance3D",true,false)
	var zone_occluders:=zone_root.find_children("*","OccluderInstance3D",true,false)
	var original: Node=load("res://maps/Benchmark1km/baseline-lightmap1.scn").instantiate()
	var baseline:=Node3D.new();game.add_child(baseline)
	for node in original.find_children("*","MeshInstance3D",true,false):node.reparent(baseline,false)
	original.free();baseline.hide()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var views: Array=[{"name":"district","eye":Vector3(-395,2,-395),"target":Vector3(-320,6,-315)},{"name":"gate","eye":Vector3(-395,2,-375),"target":Vector3(100,2,-375)},{"name":"overview","eye":Vector3(0,68,0),"target":Vector3(440,0,440)}]
	var results: Array=[]
	for view in views:
		camera.position=view.eye;camera.look_at(view.target);camera.reset_physics_interpolation()
		for mode in ["original","zones_off","zones_on"]:
			baseline.visible=mode=="original"
			for node in zone_meshes:node.visible=mode!="original"
			for node in zone_occluders:node.visible=mode=="zones_on"
			root.use_occlusion_culling=mode=="zones_on"
			for frame in 90:await tree.process_frame
			var intervals: Array=[];var cpu: Array=[];var gpu: Array=[];var draws: Array=[];var primitives: Array=[];var last:=Time.get_ticks_usec()
			for frame in 240:
				await tree.process_frame
				var now:=Time.get_ticks_usec();intervals.append((now-last)/1000.0);last=now
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			RenderingServer.force_draw(false);root.get_texture().get_image().save_png(OUT+view.name+"-"+mode+".png")
			var row: Dictionary={"view":view.name,"mode":mode,"frame_ms":stats(intervals),"render_cpu_ms":stats(cpu),"render_gpu_ms":stats(gpu),"draw_calls":stats(draws),"primitives":stats(primitives)};results.append(row);print("KM_RENDER ",JSON.stringify(row))
	FileAccess.open(OUT+"render-comparison.json",FileAccess.WRITE).store_string(JSON.stringify({"resolution":[root.size.x,root.size.y],"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"bots":game.players.size(),"method":"Frozen identical actors and camera; 90 warmup and 240 measured frames per view/mode; no AI or physics tick in this comparison.","results":results},"  "))
	baseline.free()
