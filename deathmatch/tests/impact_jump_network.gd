extends "res://deathmatch/tests/network_runner.gd"
class Observation extends Node:
	var seen: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func observed(index: int) -> void:
		if multiplayer.is_server():seen[index]=true
var observation: Observation
var dt:=1.0/120
func step() -> void:
	await physics_frame
	game.clock+=dt;game._server_tick(dt);game._send_snapshot()
func run() -> void:
	role=OS.get_cmdline_user_args()[0];dt=1.0/Engine.physics_ticks_per_second
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	observation=Observation.new();observation.name="HammerObservation";root.add_child(observation)
	if role=="server":await authority()
	else:await client()
	print("IMPACT_NETWORK_RESULT ",JSON.stringify({"role":role,"passed":failures.is_empty(),"failures":failures}))
	game.disconnect_game();await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
func authority() -> void:
	game.dedicated=true;game.bind_address="127.0.0.1";game.armory.select("ut99")
	game.start_host("Hammer jump",28991,100,60,false)
	check(await wait_for(func():return game.players.size()==1,20),"Real ENet client joins UT loadout")
	if game.players.is_empty():return
	game.set_physics_process(false);game.set_process(false)
	var id: int=game.players.keys()[0];var s: Dictionary=game.players[id];var actor=game.fighters[id]
	for index in 2:
		game.variant_combat.reset()
		s.merge({"weapon":0,"owned":[0,2],"hp":100,"armor":0,"dead":false,"invulnerable":0,"cooldown":0.,"shots":0,"fire":false,"alt_fire":false,"input_blocked":false,"jump":false,"xr":{},"vr_device":false,"pitch":-PI/2},true)
		actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.jump_held=false;actor.jump_queued=false
		game._send_snapshot();game._announcement.rpc("HAMMER_CHARGE_"+str(index))
		for i in ceili(3.5/dt):await step()
		check(game.variant_combat.charging.has(id) and s.shots==0 and s.hp==100,"Remote held charge survives maximum without auto-fire (%d)"%index)
		check(s.vr_device==(index==1),"Authority uses expected desktop/tracked pose (%d)"%index)
		game._announcement.rpc("HAMMER_RELEASE_"+str(index))
		var height:=0.0
		for i in ceili(2.0/dt):
			await step();height=maxf(height,actor.position.y-Fixture.ORIGIN.y)
		check(s.shots==1 and s.hp==64 and height>5,"Remote jump release produces one damaging surface boost (%d)"%index)
		check(observation.seen.has(index),"Owning client receives jump height and self damage (%d)"%index)
		print("IMPACT_NETWORK_APEX ",index," ",height)
	game._announcement.rpc("HAMMER_DONE");await pause(.3)
func client() -> void:
	game.start_join("Hammer client","127.0.0.1",28991)
	check(await wait_for(func():return game.active and not game.local_state().is_empty(),20),"Client admitted")
	game.set_physics_process(false);game.set_process(false)
	var seq:=10000
	for index in 2:
		check(await wait_for(func():return game.feed.any(func(e):return e.text=="HAMMER_CHARGE_"+str(index))),"Client receives charge case %d"%index)
		var reported:=false;var deadline:=Time.get_ticks_msec()+9000
		while Time.get_ticks_msec()<deadline:
			var releasing: bool=game.feed.any(func(e):return e.text=="HAMMER_RELEASE_"+str(index))
			var cmd:={"map_epoch":game.map_epoch,"seq":seq,"move":Vector2.ZERO,"yaw":0.,"pitch":-PI/2,"fire":not releasing,"alt_fire":false,"weapon":0,"slow":false,"respawn":false,"jump":releasing}
			if index==1:
				var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
				pose.right.origin=Vector3(.25,.6,-.3);pose.weapon=Transform3D(Basis(Vector3.RIGHT,-PI/2),pose.right.origin);cmd.xr=pose
			game._input_command.rpc_id(1,cmd);seq+=1
			var actor=game.fighters.get(game.multiplayer.get_unique_id())
			if releasing and not reported and actor and actor.target.y>Fixture.ORIGIN.y+3 and game.local_state().hp==64:
				observation.observed.rpc_id(1,index);reported=true
			if game.feed.any(func(e):return e.text=="HAMMER_CHARGE_"+str(index+1) or e.text=="HAMMER_DONE"):break
			await pause(.04)
		check(reported,"Client observes authoritative %s impact jump"%("tracked" if index else "desktop"))
	check(await wait_for(func():return game.feed.any(func(e):return e.text=="HAMMER_DONE")),"Server completed both network cases")
