extends SceneTree
## Real server simulation with a free camera; --simulate writes a bounded match report.
const AvatarPrepass=preload("res://tools/voxel_battle/avatar_prepass.gd")
const Probe=preload("res://tools/voxel_battle/performance.gd")
var prepass:=AvatarPrepass.new()
var probe:=Probe.new()
var live:=false
var keep_open:=false
var touring:=false
var view_label:="overview"
var tour_index:=-99
var live_elapsed:=0.0
var live_busy:=false
var camera_sequence:=""
var game
var camera: Camera3D
var hud: Label
var seconds:=600.0
var elapsed:=0.0
var simulation:=false
var mouse_held:=false
var output:="res://test-results/voxel-battle"
var started:=false
var totals: Dictionary={}
var visited: Dictionary={}
var travel: Dictionary={}
var last: Dictionary={}
var ticks: Array=[]
var teams: Array=[0,0]
var snipers: Array=[0,0]
var finished:=false
var jet_activations:=0
var previous_jet: Dictionary={}
var interior_visits: Dictionary={}
class Metrics extends "res://deathmatch/server/log.gd":
	var counts: Dictionary={}
	var damage: Dictionary={}
	var friendly_hits:=0
	func record(event: String,data: Dictionary={},_detail: int=1) -> void:
		counts[event]=int(counts.get(event,0))+1
		if event=="damage":
			damage[data.weapon]=int(damage.get(data.weapon,0))+int(data.damage)
			if data.attacker!=data.victim and game.match_mode.same_team(data.attacker,data.victim):friendly_hits+=1
var metrics
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	live=args.has("--live");keep_open=args.has("--keep-open");touring=args.has("--tour")
	simulation=args.has("--simulate") or DisplayServer.get_name()=="headless"
	for i in args.size():
		if args[i]=="--seconds" and i+1<args.size():seconds=maxf(1,float(args[i+1]))
		if args[i]=="--output" and i+1<args.size():output=args[i+1]
	preload("res://addons/vrm/vrm_secondary.gd").springs_enabled=false
	preload("res://deathmatch/avatars/visual_loader.gd").compile_surfaces=true
	seed(1977);DirAccess.make_dir_recursive_absolute(output)
	game=load("res://tools/voxel_battle/arena.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false)
	game.armory=preload("res://tools/voxel_battle/cs_rules.gd").new();game.armory.setup(game)
	game.variant_combat=preload("res://tools/voxel_battle/cs_combat.gd").new();game.variant_combat.setup(game)
	game.dedicated=true;game.max_clients=32;game.bot_population.count_target=32
	game.selected_map="voxel_valley";game.match_mode.configure({"sv_gametype":"tdm","sv_friendlyfire":0})
	game.start_host("Valley observer",0,100,10,true,"tdm","cs")
	# Replace log sink only; all damage/deaths/scoring still run through Arena.
	game.server_log.free();metrics=Metrics.new();metrics.game=game;game.add_child(metrics);game.server_log=metrics
	for id in game.players:
		teams[game.players[id].team]+=1
		if game.players[id].get("cs_sniper",false):snipers[game.players[id].team]+=1
		travel[id]=0.0;last[id]=game.fighters[id].position
	assert(teams==[16,16],"The scenario requires exactly 16 bots per team")
	assert(snipers==[4,4],"Each team requires four AWP specialists")
	camera=game.get_node("Overview");camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=70;camera.near=.08;camera.position=Vector3(0,490,110);camera.look_at(Vector3(0,12,0));camera.far=1000;camera.current=true
	if game.hud:game.hud.visible=false
	if not game.headless:
		root.size=Vector2i(1440,900);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_DISABLED
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var environment: Environment=game.get_node("Environment").environment
		environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.53,.67,.75)
		hud=Label.new();hud.position=Vector2(20,20);hud.add_theme_font_size_override("font_size",20);root.add_child(hud)
	if not prepare_avatars():quit(1);return
	print("VRM_PREPASS ",JSON.stringify(prepass.report))
	print("VALLEY_BUILD_READY buildings=",game.battle_map.layout.buildings.size()," collision_boxes=",game.battle_map.geometry.size())
	var deadline:=Time.get_ticks_msec()+120000
	while not game.bots.navigation.ready():
		if Time.get_ticks_msec()>deadline:push_error("Valley navigation bake timed out");quit(1);return
		await physics_frame
	print("VALLEY_NAV_READY polygons=",game.bots.region.navigation_mesh.get_polygon_count())
	if not game.headless:
		await settle_view()
		var lod_service=root.get_node_or_null("AvatarMeshLOD")
		if lod_service!=null:
			var lod_deadline:=Time.get_ticks_msec()+30000
			while (lod_service.task>=0 or not lod_service.pending.is_empty()) and Time.get_ticks_msec()<lod_deadline:await process_frame
	if not game.headless:probe.setup(output,root.get_viewport_rid())
	started=true
func prepare_avatars() -> bool:
	return prepass.prepare(game)
func _physics_process(delta: float) -> bool:
	if not started or finished:return false
	var before:=Time.get_ticks_usec()
	game._physics_process(delta)
	ticks.append((Time.get_ticks_usec()-before)/1000.0)
	elapsed+=delta
	for id in game.players:
		var p: Vector3=game.fighters[id].position
		var distance: float=p.distance_to(last[id]);if distance<4:travel[id]+=distance
		last[id]=p
		var jet: int=game.fighters[id].jetpack_state.activation
		var prior: int=previous_jet.get(id,0)
		jet_activations+=maxi(0,jet-prior);previous_jet[id]=jet
		for bi in game.battle_map.layout.buildings.size():
			var building: Dictionary=game.battle_map.layout.buildings[bi]
			var offset: Vector3=p-game.battle_map.Landscape.CENTERS[building.kind]-building.center
			if absf(offset.x)<building.size.x/2-.4 and absf(offset.z)<building.size.y/2-.4 and offset.y>=0 and offset.y<building.floors*3.2:
				interior_visits[str(bi)+":"+str(int(offset.y/3.2))]=true
		for i in game.battle_map.Landscape.CENTERS.size():
			if p.distance_to(game.battle_map.Landscape.CENTERS[i])<85:visited[i]=true
	if int(elapsed*60)%1800==0:print("VALLEY_PROGRESS seconds=",int(elapsed)," scores=",game.match_mode.scores," boosts=",game.bots.boosts)
	if simulation and (elapsed>=seconds or game.intermission>0):finish.call_deferred();finished=true
	return false
func _process(delta: float) -> bool:
	if not is_instance_valid(game) or camera==null:return false
	if touring and started and not finished:
		var index:=int(elapsed/30)%6-1
		if index!=tour_index:
			tour_index=index
			if index<0:overview()
			else:ground_visit(index)
	game.battle_map.update_view(camera)
	if not game.headless:
		# Keep production avatar/weapon interpolation and effects active without
		# invoking player input or opening the stock multiplayer menu.
		game._process(delta)
		if is_instance_valid(game.variant_visuals):game.variant_visuals.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		var move:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		camera.position+=camera.basis*move*delta*(55 if Input.is_physical_key_pressed(KEY_SHIFT) else 18)
		if started and not finished:probe.record(delta,root.get_viewport_rid(),game.battle_map,elapsed,view_label)
		if live:
			live_elapsed+=delta
			if live_elapsed>=2 and not live_busy:
				live_elapsed=0;live_busy=true;capture_live.call_deferred()
		if hud:hud.text="VALLEY JUNCTION   •   CS + JETPACK   •   16 v 16 TDM\nRED %d   BLUE %d   / 100     %.0fs   •   %d FPS\nWASD / Q E fly · RMB look · 1–5 visit area · Esc quit\n%s"%[game.match_mode.scores[0],game.match_mode.scores[1],elapsed,Engine.get_frames_per_second(),(("MATCH COMPLETE — observer remains live" if game.intermission>0 else "TEST COMPLETE — observer remains live") if finished else "Springs OFF · VRM preparation ON") if started else "Preparing navigation…"]
	return false
func finish() -> void:
	ticks.sort()
	var performance_report:=probe.result() if not game.headless else {}
	var deaths:=0;var shots:=0
	for s in game.players.values():deaths+=s.deaths;shots+=s.shots
	var report:={"seed":1977,"engine":Engine.get_version_info().string,"mode":"tdm","loadout":"cs-style","teams":teams,"snipers":snipers,"seconds":elapsed,"scores":game.match_mode.scores,"shots":shots,"deaths":deaths,"damage":metrics.damage,"friendly_hits":metrics.friendly_hits,"events":metrics.counts,"jetpack_requests":game.bots.boosts,"jetpack_activations":jet_activations,"interior_storeys_visited":interior_visits.keys(),"reloads":game.variant_combat.reloads,"distance_m":travel,"areas_visited":visited.keys(),"navigation_polygons":game.bots.region.navigation_mesh.get_polygon_count(),"physics_ms_p50":ticks[ticks.size()/2],"physics_ms_p95":ticks[int(ticks.size()*.95)],"height_m":1.7,"environment_colliders":game.battle_map.environment_colliders,"buildings":game.battle_map.layout.buildings.size(),"completed":game.intermission>0,"result":game.match_mode.result() if game.intermission>0 else "IN PROGRESS"}
	report.avatar_prepass=prepass.report
	report.performance=performance_report
	report.bot_ai_ms=Probe.summary(game.bots.tick_ms)
	var ai_total:=0.0;var physics_total:=0.0
	for value in game.bots.tick_ms:ai_total+=value
	for value in ticks:physics_total+=value
	report.bot_ai_share_of_physics_percent=100*ai_total/maxf(.001,physics_total)

	if not game.headless:
		atomic_json("performance.json",performance_report)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/match.png")
		for i in game.battle_map.Landscape.CENTERS.size():
			visit(i)
			await settle_view()
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/"+game.battle_map.Landscape.TYPES[i]+".png")
		camera.position=game.battle_map.Landscape.CENTERS[1]+Vector3(24,1.65,-12)
		camera.look_at(game.battle_map.Landscape.CENTERS[1]+Vector3(15,1.65,-30))
		await settle_view()
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/factory-interior.png")
		camera.position=game.battle_map.Landscape.CENTERS[4]+Vector3(-23,1.65,-30)
		camera.look_at(game.battle_map.Landscape.CENTERS[4]+Vector3(-29,1.65,-28))
		await settle_view()
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/radar-interior.png")
		camera.position=Vector3(-245,26,-230);camera.look_at(Vector3(-252,24,-260))
		await settle_view()
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/woodland.png")
		report.environment={"resident_tiles":game.battle_map.environment.tiles.size(),"resident_features":game.battle_map.environment.resident_features,"peak_features":game.battle_map.environment.peak_features,"visible_features":game.battle_map.environment.visible_features,"draw_calls":game.battle_map.environment.draw_calls,"lod_counts":game.battle_map.environment.counts,"triangles":game.battle_map.environment.triangles,"update_ms":game.battle_map.environment.update_ms}
		report.streaming={"generation_ms":Probe.summary(game.battle_map.terrain.generation_times),"upload_ms":Probe.summary(game.battle_map.terrain.upload_times),"peak_resident":game.battle_map.terrain.peak_resident,"peak_jobs":game.battle_map.terrain.peak_jobs,"loaded":game.battle_map.terrain.loaded_total,"evicted":game.battle_map.terrain.evicted_total}
	FileAccess.open(output+"/match.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("VALLEY_RESULT ",JSON.stringify(report))
	if keep_open and not game.headless:
		touring=false;visit(4);return
	game.disconnect_game();game.queue_free();await process_frame;await process_frame;game=null;metrics=null;quit()
func settle_view() -> void:
	# Render captures wait for the shared cache rather than relying on FPS-dependent
	# frame counts. The match is already frozen, so touring does not alter scores.
	var deadline:=Time.get_ticks_msec()+15000
	for frame in 3:await process_frame
	while not game.battle_map.terrain.settled() and Time.get_ticks_msec()<deadline:await process_frame
	for frame in 2:await process_frame
func visit(index: int) -> void:
	view_label=game.battle_map.Landscape.TYPES[index]
	var p: Vector3=game.battle_map.Landscape.CENTERS[index]
	camera.position=p+Vector3(85,62,105);camera.look_at(p+Vector3.UP*5)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:mouse_held=event.pressed
	if event is InputEventMouseMotion and mouse_held:
		camera.rotation.y-=event.relative.x*.003;camera.rotation.x=clampf(camera.rotation.x-event.relative.y*.003,-1.5,1.5)
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE:quit()
		if event.keycode>=KEY_1 and event.keycode<=KEY_5:touring=false;visit(event.keycode-KEY_1)

func overview() -> void:
	view_label="overview";camera.position=Vector3(0,490,110);camera.look_at(Vector3(0,14,0))
func ground_visit(index: int) -> void:
	var p: Vector3=game.battle_map.Landscape.CENTERS[index]
	view_label=game.battle_map.Landscape.TYPES[index]+" ground"
	camera.position=p+Vector3(-9,0,-42 if index==4 else -62)
	camera.position.y=game.battle_map.Landscape.surface(camera.position.x,camera.position.z).x+3.2
	camera.look_at(p+Vector3(0,1.7,12))
func atomic_json(name: String,value: Dictionary) -> void:
	FileAccess.open(output+"/"+name+".tmp",FileAccess.WRITE).store_string(JSON.stringify(value,"  "))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(output+"/"+name+".tmp"),ProjectSettings.globalize_path(output+"/"+name))
func capture_live() -> void:
	var control:=output+"/camera.json"
	if FileAccess.file_exists(control):
		var command=JSON.parse_string(FileAccess.get_file_as_string(control))
		if command is Dictionary and str(command.sequence)!=camera_sequence:
			camera_sequence=str(command.sequence);touring=false
			if int(command.site)<0:overview()
			elif int(command.site)<5:visit(int(command.site))
	await RenderingServer.frame_post_draw
	if not is_instance_valid(game):live_busy=false;return
	var begin:=Time.get_ticks_usec()
	var frame:=root.get_texture().get_image();frame.resize(960,600,Image.INTERPOLATE_BILINEAR)
	frame.save_jpg(output+"/live.next.jpg",.82)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(output+"/live.next.jpg"),ProjectSettings.globalize_path(output+"/live.jpg"))
	var capture_ms:=(Time.get_ticks_usec()-begin)/1000.0
	if started and not finished:probe.captures.append(capture_ms)
	atomic_json("live.json",{"status":("match complete" if game.intermission>0 else "test complete") if finished else "running" if started else "preparing","simulation_seconds":snappedf(elapsed,.1),"scores":game.match_mode.scores,"view":view_label,"fps":Engine.get_frames_per_second(),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"tiles":game.battle_map.terrain.resident.size(),"stream_settled":game.battle_map.terrain.settled(),"environment_draws":game.battle_map.environment.draw_calls,"springs":false,"vrm_prepass":true,"capture_ms":capture_ms})
	live_busy=false
