extends "res://tools/defusal/series_view.gd"
## Unrecorded live tour: production two-round DE rules, twelve bots, all maps.
func run():
	options=JSON.parse_string(OS.get_cmdline_user_args()[0]);options.rounds=2
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	if options.get("viewer",false):await view_live()
	else:await host_live()
	g.disconnect_game();g.queue_free();await process_frame;quit()
func host_live():
	g.dedicated=true;g.bind_address="127.0.0.1";g.max_clients=16;g.bot_population.count_target=12
	g.match_mode.configure({"sv_gametype":"de","sv_de_winlimit":2})
	g.selected_map=options.maps[0];g.map_rotation.assign(options.maps);g.lobby.enabled=false;g.votes.enabled=false
	g.start_host("DE Live · 6v6 · two rounds",int(options.port),20,60,false,"de");g.set_physics_process(false)
	assert(g.active and g.match_mode.defusal.win_limit==2)
	while not g.bots.ready_to_walk or not g.bots.navigation.ready():await physics_frame
	write_json("server-ready.json",{"pid":OS.get_process_id(),"maps":options.maps,"rounds":2,"switch_after":1})
	var deadline:=Time.get_ticks_msec()+90000
	while not FileAccess.file_exists(options.output+"/view-ready.json"):
		if Time.get_ticks_msec()>deadline:push_error("Live viewer did not connect");return
		g._send_snapshot();await create_timer(.1).timeout
	g.set_physics_process(true)
	var previous:=""
	var viewer_seen:=Time.get_ticks_msec()
	while g.active:
		var de=g.match_mode.defusal
		var phase: String="%s:%d:%s"%[g.current_map,de.round_id,de.phase]
		if phase!=previous:
			previous=phase;var teams: Array=[0,0]
			for id in g.players:
				if not g.players[id].spectator:teams[g.players[id].team]+=1
			var status:={"map":g.current_map,"round":de.round_id,"phase":de.phase,"teams":teams,"attacking":de.attacking,"scores":g.match_mode.scores,"win_limit":de.win_limit}
			write_json("status.json",status);print("DE_LIVE_PROGRESS ",JSON.stringify(status))
		if de.phase=="finished" and g.current_map==options.maps[-1]:
			g.set_physics_process(false)
			for i in 50:g._send_snapshot();await create_timer(.1).timeout
			write_json("completed.json",{"maps":options.maps,"rounds_per_map":2,"side_switches_per_map":1});return
		# Rotation temporarily removes bots while navigation and assets load.
		# Only an absent network viewer should end the tour early.
		if not g.multiplayer.get_peers().is_empty():viewer_seen=Time.get_ticks_msec()
		elif Time.get_ticks_msec()-viewer_seen>45000:return
		await create_timer(.25).timeout
func view_live():
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	root.position=Vector2i(50,50);root.title="DE LIVE · 6v6 · two rounds per map"
	g.start_join("DE Live View","127.0.0.1",int(options.port),true)
	var deadline:=Time.get_ticks_msec()+90000
	while not g.active or g.players.size()<13 or g.match_mode.kind!="de":
		if Time.get_ticks_msec()>deadline:push_error("DE spectator connection timeout");return
		await process_frame
	g.menu_open=false;g.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	g.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var layer:=CanvasLayer.new();root.add_child(layer);layer.layer=100
	var background:=ColorRect.new();background.color=Color(.025,.035,.05,.88);background.size=Vector2(1280,94);layer.add_child(background)
	overlay=Label.new();overlay.position=Vector2(20,10);overlay.add_theme_font_size_override("font_size",20);layer.add_child(overlay)
	var director:=LateDirector.new();director.session=self;director.process_priority=100;root.add_child(director)
	write_json("view-ready.json",{"pid":OS.get_process_id(),"spectator":g.local_state().spectator,"players":g.players.size()})
	print("DE_LIVE_VIEW_READY")
	var capture_at:=0
	while g.active or g.map_loading:
		await process_frame
		if g.active:
			g.menu_open=false;g.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			if is_instance_valid(g.camera):g.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		if Time.get_ticks_msec()>capture_at:
			capture_at=Time.get_ticks_msec()+5000
			root.get_texture().get_image().save_png(options.output+"/live.png")
