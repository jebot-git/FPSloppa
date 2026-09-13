extends "res://deathmatch/tests/network_runner.gd"
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	if role=="server":
		game.dedicated=true;game.bind_address="127.0.0.1"
		game.start_host("Fallback server",27934,100,60,false)
		check(await wait_for(func():return game.players.size()==1,15),"Fallback client completes normal asset admission")
		await pause(1)
	else:
		game.start_join("Fallback client","127.0.0.2",27934)
		# Deterministic equivalent of DNS returning an unreachable address first.
		game.connect_addresses.append("127.0.0.1")
		game.connect_address_deadline=game.clock+.3
		check(await wait_for(func():return game.active,15),"Unreachable first address falls back without restarting the join")
		check(game.connect_address_index==2 and game.connect_addresses.is_empty(),"Successful transport cancels remaining address attempts")
		await pause(.7)
		game.disconnect_game("Cancellation check")
		game.start_join("Fallback client","127.0.0.2",27934)
		game.connect_addresses.append("127.0.0.1");game.connect_address_deadline=game.clock+.2
		game.disconnect_game("Cancelled by user")
		await pause(.4)
		check(game.connect_addresses.is_empty() and game.connect_address_deadline==0 and not game.active,"Cancelling clears pending fallback attempts")
	print("ADDRESS_FALLBACK_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
