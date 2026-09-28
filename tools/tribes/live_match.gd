extends SceneTree
## Real 6v6 authority and a separate visible ENet spectator. No bot stat buffs.
class Director extends Node:
	var session
	func _process(_delta):session.direct()
var game
var options: Dictionary
var overlay: Label
var focus:=0
var focus_at:=-20.0
var start:=0.0
var frame_count:=0
var sample_at:=0.0
var samples: Array=[]
var movement: Dictionary={}
var capture_deadline=preload("res://tools/tribes/capture_deadline.gd").new()
var flag_events: Array=[]
var previous_flags: Array=[]
var previous_scores: Array=[0,0]
var termination_reason:="running"
var recorder
var travel_samples: Array=[]
var travel_at:=0.0
var last_view_clock:=0.0
func _initialize():run.call_deferred()
func write(name: String,value):FileAccess.open(options.output+"/"+name,FileAccess.WRITE).store_string(JSON.stringify(value,"  "))
func run():
	options=JSON.parse_string(OS.get_cmdline_user_args()[0]);seed(int(options.get("seed",9281)))
	DirAccess.make_dir_recursive_absolute(options.output)
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	if options.get("viewer",false):
		root.title="ST LIVE · "+str(options.get("map","ctf_stonehenge"))+" · 6v6";root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,800);root.position=Vector2i(50,50)
		root.content_scale_size=root.size;Engine.max_fps=60
		game.start_join("ST Live View","127.0.0.1",int(options.port),true)
		game.voice_enabled=false # Silent bot observer; no microphone capture.
		var deadline:=Time.get_ticks_msec()+60000
		while not game.active or game.players.size()<13 or game.match_mode.kind!="st":
			if Time.get_ticks_msec()>deadline:push_error("ST spectator connection timeout");quit(1);return
			await process_frame
		game.voice.set_mode(0) # Session-only; disconnect must not reopen capture.
		game.menu_open=false;game.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		game.camera.far=1600;game.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		var layer:=CanvasLayer.new();root.add_child(layer);layer.layer=100
		var background:=ColorRect.new();background.color=Color(.025,.035,.05,.88);background.size=Vector2(1280,102);layer.add_child(background)
		overlay=Label.new();overlay.position=Vector2(20,8);overlay.add_theme_font_size_override("font_size",21);layer.add_child(overlay)
		var director:=Director.new();director.session=self;director.process_priority=100;root.add_child(director)
		write("viewer.json",{"pid":OS.get_process_id(),"peer":game.multiplayer.get_unique_id(),"spectator":game.local_state().spectator,"map":game.current_map})
		print("ST_LIVE_VIEW_READY")
		if options.get("record",false):
			recorder=preload("res://tools/tribes/live_recorder.gd").new();recorder.start(options.output)
			RenderingServer.frame_post_draw.connect(record_frame)
		while game.active:
			await process_frame;frame_count+=1
			if frame_count%600==0:
				root.get_texture().get_image().save_png(options.output+"/live.png")
				write("viewer.json",{"pid":OS.get_process_id(),"peer":game.multiplayer.get_unique_id(),"spectator":game.local_state().spectator,"frames":frame_count,"clock":game.snapshot_view_time,"map":game.current_map,"bot":focus,"horizontal_speed_kmh":watched_speed()})
		write("viewer-ended.json",{"pid":OS.get_process_id(),"frames":frame_count,"clock":last_view_clock})
		if recorder:
			RenderingServer.frame_post_draw.disconnect(record_frame)
			var encoder_pid: int=recorder.finish();var end:=Time.get_ticks_msec()+30000
			while OS.is_process_running(encoder_pid) and Time.get_ticks_msec()<end:await create_timer(.1).timeout
	else:
		game.dedicated=true;game.bind_address="127.0.0.1";game.max_clients=16;game.bot_population.count_target=12
		game.match_mode.configure({"sv_gametype":"st","capturelimit":5});game.selected_map=str(options.get("map","ctf_stonehenge"));game.lobby.enabled=false
		var duration: float=float(options.get("seconds",0))
		var minutes:=clampi(ceili(duration/60.0),1,60) if duration>0 else 30
		game.start_host("ST experimental 6v6",int(options.get("port",28984)),5,minutes,false,"st")
		game.voice_enabled=false
		game.server_log.free()
		game.server_log=preload("res://tools/tribes/match_log.gd").new();game.add_child(game.server_log)
		game.server_log.game=game
		game.server_log.evidence=FileAccess.open(options.output+"/combat.jsonl",FileAccess.WRITE)
		if not game.active:push_error("ST match failed to start");quit(1);return
		start=game.clock
		var speed: int=int(options.get("speed",1));Engine.time_scale=speed;Engine.physics_ticks_per_second=60*speed;Engine.max_physics_steps_per_frame=32
		print("ST_LIVE_SERVER_READY ",OS.get_process_id())
		while game.active:
			await physics_frame
			measure_movement()
			if game.clock>=travel_at:travel_at=game.clock+1;sample_travel()
			observe_flags()
			if game.clock>=sample_at:sample_at=game.clock+5;sample()
			if capture_deadline.expired(game.clock-start):termination_reason=capture_deadline.reason(game.clock-start);break
			if game.intermission>0:termination_reason="match_finished";break
			if float(options.get("seconds",0))>0 and game.clock-start>=float(options.seconds):termination_reason="duration_reached";break
		if termination_reason=="running":termination_reason="disconnected"
		sample();write("samples.json",samples)
		write("travel.json",travel_samples)
		var result:={"seconds":game.clock-start,"scores":game.match_mode.scores,"samples":samples,"movement":movement,"termination_reason":termination_reason,"flag_events":flag_events}
		result.merge(capture_deadline.snapshot());write("result.json",result)
		print("ST_MATCH_END ",termination_reason," first_capture=",capture_deadline.first_capture_seconds)
	game.disconnect_game();game.queue_free();await process_frame;quit(2 if termination_reason in ["no_capture_600s","no_pickup_after_capture_600s"] else 0)
func flag_event(kind: String,team: int,carrier: int):
	if kind=="pickup":capture_deadline.pickup(game.clock-start)
	var row:={"seconds":game.clock-start,"kind":kind,"flag_team":team,"carrier":carrier}
	if game.players.has(carrier) and game.fighters.has(carrier):
		var actor=game.fighters[carrier];var brain: Dictionary=game.bots.brains.get(carrier,{})
		row.merge({"position":actor.position,"velocity":actor.velocity,"hp":game.players[carrier].hp,"energy":actor.tribes_state.energy,"pack":game.players[carrier].tribes_pack,"role":brain.get("role",""),"goal":brain.get("goal_key",""),"phase":brain.get("travel_phase","")})
	flag_events.append(row);write("flag-events.json",flag_events)
func record_frame():
	if recorder and is_instance_valid(game) and game.active:recorder.capture(root,game.snapshot_view_time,focus,watched_speed())
func watched_speed() -> float:
	if not game.fighters.has(focus):return 0.0
	var velocity: Vector3=game.fighters[focus].visual_velocity
	return Vector2(velocity.x,velocity.z).length()*3.6
func observe_flags():
	capture_deadline.observe(game.clock-start,game.match_mode.scores)
	for team in game.match_mode.flags.size():
		var f: Dictionary=game.match_mode.flags[team]
		if previous_flags.size()==2:
			var old: Dictionary=previous_flags[team]
			if f.carrier!=0 and f.carrier!=old.carrier:flag_event("pickup",team,f.carrier)
			elif f.carrier==0 and old.carrier!=0:flag_event("drop" if f.dropped else "release",team,old.carrier)
			elif old.dropped and not f.dropped:flag_event("return",team,0)
		if game.match_mode.scores[team]>previous_scores[team]:flag_event("capture",1-team,int(previous_flags[1-team].carrier) if previous_flags.size()==2 else 0)
	previous_flags=game.match_mode.flags.duplicate(true);previous_scores=game.match_mode.scores.duplicate()
func measure_movement():
	for id in game.bots.brains:
		if not game.bots.alive(id):continue
		var actor=game.fighters[id];var state: Dictionary=game.players[id]
		if not movement.has(id):movement[id]={"peak_kmh":0.0,"ski_seconds":0.0,"jet_seconds":0.0,"frames":0}
		var stats: Dictionary=movement[id];stats.peak_kmh=maxf(stats.peak_kmh,Vector2(actor.velocity.x,actor.velocity.z).length()*3.6)
		stats.ski_seconds+=(1.0/60 if state.ski else 0.0);stats.jet_seconds+=(1.0/60 if state.jet_held else 0.0);stats.frames+=1
func sample_travel():
	var rows: Array=[]
	for id in game.bots.brains:
		if not game.bots.alive(id):continue
		var b: Dictionary=game.bots.brains[id];var s: Dictionary=game.players[id];var actor=game.fighters[id]
		if b.goal_key not in ["st:flag","st:capture"]:continue
		rows.append({"id":id,"serial":s.serial,"team":s.team,"goal":b.goal_key,"position":actor.position,"velocity":actor.velocity,"hp":s.hp,"energy":actor.tribes_state.energy,"pack":s.tribes_pack,"phase":b.get("travel_phase",""),"grounded":actor.is_supported(),"jet":s.jet_held,"ski":s.ski,"distance":actor.position.distance_to(b.goal),"waypoint":b.path[b.step] if b.step<b.path.size() else b.goal})
	travel_samples.append({"seconds":game.clock-start,"bots":rows})
func sample():
	var teams: Array=[0,0];var spectators:=0;var bots: Array=[]
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.spectator:spectators+=1;continue
		teams[s.team]+=1
		var brain: Dictionary=game.bots.brains.get(id,{})
		bots.append({"id":id,"team":s.team,"role":brain.get("role",""),"class":s.tribes_class,"pack":s.tribes_pack,"dead":s.dead,"hp":s.hp,"shots":s.shots,"deaths":s.deaths,"position":game.fighters[id].position,"goal":brain.get("goal_key",""),"target":brain.get("goal",Vector3.ZERO),"step":brain.get("step",0),"path":brain.get("path",[]),"energy":game.fighters[id].tribes_state.energy,"speed_kmh":Vector2(game.fighters[id].velocity.x,game.fighters[id].velocity.z).length()*3.6,"phase":brain.get("travel_phase",""),"ski":s.ski,"jet":s.jet_held,"equipment_target":brain.get("equipment_target",-1),"lane":game.bots.tribes.tactics.lane(id),"recoveries":game.bots.tribes.tactics.record(id).recoveries,"movement":movement.get(id,{})})
		var tower: Dictionary=brain.get("tower",{})
		bots[-1].merge({"serial":s.serial,"velocity":game.fighters[id].velocity,"refilling":brain.get("refilling",false),"waypoint":brain.path[brain.step] if not brain.is_empty() and brain.step<brain.path.size() else brain.get("goal",Vector3.ZERO),"tower_phase":tower.get("phase",""),"tower_stage":tower.get("stage",Vector3.ZERO)})
	var row:={"pid":OS.get_process_id(),"clock":game.clock,"seconds":game.clock-start,"teams":teams,"spectators":spectators,"scores":game.match_mode.scores.duplicate(),"flags":game.match_mode.flags.duplicate(true),"generators":game.match_mode.tribes.stations().health.duplicate(),"base_assets":game.match_mode.tribes.stations().assets.snapshot(),"deployables":game.match_mode.tribes.deployables.snapshot().rows,"tactics":game.bots.tribes.tactics.stats.duplicate(),"offense":game.bots.tribes.offense.stats.duplicate(),"fixed_defences":game.match_mode.tribes.stations().defences.snapshot(),"fixed_fire":game.match_mode.tribes.stations().defences.stats.duplicate(),"field_recovery":game.match_mode.tribes.recovery.stats.duplicate(),"targeting":game.match_mode.tribes.targeting.stats.duplicate(),"loot":game.match_mode.tribes.recovery.rows.size(),"waves":game.bots.tribes.tactics.waves.duplicate(true),"bots":bots}
	row.merge(capture_deadline.snapshot());row.termination_reason=termination_reason
	write("server.json",row);samples.append(row)
	if samples.size()%12==0:write("samples.json",samples)
	if samples.size()%6==0:print("ST_MATCH ",snappedf(game.clock-start,1)," scores=",row.scores," flags=",row.flags.map(func(f):return f.carrier)," power=",row.generators)
func direct():
	if not is_instance_valid(game) or not game.active:return
	var alive: Array=game.players.keys().filter(func(id):return id<0 and not game.players[id].dead and not game.players[id].spectator and game.fighters.has(id));alive.sort()
	var carrier:=0
	for flag in game.match_mode.flags:
		if flag.carrier in alive:carrier=flag.carrier;break
	var view_clock: float=maxf(0,game.snapshot_view_time)
	last_view_clock=maxf(last_view_clock,view_clock)
	if not alive.is_empty() and (focus not in alive or view_clock-focus_at>45 or carrier!=0 and carrier!=focus):
		# Follow whole approaches instead of cutting every 2.5 wall seconds
		# in a 4x run. Public flag carriers take immediate camera priority.
		focus=alive[int(view_clock/45)%alive.size()]
		var telemetry=JSON.parse_string(FileAccess.get_file_as_string(str(options.get("telemetry_output",options.output))+"/server.json"))
		if telemetry is Dictionary:
			var attackers: Array=telemetry.get("bots",[]).filter(func(row):return row.id in alive and row.role=="capper" and row.goal=="st:flag")
			if not attackers.is_empty():focus=int(attackers[int(view_clock/45)%attackers.size()].id)
		if carrier!=0:focus=carrier
		focus_at=view_clock
	if game.fighters.has(focus):
		var s: Dictionary=game.players[focus];var actor=game.fighters[focus];var eye: Vector3=actor.render_position()+Vector3.UP*actor.eye_height()
		var basis:=Basis(Vector3.UP,s.yaw);var best:=Vector3.ZERO;var clearance:=-INF
		# Narrow bunker passages can push a chase camera inside avatar hair.
		# Prefer the usual shoulder view, then a clear side/overhead vantage.
		var offsets: Array=[Vector3(2.4,2.3,5.5),Vector3(-2.4,2.3,5.5),Vector3(4,2,1),Vector3(-4,2,1),Vector3(0,4,0),Vector3(0,1.8,-4)]
		for index in offsets.size():
			var wanted: Vector3=eye+basis*offsets[index]
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,wanted,1))
			var point: Vector3=hit.position+hit.normal*.3 if not hit.is_empty() else wanted
			var score: float=point.distance_to(eye)-index*.2
			if score>clearance:best=point;clearance=score
			if index==0 and point.distance_to(eye)>3.5:break
		game.camera.global_position=best;game.camera.look_at(eye-basis.z*5);game.camera.fov=85
	if is_instance_valid(game.viewmodel):game.viewmodel.hide()
	var names: Array=[]
	for i in game.match_mode.flags.size():
		var f: Dictionary=game.match_mode.flags[i];names.append(("RED" if i==0 else "BLUE")+": "+("CARRIED" if f.carrier else "DROPPED" if f.dropped else "HOME"))
	var watched: String=game.players[focus].name+" · "+game.players[focus].tribes_class.to_upper() if game.players.has(focus) else "Overview"
	var speed:=watched_speed()
	overlay.text="LIVE 6v6 · ST TRIBES · %s     RED %d : %d BLUE     %02d:%02d\n%s     %s\nWatching %s     SPEED %.0f km/h horizontal"%[game.current_map.trim_prefix("ctf_").to_upper(),game.match_mode.scores[0],game.match_mode.scores[1],int(game.round_left)/60,int(game.round_left)%60,names[0],names[1],watched,speed]
