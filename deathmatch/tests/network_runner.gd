extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var game
var role := ""
var failures: Array = []
var peer_id := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func wait_for(condition: Callable,seconds: float = 8) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await pause(.05)
	return false

func run() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size()>0 else "server"
	game = load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	Fixture.setup(game)
	await process_frame
	if role=="server": await server_run()
	else: await client_run()
	print("NETWORK_RESULT ",role," ",JSON.stringify({"failures":failures}))
	game.disconnect_game("Test completed")
	await pause(.1)
	quit(0 if failures.is_empty() else 1)

func server_run() -> void:
	game.dedicated = true
	game.start_host("Test",27777,20,10,false)
	check(await wait_for(func(): return game.players.size()==2),"Two ENet clients joined")
	if game.players.size()!=2: return
	var shooter := 0
	var target := 0
	for id in game.players:
		if game.players[id].name=="Shooter": shooter=id
		else: target=id
	check(shooter!=0 and target!=0,"Nicknames and distinct peer identities")
	game.fighters[shooter].position=Fixture.point()
	game.fighters[target].position=Fixture.point(0,-1)
	for id in [shooter,target]:
		game.players[id].invulnerable=0;game.players[id].serial+=1
	game.players[shooter].ammo=[0,0,0,0]
	game._announcement.rpc("TEST_MELEE")
	check(await wait_for(func():return game.players[target].hp==90,3),"Remote VR weapon sweep deals authoritative melee damage with no ammo")
	await pause(.3)
	check(game.players[target].hp==90,"Remote weapon contact cannot register repeated melee hits")
	game._announcement.rpc("TEST_TRACKING_END")
	await pause(.2)
	game._announcement.rpc("TEST_TRACKING")
	check(await wait_for(func(): return game.players[shooter].xr.get("body",{}).has("left_foot"),3),"Body targets accepted through ENet input")
	await pause(.4)
	game._announcement.rpc("TEST_TRACKING_END")
	await pause(.3)
	game.fighters[shooter].position=Fixture.point()
	game.fighters[target].position=Fixture.point(2,-3)
	for id in [shooter,target]:game.players[id].serial+=1
	await pause(.2)
	game._announcement.rpc("TEST_ROOM")
	check(await wait_for(func():return game.fighters[shooter].position.x>Fixture.ORIGIN.x+.25,3),"Remote headset motion moves authoritative damage capsule")
	await pause(.3)
	check(game.fighters[shooter].position.x<Fixture.ORIGIN.x+.35,"Remote room-scale movement remains bounded below headset")
	game._announcement.rpc("TEST_TRACKING_END")
	await pause(.2)
	game.fighters[shooter].position = Fixture.point()
	game.fighters[target].position = Fixture.point(0,-2.7)
	for id in [shooter,target]:
		game.players[id].invulnerable = 0
		game.players[id].serial += 1
	game.players[target].hp = 60
	game.players[shooter].owned = [0,2,4]
	game.players[shooter].ammo = [50,20,0,0]
	await pause(.2)
	game._announcement.rpc("TEST_FIRE")
	check(await wait_for(func(): return game.players[target].dead,4),"Client input produces authoritative hitscan kill")
	game._announcement.rpc("TEST_STOP")
	check(game.players[shooter].kills==1 and game.players[target].deaths==1,"Frag and death credited")
	check(game.players[shooter].ammo[1]<=18 and game.players[shooter].ammo[1]>=16,"Two-shell cost and fire cooldown enforced")
	await pause(.5)
	check(game.players[shooter].ping>=0,"Ping exchange active")
	game.players[target].respawn_at = game.clock-.1
	game.players[target].want_respawn = true
	await pause(.2)
	check(not game.players[target].dead and game.players[target].hp==100,"Respawn restores health")
	check(game.players[target].owned==[2],"Respawn resets inventory")
	var pickup: Dictionary = game.pickups[0]
	pickup.kind="weapon";pickup.item=1;pickup.available=true
	pickup.position = game.fighters[shooter].position
	await pause(.2)
	check(game.players[shooter].owned.has(1) and not pickup.available,"Server awards pickup and removes it globally")
	pickup.respawn = game.clock+.1
	await pause(.3)
	check(pickup.available,"Timed pickup respawn")
	# Snapshotting moving projectiles must be visible to late/current peers.
	game.players[shooter].yaw = 0
	game.players[shooter].pitch = 0
	game._launch(shooter,7)
	check(game.projectiles.size()==1,"Server creates plasma projectile")
	await pause(.1)
	game._announcement.rpc("TEST_CHAT")
	check(await wait_for(func(): return game.last_event.contains("hello arena"),3),"Chat relayed through server")
	game.frag_limit = 1
	game._end_round()
	check(game.intermission>0 and not game.round_message.is_empty(),"Round enters intermission")
	game.intermission = .1
	await pause(.3)
	check(game.players[shooter].kills==0 and game.round_left>590,"Round restart resets score and timer")
	game._announcement.rpc("TEST_LEAVE")
	check(await wait_for(func(): return game.players.size()==1,3),"Peer disconnect removes marine")
	game.projectile_id += 1
	game._projectile_spawn.rpc(game.projectile_id,shooter,7,Vector3(0,20,0),Vector3.UP,0.0,0.0)
	game.gates[0].until = game.clock+20
	game._gate_state.rpc(0,true)
	check(await wait_for(func(): return game.players.size()==2,5),"Client can rejoin an in-progress round")
	await pause(.2)
	game._announcement.rpc("TEST_DONE")
	await pause(.5)

func client_run() -> void:
	var is_shooter := role=="shooter"
	game.start_join("Shooter" if is_shooter else "Target","127.0.0.1",27777)
	check(await wait_for(func(): return game.active,8),"Connected and received roster")
	if not game.active: return
	check(await wait_for(func(): return game.players.size()==2,5),"Both marines replicated")
	var saw_death := false
	var saw_pickup := false
	var sent_chat := false
	var rejoined := false
	var saw_late_projectile := false
	var saw_late_gate := false
	var saw_tracking := false
	var saw_melee := false
	var melee_started := -1
	var saw_eyes:=false
	var completed := false
	var deadline := Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		if game.active:
			if game.feed.any(func(entry): return entry.text=="TEST_DONE"):
				completed = true
				break
			if rejoined:
				saw_late_projectile = saw_late_projectile or not game.projectiles.is_empty()
				saw_late_gate = saw_late_gate or game.gates[0].open
			for state in game.players.values():
				if state.dead: saw_death = true
				if state.owned.has(1): saw_pickup = true
			for actor in game.fighters.values():
				if actor.xr_pose.get("body",{}).has("left_foot"): saw_tracking=true
				if actor.xr_pose.get("face",{}).get("lids",false): saw_eyes=true
			if game.last_event=="TEST_MELEE":
				for state in game.players.values():
					if state.name=="Target" and state.hp==90:saw_melee=true
				if is_shooter:
					if melee_started<0:melee_started=Time.get_ticks_msec()
					game.set_physics_process(false);game.sequence+=1
					var command:Dictionary=game._local_command();command.map_epoch=game.map_epoch;command.yaw=0.0;command.melee=true
					command.xr=preload("res://deathmatch/vr/poses.gd").neutral()
					command.xr.right.origin=Vector3(minf(.2,-.8+(Time.get_ticks_msec()-melee_started)*.002),1.1,-.6)
					command.xr.weapon=command.xr.right
					game._input_command.rpc_id(1,command)
			if game.last_event=="TEST_TRACKING" and is_shooter:
				game.set_physics_process(false)
				game.sequence+=1
				var command: Dictionary=game._local_command()
				command.map_epoch=game.map_epoch
				command.xr=preload("res://deathmatch/vr/poses.gd").neutral()
				command.xr.face={"look":Vector2(.1,.05),"blink":Vector2(.5,.2),"gaze":true,"lids":true}
				command.xr.body={"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.15,.25,0))}
				game._input_command.rpc_id(1,command)
			if game.last_event=="TEST_TRACKING_END": game.set_physics_process(true)
			if game.last_event=="TEST_ROOM" and is_shooter:
				game.set_physics_process(false);game.sequence+=1
				var command:Dictionary=game._local_command();command.map_epoch=game.map_epoch;command.yaw=0
				command.xr=preload("res://deathmatch/vr/poses.gd").neutral()
				command.xr.head.origin.x=Fixture.ORIGIN.x+.3-game.fighters[game.multiplayer.get_unique_id()].target.x
				command.room=preload("res://deathmatch/vr/room_scale.gd").request(command.xr.head.origin)
				game._input_command.rpc_id(1,command)
			if game.last_event=="TEST_FIRE" and is_shooter:
				game.local_yaw=0;game.local_pitch=0
				game.desired_weapon = 4
				game.fire_down = true
			if game.last_event=="TEST_STOP": game.fire_down = false
			if game.last_event=="TEST_CHAT" and is_shooter and not sent_chat:
				game.chat_send("hello arena")
				sent_chat = true
			if game.last_event=="TEST_LEAVE" and not is_shooter and not rejoined:
				game.disconnect_game("rejoin test")
				await pause(.5)
				game.start_join("Target","127.0.0.1",27777)
				rejoined = true
		await pause(.02)
	check(saw_melee,"Melee damage replicated to both clients")
	check(saw_eyes,"Measured eye data replicated in multiplayer snapshot")
	check(saw_tracking,"Body tracking replicated in multiplayer snapshot")
	check(saw_death,"Death replicated to client")
	check(saw_pickup,"Pickup inventory replicated to client")
	check(completed,"Completed network scenario")
	if not is_shooter:
		check(saw_late_projectile,"Late join restores in-flight projectile")
		check(saw_late_gate,"Late join restores open door")
