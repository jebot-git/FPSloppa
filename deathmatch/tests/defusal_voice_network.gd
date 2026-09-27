extends SceneTree
const Opus=preload("res://deathmatch/tests/opus_fixture.gd")
var game
var failures: Array=[]
var checks:=0
var messages: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(condition: Callable) -> bool:
	var end:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<end:
		if condition.call():return true
		await create_timer(.02).timeout
	return false
func run():
	var role: String=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.voice.test_receive=true
	if role=="server":
		game.dedicated=true;game.bind_address="127.0.0.1";game.match_mode.configure({"sv_gametype":"de"});game.selected_map="de_dust2_rebuilt"
		game.start_host("DE voice",28987,20,10,false,"de")
		check(await wait_for(func():return game.players.size()==4),"Four voice/observer clients joined")
		for id in game.players:
			var s: Dictionary=game.players[id]
			if s.spectator:continue
			s.team=1 if s.name=="dead" else 0;s.dead=s.name!="alive";s.hp=0 if s.dead else 100
		game.match_mode.defusal.phase="prepare";game.match_mode.defusal.phase_end=game.clock+60;game.match_mode.defusal.message="VOICE TEST READY"
		game._broadcast_roster()
		await create_timer(9).timeout
		check(game.voice.relayed_packets>=140,"Authority accepted real Opus on both PTT routes")
	else:
		game.start_join(role,"127.0.0.1",28987,role=="observer")
		check(await wait_for(func():return game.active and game.players.size()==4 and game.match_mode.defusal.message=="VOICE TEST READY"),"DE life states replicated")
		if role=="sender":
			await create_timer(.4).timeout
			var encoder:=Opus.encoder()
			game.chat_send("dead team message",true)
			for i in range(1,81):
				game.voice.submit.rpc_id(1,i,Opus.packet(encoder,i*960),true);await create_timer(.02).timeout
			game.chat_send("dead global message",false)
			for i in range(81,161):
				game.voice.submit.rpc_id(1,i,Opus.packet(encoder,i*960),false);await create_timer(.02).timeout
			await create_timer(1).timeout
			check(game.voice.received_packets==0,"Dead sender has no audio echo")
		else:
			await create_timer(5.5).timeout
			check(game.voice.received_packets==0 if role=="alive" else game.voice.received_packets>=100,"Dead audio reaches dead/observer clients and never living client")
			if role!="alive":check(game.voice.decoded_packets>10 and game.voice.decoded_peak>.01,"Dead channel decodes audible Opus")
		var texts: Array=game.chat_feed.map(func(row):return row.text)
		check(not texts.any(func(t):return "dead " in t) if role=="alive" else texts.any(func(t):return "[DEAD]" in t and "dead global message" in t),"Text shares the dead-only boundary")
		if role=="dead":
			var de=game.match_mode.defusal;var body: Vector3=game.fighters[game.multiplayer.get_unique_id()].position
			de.move_observer({"move":Vector2.RIGHT,"fly":1.0,"yaw":0.0,"slow":false},1.0)
			check(de.observer_position.distance_to(body)>6.9,"Network-killed player can move spectator camera")
	var result:={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://test-results/defusal/voice-network-"+role+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_VOICE_NETWORK_RESULT ",role," ",JSON.stringify(result));game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
