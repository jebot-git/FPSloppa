extends "res://deathmatch/tests/network_runner.gd"
class Probe extends Node:
	var seen: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func observed(stage_name: String) -> void:
		if multiplayer.is_server():seen[stage_name]=true
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var observation:=Probe.new();observation.name="FrigateProbe";root.add_child(observation)
	var tf=game.match_mode.fortress;var rules=game.match_mode.assault
	if role=="server":
		game.dedicated=true;game.selected_map="as_frigate";game.match_mode.configure({"sv_gametype":"as"});game.start_host("Frigate network",27893,100,6,false,"as")
		check(await wait_for(func():return game.players.size()==1,15),"Client joins Frigate dedicated server")
		if game.players.size()==1:
			game.set_physics_process(false);game.set_process(false)
			var id: int=game.players.keys()[0];game.players[id].team=0;game.players[id].dead=false;game.players[id].vr_device=true
			game.fighters[id].position=rules.objectives[0].position+Vector3(0,0,-2)
			game._send_snapshot()
			check(await wait_for(func():return observation.seen.has("initial")),"Client acknowledges full compressor snapshot")
			tf.damage_building(100100,id,40);game._send_snapshot()
			check(await wait_for(func():return observation.seen.has("damaged")),"Client acknowledges reduced objective health")
			tf.damage_building(100100,id,200);game._send_snapshot()
			check(await wait_for(func():return observation.seen.has("unlocked")),"Client observes destroyed compressor and unlocked bridge")
			game.players[id].vr_device=true;game.players[id].use_at=0;game.fighters[id].position=rules.objectives[1].position;game._send_snapshot();game._announcement.rpc("FINAL_READY")
			check(await wait_for(func():return rules.switching),"Remote Use activates the final objective")
			game._send_snapshot();check(await wait_for(func():return observation.seen.has("complete")),"Client receives paired-leg completion")
			rules.next_leg();game._send_snapshot()
			check(await wait_for(func():return observation.seen.has("reset")),"Client observes restored compressor and switched defenders")
			game._announcement.rpc("FRIGATE_DONE");await pause(.4)
	else:
		game.start_join("Frigate client","127.0.0.1",27893)
		check(await wait_for(func():return game.active and game.current_map=="as_frigate" and tf.buildings.has(100100),15),"Joining client receives Frigate and mission structure")
		game.set_physics_process(false);game.set_process(false)
		check(tf.buildings.get(100100,{}).get("hp",0)==240,"Initial compressor health is 240")
		observation.observed.rpc_id(1,"initial")
		check(await wait_for(func():return tf.buildings.get(100100,{}).get("hp",0)==200),"40 damage replicates as 200 remaining HP")
		observation.observed.rpc_id(1,"damaged")
		check(await wait_for(func():return rules.stage==1 and not tf.buildings.has(100100) and game.gates[0].open),"Destruction, stage and open door agree on client")
		observation.observed.rpc_id(1,"unlocked")
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="FINAL_READY")),"Server places client at final console")
		game._use_request.rpc_id(1)
		check(await wait_for(func():return rules.switching and rules.first_finished),"Remote console Use completes first assault")
		observation.observed.rpc_id(1,"complete")
		check(await wait_for(func():return rules.leg==1 and rules.attacking==1 and rules.stage==0 and tf.buildings.get(100100,{}).get("hp",0)==240),"Return leg restores objective health and reverses roles")
		observation.observed.rpc_id(1,"reset")
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="FRIGATE_DONE")),"Test finishes with synchronized peers")
	print("FRIGATE_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
