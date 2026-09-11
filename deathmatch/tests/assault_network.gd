extends "res://deathmatch/tests/network_runner.gd"
class AssaultProbe extends Node:
	var seen: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func acknowledge(label: String) -> void:
		if multiplayer.is_server():
			if not seen.has(label):seen[label]={}
			seen[label][multiplayer.get_remote_sender_id()]=true
func run() -> void:
	var args:=OS.get_cmdline_user_args();role=args[0];var path: String=args[1]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var observer:=AssaultProbe.new();observer.name="AssaultProbe";game.add_child(observer)
	var key:=path.get_file().get_basename();var hash:=FileAccess.get_sha256(path)
	game.map_catalog=[{"id":key,"title":key,"path":path,"scene":"user://"+hash+"-as-net-"+role+".scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}];game.selected_map=key
	if role=="server":
		game.dedicated=true;game.match_mode.configure({"sv_gametype":"as"});game.start_host("AS network",27883,20,7,false,"as")
		check(await wait_for(func():return game.players.size()==2,30),"Both clients join AS")
		check(await wait_for(func():return observer.seen.get("spawn",{}).size()==2,15),"Both peers see AS pistol spawns and sentries")
		var rules=game.match_mode.assault
		var attacker:=0
		for id in game.players:
			game.players[id].invulnerable=game.clock+1000
			if game.players[id].team==0:attacker=id
		if attacker!=0:
			game.fighters[attacker].position=rules.objectives[0].position;game.players[attacker].serial+=1
			check(await wait_for(func():return observer.seen.get("switch",{}).size()==2,10),"Both clients receive activated switch")
			game.round_left=360
			game.fighters[attacker].position=rules.objectives[1].position;game.players[attacker].serial+=1
			check(await wait_for(func():return rules.switching,5),"Server completes first assault")
			check(await wait_for(func():return observer.seen.get("swap",{}).size()==2,20),"Both clients receive automatic role swap, reset objectives and defender sentries")
			game.match_mode.fortress.damage_building(100001,attacker,150)
			# attacker is now a defender: friendly damage is correctly refused.
			check(game.match_mode.fortress.buildings.has(100001),"New defending team cannot destroy friendly sentry")
			for id in game.players:
				if game.players[id].team==1:game.match_mode.fortress.damage_building(100001,id,150)
			check(await wait_for(func():return observer.seen.get("destroyed",{}).size()==2,10),"Sentry destruction reaches both clients")
		game._announcement.rpc("AS_NETWORK_DONE");await pause(.5)
	else:
		game.start_join(role,"127.0.0.1",27883)
		check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0 and game.match_mode.kind=="as",30),"Client joins AS and receives authoritative mode")
		check(await wait_for(func():return game.match_mode.fortress.buildings.size()==3,10),"Client receives map sentries")
		check(game.local_state().owned==[2] and not game.match_mode.fortress.enabled(),"Network player has pistol and no TF classes")
		observer.acknowledge.rpc_id(1,"spawn")
		check(await wait_for(func():return game.match_mode.assault.stage==1,15),"Client receives switch activation")
		observer.acknowledge.rpc_id(1,"switch")
		check(await wait_for(func():return game.match_mode.assault.leg==1 and game.match_mode.assault.stage==0,25),"Client receives second leg")
		check(game.match_mode.assault.attacking==1 and game.match_mode.fortress.buildings[100001].team==0 and game.round_left<=61,"Second leg swaps roles and uses recorded time")
		observer.acknowledge.rpc_id(1,"swap")
		check(await wait_for(func():return not game.match_mode.fortress.buildings.has(100001),10),"Client removes destroyed sentry")
		observer.acknowledge.rpc_id(1,"destroyed")
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="AS_NETWORK_DONE"),10),"Test completes")
	print("NETWORK_RESULT ",role," ",JSON.stringify({"failures":failures}))
	game.disconnect_game("Test complete");await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
