extends "res://deathmatch/tests/network_runner.gd"
class Probe extends Node:
	var seen: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func observed(stage: String) -> void:
		if multiplayer.is_server():seen[stage]=true
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	var probe:=Probe.new();probe.name="StanceProbe";root.add_child(probe)
	if role=="server":
		game.dedicated=true;game.start_host("Stance server",27904,100,60,false)
		check(await wait_for(func():return game.players.size()==1,15),"Client joins stance protocol")
		if game.players.size()==1:
			game.set_process(false);game.set_physics_process(false)
			var id: int=game.players.keys()[0];var actor=game.fighters[id];var s: Dictionary=game.players[id]
			for posture in ["prone","crouch","stand"]:
				game._announcement.rpc("REQUEST_"+posture)
				check(await wait_for(func():return probe.seen.has("sent_"+posture)),"Received "+posture+" input")
				actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.jump_held=false
				for i in 30:await physics_frame;s.last_input=game.clock;game._server_tick(1.0/60)
				check(actor.stance==posture and actor.position.y<Fixture.ORIGIN.y+.1,"Server applies "+posture+" and blocks prone jump")
				game._send_snapshot()
				check(await wait_for(func():return probe.seen.has("seen_"+posture)),"Client confirms "+posture+" snapshot")
			game._announcement.rpc("STANCE_DONE");await pause(.5)
	else:
		game.start_join("Stance client","127.0.0.1",27904)
		check(await wait_for(func():return game.active,15),"Client loads map")
		game.set_physics_process(false);game.set_process(false)
		var actor=game.fighters[game.multiplayer.get_unique_id()];actor.prediction.clear()
		var seq:=100000
		for posture in ["prone","crouch","stand"]:
			check(await wait_for(func():return game.feed.any(func(e):return e.text=="REQUEST_"+posture)),"Server ready for "+posture)
			seq+=1
			game._input_command.rpc_id(1,{"map_epoch":game.map_epoch,"seq":seq,"move":Vector2(0,-1),"yaw":0.0,"pitch":0.0,"fire":false,"weapon":2,"slow":false,"respawn":false,"prone":posture=="prone","crouch":posture=="crouch","jump":posture=="prone","leg_assist":true})
			# Same reliable probe is only an acknowledgement; movement uses its normal RPC.
			await pause(.2);probe.observed.rpc_id(1,"sent_"+posture)
			check(await wait_for(func():return actor.stance==posture and actor.tracked_leg_animation),"Authoritative "+posture+" height and animation preference arrive")
			probe.observed.rpc_id(1,"seen_"+posture)
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="STANCE_DONE")),"Stance exchange completes")
	print("STANCE_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
