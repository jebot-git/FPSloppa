extends "res://deathmatch/tests/network_runner.gd"
class StageProbe extends Node:
	var stages:Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func ready(stage:String):
		if multiplayer.is_server():
			if not stages.has(stage):stages[stage]={}
			stages[stage][multiplayer.get_remote_sender_id()]=true
var stage_probe:StageProbe
func run():
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	stage_probe=StageProbe.new();stage_probe.name="StageProbe";root.add_child(stage_probe)
	if role=="server":await server_test()
	else:await client_test()
	print("LOADOUT_VOTE_NETWORK_RESULT ",JSON.stringify({"role":role,"failures":failures}))
	game.disconnect_game();await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
func server_test():
	game.dedicated=true;game.bind_address="127.0.0.1";game.selected_map="qsrc_dm1";game.armory.select("doom")
	game.votes.allowed_modes=["dm","ctf","tf"];game.mode_maplists={"dm":["qsrc_dm1"],"ctf":["qsrc_dm6"],"tf":["tf_ironspan"]}
	game.lobby.enabled=true;game.lobby.seconds=45
	game.start_host("Loadout vote test",28994,100,60,false)
	check(await wait_for(func():return game.players.size()==2,25),"Two real clients join the Doom match")
	if game.players.size()!=2:return
	check(await wait_for(func():return game.armory.effective()=="quake" and game.players.size()==2 and not game.map_loading,30),"Majority restarts same map with Quake and both clients rejoin")
	check(game.current_map=="qsrc_dm1" and game.players.values().all(func(s):return s.owned==[0,2] and s.ammo[1]==25),"Quake inventory replaces Doom inventory")
	check(await wait_for(func():return stage_probe.stages.get("quake",{}).size()==2,15),"Both clients acknowledge Quake restart before entering lobby")
	game.lobby.begin()
	check(await wait_for(func():return game.lobby.confirmed,30),"Lobby majority approves combined map/mode/loadout")
	check(game.lobby.result()=={"mode":"ctf","map":"qsrc_dm6","rules":"ut99"},"Server retains the approved UT99 loadout")
	game.lobby.until=game.clock
	check(await wait_for(func():return game.current_map=="qsrc_dm6" and game.players.size()==2 and not game.map_loading,30),"Lobby timer moves both clients to chosen match")
	check(game.match_mode.kind=="ctf" and game.armory.effective()=="ut99" and game.players.values().all(func(s):return 11 in s.owned),"Chosen mode and UT99 spawn inventories are authoritative")
	check(await wait_for(func():return stage_probe.stages.get("ut99",{}).size()==2,15),"Both clients acknowledge the lobby-selected UT99 match")
	await pause(2)
func client_test():
	game.start_join(role,"127.0.0.1",28994)
	check(await wait_for(func():return game.active and game.players.size()==2 and not game.local_state().is_empty(),25),"Client joins with another voter")
	if role=="first":game.votes.propose("loadout","quake")
	else:
		check(await wait_for(func():return game.votes.view.get("title","").contains("QUAKE")),"Second voter receives loadout ballot")
		game.votes.vote(true)
	check(await wait_for(func():return game.active and game.current_map=="qsrc_dm1" and game.armory.effective()=="quake" and not game.local_state().is_empty(),30),"Client receives Quake loadout after restart")
	stage_probe.ready.rpc_id(1,"quake")
	check(await wait_for(func():return game.lobby.active() and game.players.size()==2 and not game.lobby.view.is_empty(),30),"Both clients enter voting lobby")
	await pause(.2);game.lobby.submit("ctf","qsrc_dm6","ut99")
	check(await wait_for(func():return game.active and game.current_map=="qsrc_dm6" and game.match_mode.kind=="ctf" and game.armory.effective()=="ut99" and not game.local_state().is_empty(),30),"Client enters the voted CTF/UT99 match")
	# The reliable roster precedes the first authoritative inventory snapshot.
	check(await wait_for(func():return 11 in game.local_state().get("owned",[]),3),"Client receives usable UT99 spawn loadout")
	stage_probe.ready.rpc_id(1,"ut99")
	await pause(.5)
