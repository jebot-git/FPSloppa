extends SceneTree
const Fixture=preload("res://deathmatch/tests/cq_battery_tank.gd")
var failures:Array=[]
var game
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(test:Callable,seconds:float=15) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.05).timeout
	return false
func run() -> void:
	var role:String=OS.get_cmdline_user_args()[0]
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Fixture.TestArena);root.add_child(game)
	game.match_mode.objectives.sites[0].position=Vector3(10,.03,-10)
	if role=="server":
		game.start_host("Capturer",28816,5,1,false)
		check(await wait_for(func():return game.players.size()==2),"Client joins unified CQ authority")
		game.set_process(false);game.set_physics_process(false);game.voice.set_mode(0);game.voice.process_mode=Node.PROCESS_MODE_DISABLED
		game.players[1].team=0;game.fighters[1].position=Vector3(10,.03,-10)
		for id in game.players:
			if id!=1:game.players[id].team=1;game.fighters[id].position=Vector3(20,.03,-10)
		game._send_snapshot();await create_timer(.5).timeout
		for i in 10:game.clock+=1;game.match_mode.tick(1);game._send_snapshot();await create_timer(.05).timeout
		await create_timer(.3).timeout
		for i in 10:game.clock+=1;game.match_mode.tick(1);game._send_snapshot();await create_timer(.05).timeout
		await create_timer(.4).timeout
		var enemy:int=game.players.keys().filter(func(id):return id!=1)[0]
		game.match_mode.objectives.rules.scores=[199,0];game.match_mode.killed(enemy,1);game._send_snapshot();await create_timer(.6).timeout
		check(game.intermission>0 and game.match_mode.scores==[200,0],"Authority ends on territory-weighted kill")
	else:
		game.clock=500;game.start_join("Observer","127.0.0.1",28816)
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins with offset clock")
		check(game.fighters[game.multiplayer.get_unique_id()].cs16_enabled,"Client defaults to CS prediction")
		check(await wait_for(func():return game.match_mode.objectives.rules.owners[0]==0),"Captured POI ownership replicates")
		check(await wait_for(func():return game.match_mode.scores[0]==1),"Ten-second holding income replicates")
		check(await wait_for(func():return game.intermission>0 and game.match_mode.scores==[200,0] and game.match_mode.objectives.rules.winner==0),"First-to-200 result and winner replicate")
		var legacy:Dictionary=game.match_mode.snapshot();legacy.cq_movement={"quake":true};game.match_mode.receive(legacy)
		check(game.fighters[game.multiplayer.get_unique_id()].cs16_enabled,"Client ignores retired Quake snapshot field")
	check(game.fighters[game.multiplayer.get_unique_id()].cs16_enabled and game.fighters[game.multiplayer.get_unique_id()].body_shape.shape is CylinderShape3D,"CS cylinder prediction remains fixed through replicated match")
	print("CQ_FRONTIER_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
