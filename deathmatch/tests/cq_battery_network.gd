extends SceneTree
const Test=preload("res://deathmatch/tests/cq_battery_tank.gd")
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
		game.start_host("Battery driver",28805,100,10,false)
		check(await wait_for(func():return game.players.size()==2),"Observer joins authority")
		game.set_process(false);game.set_physics_process(false)
		game.battery_tanks.configure()
		for key in game.battery_tanks.rows:game.battery_tanks.rows[key].position=Vector3(key*50,.03,0);game.battery_tanks.rows[key].yaw=0;game.battery_tanks.rows[key].visual_y=.03+(0 if key<2 else .25);game.battery_tanks.pose_body(key)
		game.players[1].team=0;game.players[1].input_blocked=false;game.players[1].last_input=game.clock;game.players[1].pitch=.45;game.players[1].yaw=.2;game.fighters[1].position=Vector3(3.5,.03,0)
		await physics_frame;await physics_frame
		check(game.battery_tanks.use(1),"Authority boards driver")
		game._send_snapshot();await create_timer(.5).timeout
		for i in 45:
			game.clock+=.05;game.players[1].last_input=game.clock;game.players[1].fire=true;game.players[1].move=Vector2(0,-1);game.battery_tanks.tick(.05);game._send_snapshot();await create_timer(.05).timeout
		check(game.projectiles.size()==8 and game.battery_tanks.rows[0].reload_at>game.clock,"Authority launches eight rounds and reloads while moving")
		game.battery_tanks.damage(0,1,80,"grenade");game._send_snapshot();await create_timer(.5).timeout
		check(game.battery_tanks.use(1),"Authority safely dismounts")
		game._send_snapshot();await create_timer(.5).timeout
		game.battery_tanks.damage(0,1,60,"ordnance");game._send_snapshot();await create_timer(.5).timeout
	else:
		game.clock=500;game.start_join("Battery observer","127.0.0.1",28805)
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins with a different clock")
		check(await wait_for(func():return game.battery_tanks.mounted(1)),"Crew reservation replicates")
		if game.battery_tanks.mounted(1):
			check(game.battery_tanks.rows.size()==8 and game.battery_tanks.bodies.size()==8,"Both hulls replicate with colliders")
			check(game.fighters[1].vehicle_seated and game.fighters[1].collision_layer==0,"Snapshot keeps seated crew collider disabled")
			check(await wait_for(func():return game.projectiles.size()==8 and game.battery_tanks.rows[0].reload_at>game.clock),"Eight ballistic rounds and reload replicate")
			check(game.projectiles.values().all(func(p):return p.definition.gravity==20 and p.extra.battery_shot),"Client uses same mortar projectile definitions")
			check(game.projectiles.values().all(func(p):return p.extra.barrage_target.distance_to(p.extra.barrage_center)<=15.01 and (p.position+p.velocity*p.extra.barrage_time-Vector3.UP*10*p.extra.barrage_time*p.extra.barrage_time).distance_to(p.extra.barrage_target)<.02),"Authoritative dispersed trajectories replicate exactly to observer")
			check(game.projectiles.values()[0].extra.barrage_target.distance_to(game.projectiles.values()[4].extra.barrage_target)>5,"Network observer receives area barrage rather than pinpoint shots")
			var remaining:float=game.battery_tanks.rows[0].reload_at-game.clock
			check(remaining>27 and remaining<=30,"Reload deadline preserves relative thirty seconds across clocks")
			check(game.battery_tanks.rows[0].position.z<-.1,"Moving hull position replicates")
			check(await wait_for(func():return game.battery_tanks.rows[0].hp==60),"Half grenade damage replicates")
			check(await wait_for(func():return not game.battery_tanks.mounted(1) and not game.fighters[1].vehicle_seated),"Dismount releases crew and restores player collider")
			check(await wait_for(func():return game.battery_tanks.rows[0].hp==0 and game.battery_tanks.bodies[0].collision_layer==0),"Destroyed hull is disabled on client")
	print("CQ_BATTERY_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
