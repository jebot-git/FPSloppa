extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var game
var role := ""
var failures: Array = []
var peer_id := 0
class ReplicaProbe extends Node:
	var rocket_seen: Dictionary={}
	@rpc("any_peer","call_remote","reliable")
	func observed_rocket() -> void:
		if multiplayer.is_server():rocket_seen[multiplayer.get_remote_sender_id()]=true
var probe: ReplicaProbe

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
	probe=ReplicaProbe.new();probe.name="ReplicaProbe";root.add_child(probe)
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
	check(await wait_for(func(): return game.players.size()==3),"Two players and a spectator joined through ENet")
	if game.players.size()!=3: return
	var shooter := 0
	var target := 0
	for id in game.players:
		if game.players[id].name=="Shooter": shooter=id
		elif game.players[id].name=="Target": target=id
	check(shooter!=0 and target!=0,"Nicknames and distinct peer identities")
	game.fighters[shooter].position=Fixture.point(0,6)
	game.fighters[target].position=Fixture.point(-6,6)
	for id in [shooter,target]:game.players[id].serial+=1
	await pause(.2)
	game._announcement.rpc("TEST_MOVEMENT")
	var airborne:=false
	for i in 32:
		await pause(.05)
		airborne=airborne or game.fighters[shooter].position.y>Fixture.ORIGIN.y+.5
	check(airborne and game.fighters[shooter].position.z<Fixture.ORIGIN.z,"Remote movement and manual jump run through the authoritative Quake simulation")
	game._announcement.rpc("TEST_MOVEMENT_END")
	await pause(.2)
	for id in [shooter,target]:
		game.fighters[id].velocity=Vector3.ZERO;game.fighters[id].blast_velocity=Vector2.ZERO
	game.fighters[shooter].position=Fixture.point(0,6)
	game.players[shooter].serial+=1
	await pause(.3)
	game._announcement.rpc("TEST_JUMP_PULSE")
	check(await wait_for(func():return game.fighters[shooter].position.y>Fixture.ORIGIN.y+.5,2),"One-physics-frame jump survives the gap between client network sends")
	game._announcement.rpc("TEST_TRACKING_END")
	await pause(.2)
	game.fighters[shooter].velocity=Vector3.ZERO
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
	await pause(.9)
	game.players[target].hp=100
	await pause(.2)
	game._announcement.rpc("TEST_KICK")
	check(await wait_for(func():return game.players[shooter].get("left_kick",{}).get("hit",false) and game.players[target].hp==90,3),"Remote tracked kick deals authoritative damage through ENet")
	await pause(.2)
	check(game.players[target].hp==90,"Holding the remote foot in contact cannot repeatedly hit")
	game._announcement.rpc("TEST_TRACKING_END")
	await pause(.2)
	game.players[shooter].ammo=[50,0,0,0]
	game.players[target].hp=1000
	game._announcement.rpc("TEST_DUAL")
	check(await wait_for(func():return game.players[target].hp<1000,3),"Remote secondary trigger fires from its independent VR aim")
	await pause(.3)
	check(game.players[shooter].ammo[0]<50 and game.players[shooter].cooldown==0,"Offhand fire spends shared bullets without primary cooldown")
	game._announcement.rpc("TEST_TRACKING_END")
	await pause(.3)
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
	game._announcement.rpc("TEST_ROCKET")
	game._blast(game.fighters[shooter].position+Vector3(-.5,.1,0),shooter,128,5.76)
	await pause(.35)
	check(game.fighters[shooter].position.y>Fixture.ORIGIN.y+1 and game.fighters[shooter].blast_velocity.length()>1,"Server retains rocket jump during remote input simulation")
	# Do not erase this transient state while a slower client is still rendering
	# buffered snapshots. Every peer must actually observe both replicated fields.
	check(await wait_for(func():return probe.rocket_seen.size()==3,3),"All peers acknowledge replicated rocket position and knockback")
	for id in [shooter,target]:
		game.fighters[id].velocity=Vector3.ZERO;game.fighters[id].blast_velocity=Vector2.ZERO
		game.players[id].serial+=1
	game.fighters[shooter].position=Fixture.point();game.fighters[target].position=Fixture.point(0,-2.7)
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
	game.players[target].respawn_at = game.clock-4
	game.players[target].want_respawn = true
	check(await wait_for(func():return not game.players[target].dead and game.players[target].hp==100,1),"Respawn restores health")
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
	check(await wait_for(func(): return game.players.size()==2,3),"Peer disconnect removes marine")
	game.projectile_id += 1
	game._projectile_spawn.rpc(game.projectile_id,shooter,7,Vector3(0,20,0),Vector3.UP,0.0,0.0)
	game.gates[0].until = game.clock+20
	game._gate_state.rpc(0,true)
	check(await wait_for(func(): return game.players.size()==3,5),"Client can rejoin an in-progress round")
	await pause(.2)
	game._announcement.rpc("TEST_DONE")
	await pause(.5)

func client_run() -> void:
	var is_shooter := role=="shooter"
	game.start_join("Shooter" if is_shooter else "Observer" if role=="spectator" else "Target","127.0.0.1",27777,role=="spectator")
	check(await wait_for(func(): return game.active,8),"Connected and received roster")
	if not game.active: return
	check(await wait_for(func(): return game.players.size()==3,5),"Players and spectator replicated")
	var saw_death := false
	var saw_pickup := false
	var sent_chat := false
	var rejoined := false
	var saw_late_projectile := false
	var saw_late_gate := false
	var saw_tracking := false
	var saw_melee := false
	var saw_rocket:=false
	var saw_dual:=false
	var saw_fingers:=false
	var melee_started := -1
	var saw_eyes:=false
	var kick_started:=-1
	var saw_kick:=false
	var pulse_sent:=false
	var movement_started:=-1
	var saw_movement:=false
	var prediction_samples:=0
	var prediction_error:=0.0
	var completed := false
	var deadline := Time.get_ticks_msec()+25000
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
				if game.last_event=="TEST_MOVEMENT" and actor.visual_velocity.length()>7 and actor.target.y>Fixture.ORIGIN.y+.3:saw_movement=true
				if not saw_rocket and actor.blast_velocity.length()>1 and actor.target.y>Fixture.ORIGIN.y+.5:
					saw_rocket=true;probe.observed_rocket.rpc_id(1)
				if actor.xr_pose.get("body",{}).has("left_foot"): saw_tracking=true
				if actor.xr_pose.get("body",{}).get("left_curls",PackedFloat32Array())==PackedFloat32Array([0,.25,.5,.75,1]): saw_fingers=true
				if actor.xr_pose.has("offhand_weapon") and game.players.values().any(func(s):return s.offhand_cooldown>0): saw_dual=true
				if actor.xr_pose.get("face",{}).get("lids",false): saw_eyes=true
			if game.last_event=="TEST_MOVEMENT" and is_shooter:
				if movement_started<0:
					movement_started=Time.get_ticks_msec();game.local_yaw=0;game.menu_open=false
					game.bindings.keys.forward=KEY_W;game.bindings.keys.jump=KEY_SPACE
					for keycode in [KEY_W,KEY_SPACE]:
						var key:=InputEventKey.new();key.physical_keycode=keycode;key.pressed=true;Input.parse_input_event(key)
				if Time.get_ticks_msec()-movement_started>600:
					var own=game.fighters[game.multiplayer.get_unique_id()]
					prediction_error+=own.position.distance_to(own.target);prediction_samples+=1
			elif movement_started>=0:
				for keycode in [KEY_W,KEY_SPACE]:
					var key:=InputEventKey.new();key.physical_keycode=keycode;key.pressed=false;Input.parse_input_event(key)
				movement_started=-1
			if game.last_event=="TEST_JUMP_PULSE" and is_shooter and not pulse_sent:
				pulse_sent=true;game.set_physics_process(false);game.input_accumulator=0;game.menu_open=false
				var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;Input.parse_input_event(key);Input.flush_buffered_events()
				game._physics_process(1.0/60)
				key=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
				game._physics_process(1.0/60);game.set_physics_process(true)
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
			if game.last_event=="TEST_DUAL" and is_shooter:
				game.set_physics_process(false);game.sequence+=1
				var command:Dictionary=game._local_command();command.map_epoch=game.map_epoch;command.yaw=0.0;command.weapon=2
				command.fire=false;command.offhand_fire=true;command.melee=false
				command.xr=preload("res://deathmatch/vr/poses.gd").neutral()
				command.xr.offhand_weapon=command.xr.left
				command.xr.weapon.basis=Basis(Vector3.UP,PI/2)
				game._input_command.rpc_id(1,command)
			if game.last_event=="TEST_KICK":
				for state in game.players.values():
					if state.name=="Target" and state.hp==90:saw_kick=true
				if is_shooter:
					if kick_started<0:kick_started=Time.get_ticks_msec()
					game.set_physics_process(false);game.sequence+=1
					var command:Dictionary=game._local_command();command.map_epoch=game.map_epoch;command.yaw=0;command.melee=true
					command.xr=preload("res://deathmatch/vr/poses.gd").neutral()
					command.xr.body={"left_foot":Transform3D(Basis.IDENTITY,Vector3(0,.35,maxf(-.8,-(Time.get_ticks_msec()-kick_started)*.0035)))}
					game._input_command.rpc_id(1,command)
			if game.last_event=="TEST_TRACKING" and is_shooter:
				game.set_physics_process(false)
				game.sequence+=1
				var command: Dictionary=game._local_command()
				command.map_epoch=game.map_epoch
				command.xr=preload("res://deathmatch/vr/poses.gd").neutral()
				command.xr.face={"look":Vector2(.1,.05),"blink":Vector2(.5,.2),"gaze":true,"lids":true}
				command.xr.body={"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.15,.25,0)),"left_curls":PackedFloat32Array([0,.25,.5,.75,1])}
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
				var fire_event:=InputEventMouseButton.new();fire_event.button_index=MOUSE_BUTTON_LEFT;fire_event.pressed=true;Input.parse_input_event(fire_event)
			if game.last_event=="TEST_STOP":
				var fire_event:=InputEventMouseButton.new();fire_event.button_index=MOUSE_BUTTON_LEFT;fire_event.pressed=false;Input.parse_input_event(fire_event)
			if game.last_event=="TEST_CHAT" and is_shooter and not sent_chat:
				game.chat_send("hello arena")
				sent_chat = true
			if game.last_event=="TEST_LEAVE" and role=="target" and not rejoined:
				game.disconnect_game("rejoin test")
				await pause(.5)
				game.start_join("Target","127.0.0.1",27777)
				rejoined = true
		await pause(.02)
	check(saw_rocket,"Rocket position and knockback replicate to players and spectator")
	check(saw_kick,"Tracked kick damage replicates to both players and spectator")
	check(saw_movement,"Quake running and jumping replicate to players and spectator")
	if is_shooter:check(prediction_samples>0 and prediction_error/maxi(1,prediction_samples)<1.0,"Client movement prediction stays close to authoritative snapshots")
	check(saw_dual,"Secondary pistol pose and cooldown replicate to both clients")
	check(saw_fingers,"Independent finger curls replicate to both clients")
	check(saw_melee,"Melee damage replicated to both clients")
	check(saw_eyes,"Measured eye data replicated in multiplayer snapshot")
	check(saw_tracking,"Body tracking replicated in multiplayer snapshot")
	check(saw_death,"Death replicated to client")
	check(saw_pickup,"Pickup inventory replicated to client")
	check(completed,"Completed network scenario")
	if role=="spectator":
		var own:Dictionary=game.local_state()
		check(own.spectator and own.dead and own.deaths==0,"Observer remains outside combat across the round restart")
	if role=="target":
		check(saw_late_projectile,"Late join restores in-flight projectile")
		check(saw_late_gate,"Late join restores open door")
