extends SceneTree
var game
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var options: Dictionary=JSON.parse_string(OS.get_cmdline_user_args()[0])
	game=load(options.scene).instantiate();game.test_index=options.index;game.observer=options.observer
	root.add_child(game);game.menu_open=false
	game.start_join("Observer" if options.observer else "NetBot %02d"%(options.index+1),options.host,options.port,options.observer)
	if options.observer:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var deadline:=Time.get_ticks_msec()+1800000
	var next:=0
	while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(options.stop):
		if options.observer:
			var roster: Array=[]
			for id in game.players:roster.append({"id":id,"name":game.players[id].name,"spectator":game.players[id].spectator})
			var status: Dictionary={"active":game.active,"players":roster,"pending":0 if game.active else 1,"map":game.current_map,"mode":game.match_mode.kind,"weapon_rules":game.armory.effective(),"lobby":game.lobby.active(),"time_remaining":game.round_left,"intermission":game.intermission,"result":game.round_message,"clock":game.clock,"recording":game.demos.recording}
			status["assault_finished"]=game.match_mode.assault.finished;status["assault_leg"]=game.match_mode.assault.leg;status["scores"]=game.match_mode.scores
			var file:=FileAccess.open(options.status+".tmp",FileAccess.WRITE);file.store_string(JSON.stringify(status));file.close()
			DirAccess.rename_absolute(options.status+".tmp",options.status)
		if options.observer and game.active and not game.demos.recording:game.demos.start_record(options.demo)
		if Time.get_ticks_msec()>=next:
			var state: Dictionary=game.local_state()
			print("NETBOT ",JSON.stringify({"active":game.active,"players":game.players.size(),"map":game.current_map,"mode":game.match_mode.kind,"epoch":game.map_epoch,"hp":state.get("hp",0),"kills":state.get("kills",0),"deaths":state.get("deaths",0),"ping":game.local_ping,"position":str(game.fighters[game.multiplayer.get_unique_id()].position) if game.fighters.has(game.multiplayer.get_unique_id()) else "none","recording":game.demos.recording,"event":game.last_event}))
			next=Time.get_ticks_msec()+5000
		await create_timer(.1).timeout
	game.demos.stop_record();game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
