extends SceneTree
const Opus=preload("res://deathmatch/tests/opus_fixture.gd")
var game
var failures: Array=[]
var team_packets:=0
var public_packets:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(condition: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<deadline:
		if condition.call():return true
		await create_timer(.02).timeout
	return false
func run() -> void:
	var role: String=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.voice.test_receive=true
	game.voice.packet_received.connect(func(_id,serial,_data):
		if serial<=100:team_packets+=1
		else:public_packets+=1)
	if role=="server":
		game.dedicated=true;game.match_mode.configure({"sv_gametype":"tdm"});game.start_host("Radio test",27906,20,10,false,"tdm")
		check(await wait_for(func():return game.players.size()==3),"Three communication clients joined")
		game.match_mode.kind="tdm"
		for id in game.players:game.players[id].team=1 if game.players[id].name=="enemy" else 0
		game._broadcast_roster()
		await create_timer(7).timeout
		check(game.voice.relayed_packets>=170,"Server relayed both bounded communication channels")
	else:
		game.start_join(role,"127.0.0.1",27906)
		check(await wait_for(func():return game.active and game.players.size()==3 and game.match_mode.kind=="tdm" and game.local_state().get("team",-1)==(1 if role=="enemy" else 0)),"Team roster and mode replicated")
		if role=="sender":
			await create_timer(.5).timeout
			var encoder:=Opus.encoder()
			game.chat_send("private red message",true)
			for i in range(1,101):
				game.voice.submit.rpc_id(1,i,Opus.packet(encoder,i*960),true)
				await create_timer(.02).timeout
			await create_timer(.3).timeout
			game.chat_send("public message",false)
			for i in range(101,201):
				game.voice.submit.rpc_id(1,i,Opus.packet(encoder,i*960),false)
				await create_timer(.02).timeout
			await create_timer(1).timeout
			check(game.voice.received_packets==0,"Sender has no radio/proximity echo")
		else:
			await create_timer(6).timeout
			check(team_packets>=60 if role=="teammate" else team_packets==0,"Team voice reaches teammate and never enemy")
			check(public_packets>=60,"Proximity voice resumes after releasing radio")
			check(game.voice.decoded_packets>10 and game.voice.decoded_peak>.01,"Received voice contains decoded audible signal")
		var private_text: bool=game.chat_feed.any(func(row):return "[TEAM]" in row.text and "private red message" in row.text)
		check(not private_text if role=="enemy" else private_text,"Team text is visible only to sender and teammate")
		check(game.chat_feed.any(func(row):return "public message" in row.text),"Public text remains available to everyone")
	print("TEAM_RADIO_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
