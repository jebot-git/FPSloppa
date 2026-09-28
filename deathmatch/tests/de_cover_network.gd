extends "res://deathmatch/tests/network_runner.gd"
class Observer extends Node:
	var phase:=""
	var expected: Dictionary={}
	var seen: Dictionary={}
	@rpc("authority","call_local","reliable")
	func stage(label: String,row: Dictionary):phase=label;expected=row
	@rpc("any_peer","call_remote","reliable")
	func acknowledge(label: String):
		if multiplayer.is_server():seen[label]=true
var observer: Observer
func publish(label: String):
	var expected:={"gates":[],"hp":game.players[peer_id].hp}
	for gate in game.gates:expected.gates.append([gate.open,gate.node.position])
	observer.stage.rpc(label,expected)
	var deadline:=Time.get_ticks_msec()+6000
	while Time.get_ticks_msec()<deadline and not observer.seen.has(label):
		game.clock+=.05;game._send_snapshot();await pause(.05)
	check(observer.seen.has(label),"Client acknowledges "+label)
func agrees() -> bool:
	if game.gates.size()!=observer.expected.gates.size() or game.local_state().hp!=observer.expected.hp:return false
	for i in game.gates.size():
		if game.gates[i].open!=observer.expected.gates[i][0] or game.gates[i].node.position.distance_to(observer.expected.gates[i][1])>.005:return false
	return true
func run():
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	observer=Observer.new();observer.name="CoverObserver";game.add_child(observer)
	if role=="server":
		game.dedicated=true;game.bind_address="127.0.0.1";game.selected_map="de_nuke_rebuilt"
		game.match_mode.configure({"sv_gametype":"de"});game.armory.select("cs16")
		game.start_host("Cover network",28979,100,10,false,"de");game.set_physics_process(false);game.set_process(false)
		var runtime=game.get_node("Map/MapRuntime");runtime.triggers.use_target("GlassDoor2",1)
		await pause(1.4)
		var deadline:=Time.get_ticks_msec()+20000
		while Time.get_ticks_msec()<deadline and not observer.seen.has("ready"):
			game.clock+=.05;game._send_snapshot();await pause(.05)
		check(game.players.size()==1 and observer.seen.has("ready"),"Late client joins after glass doors open")
		if game.players.size()==1:
			peer_id=game.players.keys()[0];game.players[peer_id].spectator=true
			await publish("late join open doors")
			game.match_mode.defusal.begin_round();await publish("round reset closed doors")
			# Record and replay the production mover snapshot, including a partial
			# opening. The peer joins closed, then sees a real moving transform.
			runtime.triggers.use_target("GlassDoor2",peer_id);await pause(.4)
			for gate in game.gates:
				if gate.has("motion_tween") and is_instance_valid(gate.motion_tween):gate.motion_tween.kill()
			await publish("partially open doors")
			var path:="res://test-results/de-restoration/cover-"+str(OS.get_process_id())+".fpsdemo"
			check(game.demos.start_record(path),"Door demo recording starts");game._send_snapshot();game.demos.stop_record()
			game.demos.input=FileAccess.open(path,FileAccess.READ);game.demos.input.seek(game.demos.MAGIC.length())
			var frame: Dictionary=game.demos.read_frame()
			check(not frame.is_empty() and frame.snapshot[10].map_movers.size()==8 and frame.snapshot[8].any(func(open):return open),"Demo stores partial door positions and open state")
			game.demos.input.close();game.demos.input=null
			game.match_mode.defusal.begin_round();await publish("second reset")
			# A real shot crosses Nuke's thin radio-room timber partition.
			game.match_mode.kind="dm";game._add_player(-9,"Wallbang shooter")
			var shooter: Dictionary=game.players[-9];var victim: Dictionary=game.players[peer_id]
			for state in [shooter,victim]:state.merge({"dead":false,"spectator":false,"hp":1000,"armor":0,"invulnerable":0.0,"weapon":6,"owned":[0,6],"ammo":[60,0,90,0],"cooldown":0.0,"held":false,"fire":false,"input_blocked":false,"yaw":-PI/2,"pitch":0.0,"last_input":game.clock,"xr":{}},true)
			shooter.team=0;victim.team=1
			game.fighters[-9].position=Vector3(-8.75,.05,3.75);game.fighters[peer_id].position=Vector3(-4.85,.05,3.75)
			for settle in 8:
				game.fighters[-9].simulate(Vector2.ZERO,-PI/2,true,1.0/60);await physics_frame
			check(game.variant_combat.cs.shoot(-9) and victim.hp<1000,"Real AK shot damages remote player through radio timber")
			await publish("penetrated damage")
		observer.stage.rpc("done",{});await pause(.2)
	else:
		await pause(2)
		game.start_join("Cover remote","127.0.0.1",28979)
		check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,20),"Client enters actual Nuke BSP")
		game.set_physics_process(false);game.set_process(false);observer.acknowledge.rpc_id(1,"ready")
		check(game.get_node("Map/MapRuntime").ballistics.ready,"Client binds same BSP penetration metadata")
		var handled:="";var deadline:=Time.get_ticks_msec()+35000
		while Time.get_ticks_msec()<deadline and observer.phase!="done":
			await pause(.02)
			if observer.phase.is_empty() or handled==observer.phase or observer.phase=="done":continue
			var label:=observer.phase
			check(await wait_for(agrees,5),"Replicated health and mover transforms: "+label)
			observer.acknowledge.rpc_id(1,label);handled=label
		check(observer.phase=="done","Network scenario completes")
	print("DE_COVER_NETWORK_RESULT ",role," ",JSON.stringify(failures))
	FileAccess.open("res://test-results/de-restoration/network-"+role+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
