extends SceneTree
const Study=preload("res://tools/native_study/study_scopes.gd")
const Replication=preload("res://test-results/native-current-study/code/deathmatch/network/replication.gd")
var game
func _initialize():run.call_deferred()
func stats(rows:Array) -> Dictionary:
	if rows.is_empty():return {}
	rows.sort();return {"mean_ms":rows.reduce(func(a,b):return a+b,0.)/rows.size(),"p95_ms":rows[ceili(rows.size()*.95)-1],"p99_ms":rows[ceili(rows.size()*.99)-1],"max_ms":rows.back()}
func run() -> void:
	var args:=OS.get_cmdline_user_args();var map_id:=args[0];var ticks:=int(args[1]);var warmup:=int(args[2]);var control:=args.has("--control")
	seed(9400)
	game=load("res://deathmatch/arena.tscn" if control else "res://test-results/native-current-study/code/deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.dedicated=true;game.bind_address="127.0.0.1";game.max_clients=32;game.bot_population.count_target=16
	game.match_mode.configure({"sv_gametype":"st" if map_id.begins_with("ctf_") else "dm","capturelimit":100});game.selected_map=map_id;game.lobby.enabled=false
	game.start_host("Native current study",0,100,60,false)
	if not game.active:push_error("FAIL host start");quit(1);return
	game.set_process(false);game.set_physics_process(false);game.voice_enabled=false
	var deadline:=Time.get_ticks_msec()+60000
	while not game.bots.navigation.ready():
		if Time.get_ticks_msec()>deadline:push_error("FAIL nav timeout");quit(1);return
		await physics_frame
	var receiver=Replication.new();var times:Array=[];var send_times:Array=[];var receive_times:Array=[];var assemble_times:Array=[];var bytes:=0;var packet_count:=0;var shots:=0;var peak_projectiles:=0;var warmup_times:Array=[]
	for tick in warmup+ticks:
		await physics_frame
		if tick==warmup:Study.reset()
		game.clock+=1./60
		var start:=Time.get_ticks_usec();game._server_tick(1./60);game._record_history()
		var elapsed:=(Time.get_ticks_usec()-start)/1000.
		if tick>=warmup:times.append(elapsed)
		else:warmup_times.append(elapsed)
		peak_projectiles=maxi(peak_projectiles,game.projectiles.size())
		if not control and tick>=warmup and tick%10==0:
			start=Time.get_ticks_usec();game._send_snapshot();assemble_times.append((Time.get_ticks_usec()-start)/1000.)
			var snapshot:Array=game.get_meta("study_snapshot")
			start=Time.get_ticks_usec();var packets:Dictionary=game.replication.packets(snapshot);send_times.append((Time.get_ticks_usec()-start)/1000.)
			start=Time.get_ticks_usec()
			for packet in packets.normal+packets.large:
				bytes+=packet.size();packet_count+=1
				if not receiver.receive(packet,game.map_epoch):push_error("FAIL snapshot receive");quit(1);return
			var restored:Array=receiver.flush();receive_times.append((Time.get_ticks_usec()-start)/1000.)
			if restored[0].size()!=game.players.size():push_error("FAIL snapshot membership");quit(1);return
		if tick%300==0:print("STUDY_PROGRESS ",map_id," tick=",tick)
	for state in game.players.values():shots+=state.shots
	var result:={"map":map_id,"mode":game.match_mode.kind,"control":control,"bots":game.players.size(),"warmup":warmup,"ticks":ticks,"simulation":stats(times),"warmup_simulation":stats(warmup_times),"scopes_us_calls_max_self":Study.rows.duplicate(true),"shots":shots,"peak_projectiles":peak_projectiles,"scores":game.match_mode.scores,"snapshot_assembly":stats(assemble_times),"snapshot_encode":stats(send_times),"snapshot_receive_flush":stats(receive_times),"bytes_per_snapshot":bytes/maxi(1,send_times.size()),"packets_per_snapshot":float(packet_count)/maxi(1,send_times.size()),"native":{"bots":game.bots.native_ai!=null,"projectiles":game.native_projectiles!=null,"specialized_trace":not game._native_trace_allowed(),"codec":preload("res://deathmatch/network/codec.gd").native_codec!=null}}
	print("CURRENT_STUDY_RESULT ",JSON.stringify(result));game.disconnect_game();game.free();await process_frame;quit()
