extends "res://deathmatch/tests/network_runner.gd"
const Poses=preload("res://deathmatch/vr/poses.gd")
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	var physical=game.match_mode.fortress.physical
	if role=="server":
		game.dedicated=true;game.match_mode.configure({"sv_gametype":"tf"});game.start_host("Physical network",27889,100,60,false,"tf")
		check(await wait_for(func():return game.players.size()==1,15),"VR client joins matching protocol")
		if game.players.size()==1:
			game.set_physics_process(false)
			var id: int=game.players.keys()[0];var s: Dictionary=game.players[id]
			s.tf_next="demoman";game._spawn(id);game.match_mode.fortress.cooldowns[id]=0;s.yaw=0;game.fighters[id].position=Fixture.point();game._send_snapshot()
			check(await wait_for(func():return s.get("physical",false) and not s.xr.is_empty(),8),"Fresh VR pose and physical setting arrive through input channel")
			game._server_tick(1.0/60)
			check(is_equal_approx(game.fighters[id].collision_height,.9) and s.xr.face.expression[0]>.5,"Server applies tracked crouch and accepts expression weights")
			game._announcement.rpc("ARM_READY")
			check(await wait_for(func():return physical.armed.has(id),8),"Offhand arming RPC uses authenticated sender")
			game._announcement.rpc("THROW_READY")
			check(await wait_for(func():return game.match_mode.fortress.charges.has(id),8),"Reliable grip release launches grenade")
			if game.match_mode.fortress.charges.has(id):
				check(s.ammo[2]==14 and game.match_mode.fortress.charges[id].velocity==Vector3(0,2,-4),"Network release preserves velocity and charges ammo once")
				await pause(.3)
				check(s.ammo[2]==14 and game.match_mode.fortress.charges.size()==1,"Duplicate and stale network releases are ignored")
				game._send_snapshot();await pause(.3)
				game.clock+=.8;game.match_mode.fortress.tick_charges(.1);game._send_snapshot();game._announcement.rpc("DETONATE_READY")
				check(await wait_for(func():return game.match_mode.fortress.charges.is_empty(),8),"Remote offhand action detonates pipe after arming delay")
				game._send_snapshot()
			game._announcement.rpc("PHYSICAL_DONE");await pause(1)
	else:
		game.start_join("Physical client","127.0.0.1",27889)
		check(await wait_for(func():return game.active and game.local_state().get("tf_class","")=="demoman",15),"Client receives authoritative class")
		game.set_physics_process(false)
		var s: Dictionary=game.local_state();var pose:=Poses.neutral()
		pose.head.origin.y=.8;pose.height=.9;pose.face={"look":Vector2.ZERO,"blink":Vector2.ZERO,"gaze":false,"lids":true,"expression":PackedFloat32Array([.7,0,0,0,0])}
		game._input_command.rpc_id(1,{"map_epoch":game.map_epoch,"seq":100000,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":6,"slow":false,"respawn":false,"physical":true,"xr":pose})
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="ARM_READY"),8),"Server accepts input before discrete action")
		physical.request.rpc_id(1,game.map_epoch-1,s.serial,1,"arm",pose,Vector3.ZERO)
		physical.request.rpc_id(1,game.map_epoch,s.serial-1,1,"arm",pose,Vector3.ZERO)
		physical.submit("arm",pose,Vector3.ZERO,1)
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="THROW_READY"),8),"Valid arm survives preceding stale map and life messages")
		physical.submit("throw",pose,Vector3(0,2,-4),2)
		physical.submit("throw",pose,Vector3(0,2,-4),2)
		physical.request.rpc_id(1,game.map_epoch-1,s.serial,3,"throw",pose,Vector3.ZERO)
		check(await wait_for(func():return not game.match_mode.fortress.charges.is_empty(),8),"Thrown projectile snapshot reaches client")
		check(is_equal_approx(game.fighters[game.multiplayer.get_unique_id()].collision_height,.9) and game.local_state().xr.face.expression[0]>.5,"Crouch collider and expression reach the client snapshot")
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="DETONATE_READY"),8),"Server simulates grenade flight")
		physical.submit("ability",pose,Vector3.ZERO,3)
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="PHYSICAL_DONE"),8),"Remote detonation completes")
		check(game.match_mode.fortress.charges.is_empty(),"Detonation removes replicated grenade")
	print("PHYSICAL_NETWORK_RESULT ",role," ",JSON.stringify(failures));game.disconnect_game();await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
