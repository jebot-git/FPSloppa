extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
class TestArena extends Base:
	var fx_count:=0
	func _load_map(_id:String) -> bool:
		spawn_points=[Vector3(0,200,0)];spawn_yaws=[0];current_map="voxel_jungle";map_sha=map_identity();return true
	@rpc("authority","call_local","reliable",1)
	func _cq_airstrike_fx(_where:Vector3) -> void:fx_count+=1
var failures:Array=[]
var game
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(test:Callable,seconds:float=20) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.05).timeout
	return false
func run() -> void:
	var role:String=OS.get_cmdline_user_args()[0]
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game)
	if role=="server":
		game.start_host("Airstrike server",28795,100,10,false)
		check(await wait_for(func():return game.players.size()==2),"Client joins authority")
		game.set_process(false);game.set_physics_process(false)
		if game.players.size()==2:
			game.classes.award(1,7500);game.classes.choose_utility(1,"shocktroop","airstrike");game._spawn(1)
			game.players[1].weapon=8;game.players[1].fire=true;game.players[1].input_blocked=false;game.players[1].last_input=game.clock;game.fighters[1].velocity=Vector3.ZERO;game.players[1].move=Vector2.ZERO
			game.airstrike.pending[1]={"at":game.clock,"position":Vector3(0,0,-80),"direction":Vector3.FORWARD,"life":game.players[1].serial};game._send_snapshot();await create_timer(1).timeout
			game.clock+=5;game.players[1].last_input=game.clock
			check(game.airstrike.launch(1,Vector3(0,0,-80),Vector3.FORWARD),"Authority confirms equipped airstrike")
			game.airstrike.pending.clear();game._send_snapshot()
			for i in 200:
				game.clock+=.05;game.airstrike.tick();game._send_snapshot();await create_timer(.05).timeout
			check(game.fx_count==12,"Authority emits exactly twelve reliable impact events")
	else:
		game.clock=500;game.start_join("Airstrike client","127.0.0.1",28795)
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins with different clock")
		check(await wait_for(func():return game.airstrike.pending.has(1)),"Targeting sequence independently replicates")
		check(await wait_for(func():return not game.airstrike.flights.is_empty()),"Bomber trajectory independently replicates")
		check(game.classes.states.get(1,{}).get("equipped_utility","")=="airstrike" and 8 in game.players[1].owned and game.grenades.state(1).counts[0]==0,"Client sees correct T2 designator loadout without grenade")
		var remaining:float=game.classes.states.get(1,{}).get("airstrike_ready",0.0)-game.clock
		check(remaining>290 and remaining<=300,"Five-minute cooldown relative deadline preserved across clocks")
		check(await wait_for(func():return game.fx_count==12,15),"Client receives all twelve reliable impact events exactly once")
	print("CQ_AIRSTRIKE_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
