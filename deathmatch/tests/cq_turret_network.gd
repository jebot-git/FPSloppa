extends SceneTree
const Test=preload("res://deathmatch/tests/cq_healing_field.gd")
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
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game)
	if role=="server":
		game.start_host("Turret server",28799,100,10,false)
		check(await wait_for(func():return game.players.size()==2),"Enemy joins authority")
		game.set_process(false);game.set_physics_process(false)
		if game.players.size()==2:
			var enemy:int=game.players.keys().filter(func(id):return id!=1)[0]
			game.classes.choose(1,"technician");game._spawn(1);game.classes.award(1,7500);game.classes.choose_utility(1,"technician","turret");game._spawn(1);game.players[1].team=0;game.players[enemy].team=1;game.players[1].weapon=6;game.players[1].input_blocked=false;game.fighters[1].position=Vector3.ZERO;game.players[1].yaw=0;game.players[1].pitch=0;game.fighters[enemy].position=Vector3(20,0,-1.6)
			await physics_frame;await physics_frame
			check(game.turrets.deploy(1),"Authority validates and deploys T2 turret")
			game._send_snapshot();await create_timer(.4).timeout
			for i in 60:game.clock+=.05;game.turrets.tick();game._send_snapshot();await create_timer(.05).timeout
			check(game.projectiles.size()==2,"Turret independently fires two single shots")
			var key:int=game.turrets.rows.keys()[0];game.turrets.damage(key,enemy,100);game._send_snapshot();await create_timer(.5).timeout
			game.turrets.damage(key,enemy,100);game._send_snapshot();await create_timer(.5).timeout
	else:
		game.clock=500;game.start_join("Turret enemy","127.0.0.1",28799)
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins with a different clock")
		check(await wait_for(func():return not game.turrets.rows.is_empty()),"Stationary turret state replicates")
		if not game.turrets.rows.is_empty():
			var key:int=game.turrets.rows.keys()[0];var row:Dictionary=game.turrets.rows[key]
			check(game.turrets.bodies.has(key) and game.turrets.bodies[key].position==row.position and row.hp==200,"Client creates collision body at authoritative placement")
			var remaining:float=game.classes.states.get(1,{}).get("turret_ready",0.0)-game.clock
			check(remaining>115 and remaining<=120,"Two-minute cooldown preserves relative deadline across clocks")
			check(game.classes.states[1].equipped_utility=="turret","T2 utility loadout replicates")
			check(await wait_for(func():return game.projectiles.size()>=2 and game.turrets.rows.values().any(func(t):return t.ammo==10)),"Client receives autonomous projectile trajectories and consumed reserve")
			check(await wait_for(func():return game.turrets.rows.values().any(func(t):return t.hp==100)),"Authoritative turret damage replicates")
			check(await wait_for(func():return game.turrets.rows.is_empty() and game.turrets.bodies.is_empty()),"Destruction removes replicated turret and collision")
	print("CQ_TURRET_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
