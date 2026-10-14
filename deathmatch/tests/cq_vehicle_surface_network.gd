extends "res://deathmatch/tests/cq_battery_network.gd"
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
func run() -> void:
	var role:String=OS.get_cmdline_user_args()[0]
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game)
	if role=="server":
		game.start_host("Crew",28811,100,10,false);check(await wait_for(func():return game.players.size()==2),"Remote observer joins")
		game.set_process(false);game.set_physics_process(false);game.battery_tanks.configure()
		var observer:int=game.players.keys().filter(func(id):return id!=1)[0];game.players[1].team=0;game.players[observer].team=1
		for key in [2,6]:
			var row:Dictionary=game.battery_tanks.rows[key]
			row.position=Vector3(key*30,.03,0);row.visual_y=.28;row.yaw=0;row.pilot=1;row.life=game.players[1].serial;row.team=0;game.battery_tanks.pose_body(key);game.battery_tanks.seat(1,key);game.players[1].invulnerable=game.clock+100
			game._send_snapshot();await create_timer(.7).timeout
			if key==2:game.battery_tanks.damage(key,1,250,"ordnance",observer)
			else:
				row.position=Vector3(-553,0,-650);row.position.y=Landscape.surface(row.position.x,row.position.z).x+.03;game.battery_tanks.pose_body(key);game.players[1].input_blocked=false;game.players[1].last_input=game.clock;game.battery_tanks.tick(.05)
			game._send_snapshot();await create_timer(.8).timeout
			check(game.players[1].dead and game.fighters[1].gibbed and row.pilot==0,"Authority gibs and releases crew "+str(key))
			game._spawn(1);game._send_snapshot();await create_timer(.5).timeout
	else:
		game.clock=500;game.start_join("Observer","127.0.0.1",28811);check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins with independent clock")
		for key in [2,6]:
			check(await wait_for(func():return game.battery_tanks.key_for(1)==key),"Occupied vehicle replicates "+str(key))
			check(await wait_for(func():return game.battery_tanks.rows.has(key) and game.battery_tanks.rows[key].hp==0 and game.players[1].dead and game.fighters[1].gibbed),"Wreck and fatal gib replicate "+str(key))
			check(not game.battery_tanks.mounted(1) and not game.fighters[1].vehicle_seated and not game.classes.downed.has(1),"Remote crew leaves seated/revivable state "+str(key))
			if key==2:check(game.local_state().kills==1,"Combat attacker receives kill credit remotely")
			check(await wait_for(func():return not game.players[1].dead),"Crew can respawn normally "+str(key))
	print("CQ_VEHICLE_SURFACE_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
