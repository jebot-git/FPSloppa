extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
class TestArena extends Base:
	func _load_map(_id:String) -> bool:
		spawn_points=[Vector3(0,1,0)];spawn_yaws=[0];current_map="voxel_jungle";map_sha=map_identity()
		var ground:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3000,1,3000);shape.shape=box;ground.add_child(shape);$Map.add_child(ground);return true
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
		game.start_host("Recon server",28794,100,10,false)
		check(await wait_for(func():return game.players.size()==2),"Enemy client joins")
		if game.players.size()==2:
			var enemy:int=game.players.keys().filter(func(id):return id!=1)[0]
			game.players[enemy].team=1;game.players[1].team=0
			game.classes.choose(1,"scout");game._spawn(1);game.classes.award(1,7500);game.classes.choose_utility(1,"scout","recon_drone");game._spawn(1)
			game.players[1].input_blocked=false;game.players[1].yaw=0;game.players[1].pitch=0;game.fighters[1].position=Vector3.ZERO;game.fighters[enemy].position=Vector3(0,1,0)
			check(game.recon_drone.activate(1),"Authority launches the equipped T2 drone")
			game._send_snapshot()
			check(await wait_for(func():return game.recon_drone.alerts.has(enemy),16),"Flight scans and spots enemy client")
			game._send_snapshot();await create_timer(3).timeout
	else:
		game.clock=500;game.start_join("Recon enemy","127.0.0.1",28794)
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins with a different local clock")
		if game.active:
			var id:int=game.multiplayer.get_unique_id()
			check(await wait_for(func():return not game.recon_drone.flights.is_empty()),"Compact aircraft flight replicates")
			check(game.classes.states.get(1,{}).get("equipped_utility","")=="recon_drone","T2 utility selection replicates")
			var remaining:float=game.classes.states.get(1,{}).get("drone_ready",0.0)-game.clock
			check(remaining>110 and remaining<=120,"Drone cooldown preserves its relative deadline across clocks")
			check(await wait_for(func():return game.recon_drone.alerts.has(id) and game.recon_drone.warning_count==1,16),"Enemy receives one detection sound event from replicated warning")
			check(game.recon_drone.marks.get(id,[0.0,0.0])[0]>game.clock and game.spotting.spotted.get(id,[0.0,0.0])[0]>game.clock,"Team-shared radar spotting replicates")
			await create_timer(1).timeout
			check(game.recon_drone.warning_count==1,"Repeated snapshots do not replay the warning")
	print("CQ_RECON_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
