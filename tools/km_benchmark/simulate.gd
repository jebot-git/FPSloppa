extends SceneTree
## Real authority, ordinary bot brains/movement/combat; no network peers.
const BASE="res://maps/Benchmark1km/"
const OUT="res://test-results/km-benchmark/"
var game
var options: Dictionary={}
var render_intervals: Array=[]
var render_at:=0
var measure_frames:=false
var live_label: Label
var hud_at:=0
func sample_frame() -> void:
	var now:=Time.get_ticks_usec()
	if measure_frames and render_at>0:render_intervals.append((now-render_at)/1000.0)
	render_at=now
class Metrics extends "res://deathmatch/server/log.gd":
	var totals: Dictionary={}
	func record(event: String,_data: Dictionary={},_detail: int=1) -> void:totals[event]=int(totals.get(event,0))+1
func _initialize():run.call_deferred()
func distribution(values: Array) -> Dictionary:
	values.sort()
	if values.is_empty():return {}
	return {"samples":values.size(),"mean":values.reduce(func(a,b):return a+b,0.0)/values.size(),"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"max":values.back()}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("{"):options=JSON.parse_string(arg)
	seed(7129)
	DirAccess.make_dir_recursive_absolute(OUT)
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false)
	game.dedicated=true;game.max_clients=64;game.bot_population.count_target=64
	game.armory.select("quake");game.match_mode.configure({"sv_gametype":"dm"})
	game.map_catalog.append({"id":"prototype_km1","title":"Kilometre Test District","path":BASE+"prototype_km1.bsp","scene":BASE+"zones.scn","sha256":FileAccess.get_sha256(BASE+"prototype_km1.bsp"),"modes":["dm"]})
	game.selected_map="prototype_km1";game.start_host("Benchmark",0,100,60,true,"dm","quake");game.frag_limit=100000
	# Benchmark-only override: shipped dedicated server limit remains unchanged.
	game.max_clients=64;game.bot_population.maintain()
	print("KM_START_STATE ",game.active," ",game.current_map," ",game.players.size()," ",game.max_clients," ",game.bot_population.count_target," ",game.map_loading)
	if not game.active or game.current_map!="prototype_km1" or game.players.size()!=64:push_error("KM_START_FAILED");quit(1);return
	var old=game.server_log;var metrics:=Metrics.new();metrics.game=game;game.add_child(metrics);game.server_log=metrics;old.queue_free()
	var deadline:=Time.get_ticks_msec()+30000
	while not game.bots.ready_to_walk or not game.bots.navigation.ready():
		if Time.get_ticks_msec()>deadline:push_error("KM_NAV_TIMEOUT");quit(1);return
		await physics_frame
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"layout.json"))
	var index:=0;var previous: Dictionary={};var serial: Dictionary={};var shots: Dictionary={};var by_bot: Dictionary={}
	for id in game.players:
		var row: Array=layout.spawns[index];var point:=Vector3(row[0],row[1],row[2]);game.fighters[id].position=point;game.fighters[id].velocity=Vector3.ZERO
		var state: Dictionary=game.players[id];state.owned=[0,2,3,4,5,6,7,8];state.ammo=[200,100,100,100];state.weapon=[3,5,7,8][index%4]
		game.bots.brains[id]=game.bots.new_brain(id);previous[id]=point;serial[id]=state.serial;shots[id]=state.shots;by_bot[id]={"distance_m":0.0,"shots":0,"deaths":0};index+=1
	var camera: Camera3D
	if not game.headless:
		for layer in game.find_children("*","CanvasLayer",true,false):layer.hide()
		if is_instance_valid(game.viewmodel):game.viewmodel.hide()
		camera=Camera3D.new();camera.far=1500;camera.fov=85;game.add_child(camera);camera.position=Vector3(-388,3,-385);camera.look_at(Vector3(-350,2,-375));camera.make_current()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	root.use_occlusion_culling=options.get("occlusion",true)
	var speed: float=options.get("speed",1.0)
	Engine.time_scale=speed;Engine.physics_ticks_per_second=int(60*speed)
	if options.get("live",false) and camera:
		DisplayServer.window_set_title("FPSloppa — 1 km² / 64 bots / requested %.0fx"%speed)
		camera.position=Vector3(-410,12,-405);camera.look_at(Vector3(-375,1,-375))
		var overlay:=CanvasLayer.new();root.add_child(overlay);live_label=Label.new();overlay.add_child(live_label);live_label.position=Vector2(16,16);live_label.add_theme_color_override("font_outline_color",Color.BLACK);live_label.add_theme_constant_override("outline_size",6)
		live_label.text="1 km² BSP29 | 64 bots | requested %.0fx"%speed
	var ticks: Array=[];var engine_ticks: Array=[];var frames: Array=[];var samples: Array=[];var peak_projectiles:=0
	var begin_clock: float=game.clock;var began:=Time.get_ticks_usec();var last:=began;var last_sample: float=game.clock
	process_frame.connect(sample_frame)
	var seconds: float=options.get("seconds",120)
	while game.clock-begin_clock<seconds:
		await physics_frame
		var now:=Time.get_ticks_usec();var t:=now
		game._physics_process(1.0/60)
		if not game.headless:
			game._process(1.0/60)
			if options.get("live",false):
				var actor: Node3D=game.fighters[-1];var focus:=actor.position+Vector3.UP
				var desired:=focus+Vector3(-9,6,11)
				var obstruction: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(focus,desired,1))
				if not obstruction.is_empty():desired=obstruction.position+obstruction.normal*.4
				camera.position=camera.position.lerp(desired,.1);camera.look_at(focus)
		if game.clock-begin_clock>10:
			measure_frames=true
			ticks.append((Time.get_ticks_usec()-t)/1000.0);engine_ticks.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000);frames.append((now-last)/1000.0)
		last=now
		if live_label and Time.get_ticks_msec()-hud_at>250:
			hud_at=Time.get_ticks_msec();var elapsed: float=(Time.get_ticks_usec()-began)/1000000.0
			live_label.text="1 km² BSP29 | 64 bots | requested %.0fx\nSimulation %.1f s | wall %.1f s | achieved %.2fx | %d FPS"%[speed,game.clock-begin_clock,elapsed,(game.clock-begin_clock)/maxf(.001,elapsed),Engine.get_frames_per_second()]
		if game.players.size()!=64 or not game.active:push_error("KM_POPULATION_FAILED");quit(1);return
		peak_projectiles=maxi(peak_projectiles,game.projectiles.size())
		for id in by_bot:
			var state: Dictionary=game.players[id];var point: Vector3=game.fighters[id].position
			if state.serial==serial[id] and point.distance_to(previous[id])<2:by_bot[id].distance_m+=point.distance_to(previous[id])
			by_bot[id].shots+=maxi(0,state.shots-shots[id]);by_bot[id].deaths=state.deaths
			previous[id]=point;serial[id]=state.serial;shots[id]=state.shots
		if game.clock-last_sample>=10:
			last_sample=game.clock;samples.append({"time":game.clock-begin_clock,"memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"projectiles":game.projectiles.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
			print("KM_PROGRESS ",round(game.clock-begin_clock)," bots=",game.players.size()," events=",metrics.totals)
	var result: Dictionary={"options":options,"renderer":RenderingServer.get_current_rendering_method(),"headless":game.headless,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"population":game.players.size(),"simulated_seconds":game.clock-begin_clock,"wall_seconds":(Time.get_ticks_usec()-began)/1000000.0,"game_tick_ms":distribution(ticks),"engine_physics_ms":distribution(engine_ticks),"physics_interval_ms":distribution(frames),"render_frame_ms":distribution(render_intervals),"requested_speed":speed,"peak_projectiles":peak_projectiles,"bots":by_bot,"events":metrics.totals,"samples":samples,"nav_polygons":game.bots.region.navigation_mesh.get_polygon_count(),"scene_meshes":game.get_node("Map").get_child(0).find_children("*","MeshInstance3D",true,false).size(),"scene_occluders":game.get_node("Map").get_child(0).find_children("*","OccluderInstance3D",true,false).size(),"map_sha256":FileAccess.get_sha256(BASE+"prototype_km1.bsp")}
	measure_frames=false
	var name: String=options.get("name","headless64")
	if not game.headless:
		await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png(OUT+name+".png")
	FileAccess.open(OUT+name+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("KM_SIMULATION_DONE ",name)
	if options.get("compare",false) and not game.headless:await preload("res://tools/km_benchmark/compare.gd").run(self,game,camera)
	game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
