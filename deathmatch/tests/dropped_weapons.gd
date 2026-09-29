extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	game.active=true;game.spawn_points=[Vector3(1000,10,1000)];game.spawn_yaws=[0.0]
	game._add_player(1,"Human");game._add_player(-1,"Bot")
	for rules in ["doom","quake","ut99","cs16"]:
		game.match_mode.kind="dm";game.armory.select(rules)
		for victim in [1,-1]:
			game._spawn(victim)
			var state: Dictionary=game.players[victim]
			game._damage(victim,victim,10000,"TEST",true)
			check(game.dropped_weapons.entries.is_empty(),rules+": starting weapon is not dropped for "+str(victim))
			game._spawn(victim);state.owned.append(3);state.weapon=3;state.ammo=[13,17,19,23]
			var ammo: int=game.armory.pickup_ammo(3)
			game._damage(victim,victim,10000,"TEST",true)
			check(game.dropped_weapons.entries.size()==1,rules+": equipped acquired weapon drops on death for "+str(victim))
			game._damage(victim,victim,10000,"TEST",true)
			check(game.dropped_weapons.entries.size()==1,"Repeated damage cannot duplicate a drop")
			var wire: Array=game.dropped_weapons.snapshot()
			var replica=load("res://deathmatch/dropped_weapons.gd").new();replica.game=game;replica.receive(wire);replica.receive(wire)
			check(replica.snapshot()==wire,"Late join / repeated snapshot restores exactly one drop")
			replica.receive([]);check(replica.entries.is_empty(),"Absent drop is removed from replica")
			var other: int=-1 if victim==1 else 1
			game._spawn(other);game.fighters[other].position=wire[0][1];game.players[other].ammo=[0,0,0,0]
			game._collect(other)
			check(game.players[other].owned.has(3) and game.players[other].ammo[game.armory.data(3).ammo]==ammo,"Living player collects weapon with standard pickup ammo")
			if rules=="ut99":check(not game.players[other].owned.has(9),"Dropped Shock Rifle does not grant a bundled sniper")
			game._respawn_pickups();check(game.dropped_weapons.entries.is_empty(),"Consumed drop is removed without respawning")
	game._spawn(1);game.players[1].owned.append(6);game.players[1].weapon=6
	game._damage(1,1,10000,"TEST",true);game.clock+=31;game._respawn_pickups()
	check(game.dropped_weapons.entries.is_empty(),"Unclaimed drop expires")
	game._spawn(1);game.players[1].owned.append(6);game.players[1].weapon=6
	for i in 70:game.dropped_weapons.drop(1)
	check(game.dropped_weapons.entries.size()==64,"Drop count remains bounded")
	game.lobby.build();check(game.dropped_weapons.entries.is_empty(),"Lobby transition clears drops")
	game.lobby.prepare();game.lobby.until=game.clock+45
	game._send_snapshot()
	var snap: Array=[[],PackedByteArray(),45.0,0.0,"",20,600.0,[],[],game.map_epoch,{"kind":"dm","lobby":game.lobby.snapshot(),"weapon_rules":"ut99","dropped_weapons":[[101,Vector3.ZERO,3,17]]},{}]
	snap[10].merge(game.match_mode.snapshot(),false)
	var frame: Dictionary={"time":0.0,"map":game.current_map,"hash":game.map_sha,"roster":[],"avatars":{},"snapshot":snap,"events":[["_pickup_event",[1,"weapon",3,3,true]]]}
	check(game.demos.valid_frame(frame),"New pickup events pass the demo schema")
	game.demos.apply_frame(frame,false)
	check(game.dropped_weapons.entries.has(101),"Replay restores recorded drops")
	frame.snapshot[10].erase("dropped_weapons");frame.events=[["_pickup_event",[1,"weapon",3,3]]]
	check(game.demos.valid_frame(frame),"Legacy pickup events remain readable")
	game.demos.apply_frame(frame,false)
	check(game.dropped_weapons.entries.is_empty(),"Seeking to a legacy or empty frame removes stale drops")
	game.active=false;game.free();print("DROPPED_WEAPONS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
