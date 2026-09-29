extends "res://deathmatch/tests/network_runner.gd"
class DropProbe extends Node:
	var seen: Dictionary={}
	var phase:=""
	@rpc("authority","call_local","reliable")
	func stage(value: String) -> void:phase=value
	@rpc("any_peer","call_remote","reliable")
	func acknowledge(value: String) -> void:
		if multiplayer.is_server():
			if not seen.has(value):seen[value]={}
			seen[value][multiplayer.get_remote_sender_id()]=true
var observer: DropProbe
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	observer=DropProbe.new();observer.name="DropProbe";game.add_child(observer)
	if role=="server":
		game.dedicated=true;game.selected_map="qsrc_dm1";game.start_host("Drop test",28978,50,20,false)
		check(await wait_for(func():return observer.seen.get("ready",{}).size()==1,20),"First client joins")
		game.set_physics_process(false)
		game._add_player(-1,"Drop bot");game.players[-1].owned.append(3);game.players[-1].weapon=3;game.players[-1].ammo[1]=17
		game._damage(-1,-1,10000,"TEST",true)
		game._send_snapshot();print("DROP_READY")
		check(await wait_for(func():game._send_snapshot();return observer.seen.get("present",{}).size()==2,25),"Existing and late clients see the bot's dropped weapon")
		check(game.dropped_weapons.entries.size()==1,"Only one death drop exists")
		if not game.dropped_weapons.entries.is_empty():
			var collector: int=observer.seen.ready.keys()[0]
			var pickup: Dictionary=game.dropped_weapons.entries.values()[0]
			game.fighters[collector].position=pickup.position;game.players[collector].owned=[2];game.players[collector].ammo=[0,0,0,0]
			game._collect(collector);game._respawn_pickups()
			check(game.players[collector].owned.has(3) and game.players[collector].ammo[1]==8,"Authority awards the weapon and standard pickup ammunition")
		observer.stage.rpc("removed")
		check(await wait_for(func():game._send_snapshot();return observer.seen.get("removed",{}).size()==2,8),"Both clients remove the collected drop")
		observer.stage.rpc("done");await pause(.3)
	else:
		game.start_join(role,"127.0.0.1",28978)
		check(await wait_for(func():return game.active and not game.local_state().is_empty(),20),"Client joins")
		observer.acknowledge.rpc_id(1,"ready")
		check(await wait_for(func():return game.dropped_weapons.entries.size()==1,15),"Snapshot creates death drop")
		if not game.dropped_weapons.entries.is_empty():
			var pickup: Dictionary=game.dropped_weapons.entries.values()[0]
			check(pickup.item==3 and pickup.amount==8,"Exact dropped weapon and ammo survive replication")
		observer.acknowledge.rpc_id(1,"present")
		check(await wait_for(func():return observer.phase=="removed" and game.dropped_weapons.entries.is_empty(),12),"Collection removes replica")
		observer.acknowledge.rpc_id(1,"removed")
		check(await wait_for(func():return observer.phase=="done",5),"Network scenario completes")
	print("DROPPED_WEAPONS_NETWORK_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
