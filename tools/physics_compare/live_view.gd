extends Node
const Director=preload("res://tools/remote_match/director.gd")
var game
var overlay:Label
var elapsed:=0.0
var last:=0
var capture_start:=0
var cpu_start:=0
var captured:=false
var frames:Array=[]
var output:String
var next_status:=0.0
var session_ready:=false
func _ready():
	process_priority=10000
	run.call_deferred()
func run():
	output=OS.get_cmdline_user_args()[0]
	var window=get_tree().root
	window.title="Jolt live test · Katabatic · 8v8";window.size=Vector2i(1440,900);window.content_scale_size=window.size
	Engine.max_fps=60
	game=load("res://deathmatch/arena.tscn").instantiate();get_tree().root.add_child(game)
	game.haptics.shutdown();game.voice_enabled=false
	game.start_join("Jolt live observer","127.0.0.1",29872,true)
	game.voice_enabled=false
	var deadline:=Time.get_ticks_msec()+90000
	while not game.active or game.players.size()!=17:
		if Time.get_ticks_msec()>deadline:push_error("Live Jolt observer failed to join 16 bots");get_tree().quit(2);return
		await get_tree().process_frame
	game.voice.set_mode(0);game.menu_open=false;game.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.camera.far=1600
	var layer:=CanvasLayer.new();layer.layer=100;get_tree().root.add_child(layer)
	var background:=ColorRect.new();background.color=Color(.02,.03,.05,.88);background.size=Vector2(1440,84);layer.add_child(background)
	overlay=Label.new();overlay.position=Vector2(18,8);overlay.add_theme_font_size_override("font_size",21);layer.add_child(overlay)
	RenderingServer.viewport_set_measure_render_time(window.get_viewport_rid(),true)
	var backend:String=game.get_world_3d().direct_space_state.get_class()
	if not backend.begins_with("Jolt"):push_error("Client backend mismatch");get_tree().quit(2);return
	print("JOLT_LIVE_READY backend=",backend," players=",game.players.size())
	session_ready=true
func distribution(values:Array):
	values.sort();return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)]}
func _process(delta:float):
	if not session_ready or not is_instance_valid(game) or not game.active:return
	elapsed+=delta
	var shot:Dictionary=Director.frame(game,elapsed)
	if shot.has("player") and is_instance_valid(game.music):game.music.preview_listener=shot.player
	if is_instance_valid(game.viewmodel):game.viewmodel.hide()
	overlay.text="JOLT PHYSICS · LIVE 8v8 KATABATIC · RED %d : %d BLUE\nWatching %s · %.1f FPS · %s"%[game.match_mode.scores[0],game.match_mode.scores[1],shot.get("name","Overview"),Engine.get_frames_per_second(),"collecting frame timings" if not captured else "60-second capture complete"]
	var now:=Time.get_ticks_usec()
	if elapsed>=20 and not captured:
		if capture_start==0:
			capture_start=now;cpu_start=FileAccess.open("/proc/self/task/%d/schedstat"%OS.get_process_id(),FileAccess.READ).get_line().split(" ")[0].to_int()
		elif last>0:
			var rid=get_viewport().get_viewport_rid()
			frames.append([float(now-last)/1000,RenderingServer.viewport_get_measured_render_time_cpu(rid),RenderingServer.viewport_get_measured_render_time_gpu(rid)])
		if now-capture_start>=60000000:
			var cpu_end:=FileAccess.open("/proc/self/task/%d/schedstat"%OS.get_process_id(),FileAccess.READ).get_line().split(" ")[0].to_int()
			var report:={"backend":game.get_world_3d().direct_space_state.get_class(),"map":game.current_map,"players":game.players.size(),"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":str(get_tree().root.size),"fps_cap":60,"main_cpu_ms_per_frame":float(cpu_end-cpu_start)/1000000/frames.size(),"frames":frames.size(),"frame_ms":distribution(frames.map(func(f):return f[0])),"render_cpu_ms":distribution(frames.map(func(f):return f[1])),"gpu_ms":distribution(frames.map(func(f):return f[2]))}
			FileAccess.open(output+"/timings.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
			FileAccess.open(output+"/frames.json",FileAccess.WRITE).store_string(JSON.stringify(frames))
			print("JOLT_LIVE_CAPTURE ",JSON.stringify(report));captured=true
	last=now
	if elapsed>=next_status:
		next_status=elapsed+10
		var teams:=[0,0];var moving:=0
		for id in game.players:
			if game.players[id].spectator:continue
			var team:int=game.players[id].team
			if team in [0,1]:teams[team]+=1
			if game.fighters.has(id) and game.fighters[id].visual_velocity.length()>.5:moving+=1
		FileAccess.open(output+"/status.json",FileAccess.WRITE).store_string(JSON.stringify({"elapsed":elapsed,"map":game.current_map,"teams":teams,"moving":moving,"scores":game.match_mode.scores,"backend":game.get_world_3d().direct_space_state.get_class(),"capture_complete":captured,"pid":OS.get_process_id()}))
		if elapsed<20 or captured:get_viewport().get_texture().get_image().save_png(output+"/live.png")
