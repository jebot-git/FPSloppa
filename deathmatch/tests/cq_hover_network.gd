extends "res://deathmatch/tests/cq_battery_network.gd"
func run() -> void:
	var role:String=OS.get_cmdline_user_args()[0]
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Test.TestArena);root.add_child(game)
	if role=="server":
		game.start_host("Hover authority",28809,100,10,false)
		check(await wait_for(func():return game.players.size()==2),"Observer joins authority")
		game.set_process(false);game.set_physics_process(false);game.battery_tanks.configure()
		for key in game.battery_tanks.rows:game.battery_tanks.rows[key].position=Vector3(key*25,.03,0);game.battery_tanks.rows[key].yaw=0;game.battery_tanks.rows[key].visual_y=.28;game.battery_tanks.pose_body(key)
		game.players[1].team=0;game.players[1].input_blocked=false;game.players[1].invulnerable=0
		await physics_frame;await physics_frame
		for key in [2,6]:
			var row:Dictionary=game.battery_tanks.rows[key];var config:Dictionary=game.battery_tanks.profile(row)
			game.players[1].use_at=0;game.fighters[1].position=row.position+Vector3(3.5,0,0);check(game.battery_tanks.use(1),"Authority boards "+row.kind);game._send_snapshot();await create_timer(.5).timeout
			game.players[1].pitch=1.2;game.players[1].yaw=.3;game.players[1].fire=true;game.players[1].move=Vector2(0,-1)
			for volley in config.capacity:
				game.clock+=1.5;game.players[1].last_input=game.clock;game.battery_tanks.tick(.05);game._send_snapshot();await create_timer(.2).timeout
			check(row.rounds==0,"Authority exhausts magazine "+row.kind);game._send_snapshot();await create_timer(.8).timeout
			game.battery_tanks.damage(key,1,100,"grenade");game._send_snapshot();await create_timer(.6).timeout
			game.battery_tanks.leave(1,true);game._send_snapshot();await create_timer(.6).timeout
		game.classes.states[1]["class"]="medic";game.classes.states[game.players.keys().filter(func(id):return id!=1)[0]]["class"]="medic"
		# Use the driver as an allied incapacitated target for the remote medic.
		game.players[1].team=game.players[game.players.keys().filter(func(id):return id!=1)[0]].team;game.classes.incapacitate(1,1,"TEST",false,false,false);game.classes.downed[1].remaining=6.0;game._send_snapshot();await create_timer(.8).timeout
	else:
		game.clock=500;game.start_join("Remote medic","127.0.0.1",28809)
		check(await wait_for(func():return game.active and not game.local_state().is_empty()),"Client joins at different clock")
		for key in [2,6]:
			check(await wait_for(func():return game.battery_tanks.key_for(1)==key),"Crew reservation replicates "+str(key))
			if not game.battery_tanks.rows.has(key):continue
			var row:Dictionary=game.battery_tanks.rows[key];var config:Dictionary=game.battery_tanks.profile(row)
			check(game.battery_tanks.rows.size()==8 and row.hp==config.hp,"All eight profiles and starting health replicate")
			check(await wait_for(func():return game.battery_tanks.rows[key].rounds==0 and game.battery_tanks.rows[key].reload_at>game.clock),"Magazine and reload replicate "+str(key))
			row=game.battery_tanks.rows[key]
			check(row.reload_at-game.clock>config.reload-.8 and row.reload_at-game.clock<=config.reload+.1,"Reload deadline adjusts to client clock "+str(key))
			check(rad_to_deg(asin(row.direction.y))<=config.pitch_max+.01 and row.visual_y-row.position.y<=.5,"Limited pitch and ride height replicate")
			var shots:Array=game.projectiles.values().filter(func(p):return p.extra.get("hover_shot","")==row.kind)
			check(shots.size()==config.capacity*config.pair and shots.all(func(p):return p.definition.gravity==0 and not p.definition.guided and p.definition.cq_effect=="ordnance"),"Exact unguided round count on remote client "+str(key))
			check(await wait_for(func():return game.battery_tanks.rows[key].hp==config.hp-50),"Half grenade damage replicates")
			check(await wait_for(func():return not game.battery_tanks.mounted(1)),"Dismount restores crew remotely")
		check(await wait_for(func():return game.classes.downed.has(1)),"Revival state replicates to remote medic")
		if game.classes.downed.has(1):check(is_equal_approx(game.classes.downed[1].remaining,6),"Remote pie uses server remaining time")
	print("CQ_HOVER_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
