extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var game
var role:=""
var shooter:=0
var target:=0
var phase:=0
var ready:=false
var fire_time:=0.0
var send_time:=0.0
var snapshots:=0.0
var hits:=0
var received_damage:=false
var saw_projectile:=false
var results: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func pause(t: float):await create_timer(t).timeout
func wait_for(fn: Callable,t: float=12) -> bool:
	var deadline:=Time.get_ticks_msec()+int(t*1000)
	while Time.get_ticks_msec()<deadline:
		if fn.call():return true
		await pause(.025)
	return false
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
	if role=="server":
		game.dedicated=true;game.start_host("Latency",27787,100,60,false)
	else:game.start_join(role,"127.0.0.1",27788 if role=="shooter" else 27789)
	check(await wait_for(func():return game.active and game.players.size()==2),"ENet join through impaired UDP link")
	game.set_physics_process(false)
	if game.players.size()==2:
		for id in game.players:
			if game.players[id].name=="shooter":shooter=id
			if game.players[id].name=="target":target=id
		ready=true
		if role=="server":await server_run()
		else:
			check(await wait_for(func():return game.feed.any(func(e):return e.text=="LAG_DONE"),35),"Scenario completes")
			check(received_damage,"Authoritative target damage replicates")
			check(saw_projectile,"Projectile state replicates")
	ready=false
	print("LAG_NETWORK_RESULT ",JSON.stringify({"role":role,"failures":failures,"weapons":results}))
	game.disconnect_game();game.free();await process_frame;quit(0 if failures.is_empty() else 1)
func server_run() -> void:
	for id in game.players:
		game.players[id].invulnerable=0;game.players[id].hp=1000000;game.players[id].armor=0
		game.players[id].owned=[2,6,7,9];game.players[id].ammo=[200,50,50,300];game.players[id].serial+=1
	game.fighters[shooter].position=Fixture.point()
	await pause(1.5)
	for weapon in [2,9,7,6]:
		phase=weapon;hits=0;game.history.clear()
		game.players[shooter].weapon=weapon;game.players[shooter].owned=[weapon];game.players[shooter].cooldown=0.0
		await pause(.7)
		hits=0
		var shots: int=game.players[shooter].shots
		game._announcement.rpc("LAG_"+str(weapon))
		await pause(4.5)
		game._announcement.rpc("LAG_STOP")
		await pause(.6)
		var count: int=game.players[shooter].shots-shots
		results.append({"weapon":weapon,"shots":count,"hits":hits,"ping_ms":game.players[shooter].ping})
		check(count>=2 and hits==count,"Weapon %d: %d/%d hits at measured %d ms RTT"%[weapon,hits,count,game.players[shooter].ping])
	phase=0
	var wall=Fixture.box(game,Fixture.point(0,-4)+Vector3.UP,Vector3(12,3,.05))
	await physics_frame;await physics_frame
	hits=0;game.players[shooter].weapon=9;game.players[shooter].owned=[9];game._announcement.rpc("LAG_9")
	await pause(2.0)
	game._announcement.rpc("LAG_STOP");await pause(.4)
	check(hits==0,"Networked railgun cannot damage through cover")
	wall.free();ready=false;game._announcement.rpc("LAG_DONE");await pause(.5)
func _physics_process(delta: float) -> bool:
	if not ready:return false
	game.clock+=delta
	if role=="server":
		var previous: Dictionary=game._history_positions()
		game.fighters[target].position=Fixture.point(3.0*sin(game.clock*3.0) if phase in [2,9] else 0.0,-8)
		game.fighters[target].velocity=Vector3(9.0*cos(game.clock*3.0) if phase in [2,9] else 0.0,0,0)
		game._record_history()
		var hp: int=game.players[target].hp
		var s: Dictionary=game.players[shooter]
		s.cooldown=maxf(0,s.cooldown-delta)
		if s.fire and game.clock-s.last_input<.35:game._fire(shooter)
		if not s.fire:s.held=false
		game._update_projectiles(delta,previous)
		if game.players[target].hp<hp:hits+=1
		snapshots+=delta
		if snapshots>=.05:snapshots=0;game._send_snapshot()
	else:
		game._interpolate_remote_players(delta)
		received_damage=received_damage or game.players[target].hp<1000000
		saw_projectile=saw_projectile or not game.projectiles.is_empty()
		game.ping_accumulator+=delta
		if game.ping_accumulator>1:game.ping_accumulator=0;game._ping.rpc_id(1,Time.get_ticks_msec())
		send_time+=delta
		if send_time>=1.0/30:
			send_time=0;game.sequence+=1
			var own: int=game.multiplayer.get_unique_id()
			var weapon: int=game.players[own].weapon
			var command: Dictionary={"map_epoch":game.map_epoch,"seq":game.sequence,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"weapon":weapon,"slow":false,"respawn":false,"view_time":game.remote_view_time}
			if role=="shooter" and game.last_event.begins_with("LAG_") and game.last_event not in ["LAG_STOP","LAG_DONE"]:
				var direction: Vector3=(game.fighters[target].position+Vector3.UP*1.25-game._shot_origin(own)).normalized()
				command.yaw=atan2(-direction.x,-direction.z);command.pitch=asin(direction.y)
				# Release between pistol shots to retain its perfectly accurate first bullet.
				command.fire=game.clock>=fire_time
				if command.fire:fire_time=game.clock+(1.65 if weapon==9 else .65 if weapon in [2,6] else .35)
			game._input_command.rpc_id(1,command)
	return false
