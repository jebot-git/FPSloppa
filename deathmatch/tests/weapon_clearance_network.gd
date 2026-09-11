extends "res://deathmatch/tests/network_runner.gd"
const Poses=preload("res://deathmatch/vr/poses.gd")
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	if role=="server":await authority()
	else:await client()
	print("WEAPON_CLEARANCE_NETWORK_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
func authority() -> void:
	game.dedicated=true;game.bind_address="127.0.0.1";game.start_host("Wall audit",28976,100,60,false)
	check(await wait_for(func():return game.players.size()==1,15),"Remote client joins clearance test")
	if game.players.size()!=1:return
	game.set_physics_process(false)
	var id: int=game.players.keys()[0];var s: Dictionary=game.players[id]
	game._add_player(-99,"Target behind wall");var target: Dictionary=game.players[-99]
	for index in 5:
		s.owned=[2,6];s.weapon=6 if index==3 else 2;s.ammo=[50,0,10,0];s.cooldown=0;s.offhand_cooldown=0;s.shots=0;s.held=false;s.dead=false;s.invulnerable=0
		target.hp=100;target.dead=false;target.invulnerable=0;target.armor=0
		game.fighters[id].position=Fixture.point(9.5 if index<2 else 9.0,0) if index<3 else Fixture.point(0,6)
		game.fighters[-99].position=Fixture.point(11.5,0) if index<3 else Fixture.point(0,3)
		game.fighters[id].velocity=Vector3.ZERO
		game._send_snapshot();game._announcement.rpc("WALL_CASE_"+str(index))
		check(await wait_for(func():return s.last_seq==100000+index),"Case %d receives authenticated input"%index)
		check(s.vr_device and not s.xr.is_empty(),"Case %d retains validated VR hand pose"%index)
		var solution: Dictionary=game._shot_solution(id,index==1)
		game._fire(id,index==1)
		if index<2:
			check(solution.blocked and s.shots==0 and s.ammo[0]==50 and target.hp==100,"Remote %s hand through wall causes no shot, ammo loss or damage"%("offhand" if index==1 else "main"))
		elif index==2:
			check(not solution.blocked and solution.clipped and solution.origin.x<Fixture.ORIGIN.x+9.875 and s.shots==1 and target.hp==100,"Remote protruding muzzle fires from near side and cannot damage covered target")
		elif index==3:
			check(not solution.blocked and solution.clipped and s.ammo[2]==9 and game.projectiles.size()==1,"Remote floor-pointing rocket launches from safe side")
			game._update_projectiles(.04)
			check(game.fighters[id].velocity.y>5 and s.hp<100,"Remote ground rocket retains rocket-jump impulse and self damage")
		else:check(s.shots==1 and target.hp<100,"Unobstructed remote pistol shot damages control target")
		game._send_snapshot()
	game._announcement.rpc("WALL_DONE");await pause(1)
func client() -> void:
	game.start_join("Tracked shooter","127.0.0.1",28976)
	check(await wait_for(func():return game.active and not game.local_state().is_empty(),15),"Client receives match")
	game.set_physics_process(false)
	for index in 5:
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="WALL_CASE_"+str(index))),"Client receives case %d"%index)
		var pose:=Poses.neutral()
		if index<3:
			pose.right.origin=Vector3(.8 if index<2 else .7,1.1,0)
			pose.weapon=Transform3D(Basis(Vector3.UP,-PI/2),pose.right.origin)
			pose.left.origin=pose.right.origin;pose.offhand_weapon=pose.weapon
		elif index==3:
			pose.right.origin=Vector3(.25,.45,-.3);pose.weapon=Transform3D(Basis(Vector3.RIGHT,-PI/2),pose.right.origin)
		game._input_command.rpc_id(1,{"map_epoch":game.map_epoch,"seq":100000+index,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":index!=1,"offhand_fire":index==1,"weapon":6 if index==3 else 2,"slow":false,"respawn":false,"xr":pose})
	check(await wait_for(func():return game.feed.any(func(e):return e.text=="WALL_DONE")),"Server completes all wall and rocket checks")
