extends "res://deathmatch/tests/network_runner.gd"
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	role=args[0]
	game=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if role=="server":
		game.dedicated=true
		game.selected_map="lqdm8"
		game.start_host("BSP test",27777,20,10,false)
		check(await wait_for(func(): return game.players.size()==2),"Two clients loaded host BSP and joined")
		if game.players.size()==2:
			var runtime=game.get_node("Map/MapRuntime")
			var region: Dictionary={}
			for r in runtime.regions:
				if r.kind=="trigger_teleport" and runtime.destinations.has(r.data.get("target","")): region=r; break
			check(not region.is_empty(),"Teleport trigger and destination imported")
			if not region.is_empty():
				var id=game.players.keys()[0]
				var shape=region.area.get_child(region.area.get_child_count()-1)
				var serial=game.players[id].serial
				game.fighters[id].position=shape.global_position-Vector3.UP*.5
				game.fighters[id].velocity=Vector3.ZERO
				check(await wait_for(func(): return game.players[id].serial>serial,2),"Entering BSP trigger teleports player authoritatively")
			check(game.lifts.size()==1,"Moving platform imported")
			var y=game.lifts[0].node.position.y
			check(await wait_for(func(): return absf(game.lifts[0].node.position.y-y)>.01,6),"Platform moves during multiplayer simulation")
		game._announcement.rpc("TEST_DONE")
		await pause(.6)
	else:
		check(game.current_map=="lqdm1","Client initially has a different arena")
		game.start_join(role,"127.0.0.1",27777)
		check(await wait_for(func(): return game.active),"Map handshake completes")
		check(game.current_map=="lqdm8","Host arena selected before roster activation")
		check(game.spawn_points.size()==8,"Spawn data matches host")
		check(await wait_for(func(): return game.feed.any(func(entry): return entry.text=="TEST_DONE"),10),"Snapshots remain active through BSP entity simulation")
	print("NETWORK_RESULT ",role," ",JSON.stringify({"failures":failures}))
	game.disconnect_game("Test completed")
	await pause(.1)
	quit(0 if failures.is_empty() else 1)
