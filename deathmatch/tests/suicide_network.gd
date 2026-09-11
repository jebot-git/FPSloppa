extends "res://deathmatch/tests/network_runner.gd"
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	await process_frame
	if role=="server":
		game.dedicated=true;game.match_mode.configure({"sv_gametype":"tdm"});game.start_host("Suicide regression",27879,50,10,false,"tdm")
		check(await wait_for(func():return game.players.size()==2,20),"Both clients join")
		await pause(1)
		game._announcement.rpc("SUICIDE_NOW")
		check(await wait_for(func():return game.players.values().any(func(p):return p.deaths==1),8),"Remote suicide reaches authority")
		var victim:=0;var other:=0
		for id in game.players:
			if game.players[id].name=="Suicider":victim=id
			else:other=id
		if victim!=0 and other!=0:
			var state: Dictionary=game.players[victim];var life: int=state.serial
			check(state.kills==-1 and state.deaths==1,"Duplicate RPC costs exactly -1 frag and one death")
			check(game.match_mode.scores[state.team]==-1,"TDM team score receives suicide penalty")
			check(game.players[other].hp==100 and game.players[other].deaths==0,"Other peer is unaffected")
			check(await wait_for(func():return not state.dead and state.serial>life,3.5),"Suicide automatically respawns after normal delay despite fresh input")
			game._announcement.rpc("STALE_SUICIDE")
			await pause(.6)
			check(state.deaths==1 and state.kills==-1,"Delayed request from previous life rejected")
		game._announcement.rpc("TEST_DONE");await pause(.5)
	else:
		game.start_join("Suicider" if role=="shooter" else "Observer","127.0.0.1",27879)
		check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,20),"Client receives live state")
		if role=="shooter":
			check(await wait_for(func():return game.feed.any(func(e):return e.text=="SUICIDE_NOW"),10),"Authority ready")
			var life: int=game.local_state().serial
			game.request_suicide();game.request_suicide()
			check(await wait_for(func():return game.local_state().get("kills",0)==-1,5),"Scoreboard receives authoritative negative frag")
			check(await wait_for(func():return game.feed.any(func(e):return e.text=="STALE_SUICIDE"),6),"Respawn completes")
			game._suicide_request.rpc_id(1,game.map_epoch,life)
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="TEST_DONE"),12),"Network test completes")
	print("NETWORK_RESULT ",role," ",JSON.stringify({"failures":failures}))
	game.disconnect_game("Test complete");await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
