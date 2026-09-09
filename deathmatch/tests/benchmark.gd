extends SceneTree
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.practice=true;game.active=true;game.menu_open=false
	game.set_physics_process(false)
	game.set_process(false)
	for id in [1,-1,-2,-3,-4,-5,-6,-7]: game._add_player(id,"Benchmark")
	var base: Vector3=Vector3(0,game.get_node("Map/MapRuntime").bounds.end.y+4,0)
	for id in game.fighters:
		var actor=game.fighters[id]
		actor.position=base+Vector3((abs(id)%4-1.5)*1.1,0,-2.5-abs(id)/4.0)
		actor.show_alive(true,id==1)
		actor.visual_velocity=Vector3(0,0,3)
		actor.rotation=Vector3.ZERO
	game.hud.visible=false
	for i in range(180): await process_frame
	var args:=OS.get_cmdline_user_args();var label: String=args[0] if not args.is_empty() else "current"
	if label=="render_reference":
		root.use_occlusion_culling=false
		game.get_node("Environment").environment.ssao_enabled=true
		game.get_node("Environment").environment.glow_enabled=true
		game.get_node("DuskSun").shadow_enabled=true
		game.get_node("Map/MapRuntime").set_process(false)
		for light in game.get_node("Map/MapRuntime").lights: light.visible=true
		for actor in game.fighters.values():
			for mesh in actor.find_children("*","MeshInstance3D",true,false):
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				for surface in range(mesh.mesh.get_surface_count()):
					var material: Material=mesh.get_active_material(surface)
					if material and material.has_meta("arena_outline"): material.next_pass=material.get_meta("arena_outline")
	game.camera.global_position=base+Vector3(0,1.55,3)
	game.camera.global_rotation=Vector3.ZERO
	for i in range(120): await process_frame
	var times: Array=[];var cpu: Array=[];var calls: Array=[];var tris: Array=[]
	var previous:=Time.get_ticks_usec()
	for i in range(360):
		await process_frame
		var now:=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		tris.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		game.camera.global_position=base+Vector3(0,1.55,3)
		game.camera.global_rotation=Vector3(0,sin(i*.012)*.35,0)
	times.sort();cpu.sort();calls.sort();tris.sort()
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"headset":false,"avatars":8,"frames":360,"frame_ms_p50":times[180],"frame_ms_p95":times[342],"process_ms_p95":cpu[342],"draw_calls_p50":calls[180],"primitives_p50":tris[180]}
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/benchmark_"+label+".png")
	var f:=FileAccess.open("res://test-results/benchmark_"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("BENCHMARK ",JSON.stringify(report))
	game.disconnect_game();game.free();quit()
