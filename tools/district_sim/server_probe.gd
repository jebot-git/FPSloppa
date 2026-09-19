extends SceneTree
## Private loopback coordinator test, NOT a public ENet gateway.
const State=preload("res://deathmatch/server/districts/state.gd")
const Wire=preload("res://deathmatch/server/districts/wire.gd")
const Rules=preload("res://deathmatch/conquest/rules.gd")
var server:=TCPServer.new()
var connections: Array=[]
var workers: Dictionary={}
var tokens: Dictionary={}
var pids: Dictionary={}
var inbox: Array=[]
var snapshots: Dictionary={}
var failures: Array=[]
var checks:=0
var finished:=false
var game
var rules=Rules.new()
func _initialize():
	Engine.max_fps=60
	create_timer(100).timeout.connect(func():check(false,"Watchdog");finish())
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func send(zone: int,row: Dictionary) -> void:
	row.epoch=row.get("epoch",1);workers[zone].send(row)
func heartbeat(zone: int,running: bool=false) -> void:send(zone,{"kind":"heartbeat","rules":rules.snapshot(),"running":running})
func poll() -> void:
	while server.is_connection_available():connections.append(Wire.new(server.take_connection()))
	for wire in connections:
		for message in wire.poll():
			var zone: int=message.zone
			if message.kind=="hello":
				check(not workers.has(zone) and message.pid==pids.get(zone) and message.token==tokens.get(zone) and message.schema==State.SCHEMA and message.map==game.map_sha,"Authenticated expected worker/schema/map")
				if not failures.is_empty():continue
				workers[zone]=wire;wire.send({"kind":"welcome","token":tokens[zone]})
			elif workers.get(zone)==wire:
				inbox.append(message)
				if message.kind=="snapshot":snapshots[zone]=message.snapshot
		if wire.failed:check(false,"Transport failure")
func wait_for(predicate: Callable,seconds: float=5) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and failures.is_empty() and Time.get_ticks_msec()<deadline:
		await process_frame;poll()
	var ok: bool=predicate.call();check(ok,"Wait completed before timeout");return ok
func receive(kind: String,zone: int) -> Dictionary:
	if not await wait_for(func():return inbox.any(func(row):return row.kind==kind and row.zone==zone)):return {}
	for index in inbox.size():
		if inbox[index].kind==kind and inbox[index].zone==zone:
			var row: Dictionary=inbox[index];inbox.remove_at(index);return row
	return {}
func snap(zone: int) -> Dictionary:
	inbox=inbox.filter(func(row):return row.kind!="snapshot" or row.zone!=zone)
	heartbeat(zone)
	var row:=await receive("snapshot",zone);return row.get("snapshot",{})
func actor(snapshot: Dictionary,id: int) -> Dictionary:
	for row in snapshot.get("actors",[]):
		if row.id==id:return row
	return {}
func input(zone: int,row: Dictionary,generation: int,seq: int) -> void:
	send(zone,{"kind":"input","id":row.id,"generation":generation,"gateway_clock":100.0,"command":{"seq":seq,"move":Vector2(1,0),"yaw":0.0,"pitch":0.0,"fire":false,"weapon":row.state.weapon,"slow":false,"respawn":false,"input_life":row.state.serial,"view_time":99.92}})
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.cq_profile=true;check(game.match_mode.conquest.install().is_empty(),"CQ assets installed")
	game.match_mode.configure({"sv_gametype":"cq"});game.dedicated=true;game.selected_map=game.match_mode.conquest.MAP_ID
	game.start_host("Fixture",0,100,30,true)
	for id in game.players.keys():State.remove(game,id)
	game.clock=100.0;game._add_player(42,"Routed human")
	game.fighters[42].position=Vector3(-250.03,.1,-375);game.fighters[42].velocity=Vector3.ZERO
	var s: Dictionary=game.players[42];s.hp=73;s.armor=41;s.invulnerable=102.0;s.respawn_at=103.0;s.view_time=99.92;s.fire_pending=[s.weapon,1,100.25]
	s.melee_state={"time":99.9,"ready_at":100.4};s.offhand_melee_state={"swing_until":100.3}
	game.variant_combat.charging[42]={"weapon":s.weapon,"time":.4,"maximum":2.0}
	var fixture:=State.actor(game,42)
	var port:=29471
	check(server.listen(port,"127.0.0.1")==OK,"Loopback coordinator bound")
	var args:=OS.get_cmdline_user_args();var binary:=ProjectSettings.globalize_path("res://Builds/CQWorkerServer/FPSloppaServer.x86_64")
	if args.size()>0:binary=args[0]
	DirAccess.make_dir_recursive_absolute("res://test-results/district-sim")
	for zone in 2:
		tokens[zone]=Crypto.new().generate_random_bytes(32).hex_encode()
		var worker_args:=PackedStringArray(["--log-file",ProjectSettings.globalize_path("res://test-results/district-sim/server-worker-%d.log"%zone),"--","--experimental-cq","--cq-worker",str(zone),"--worker-port",str(port),"--worker-token",tokens[zone]])
		pids[zone]=OS.create_process(binary,worker_args);check(pids[zone]>0,"Console worker launched")
	if not await wait_for(func():return workers.size()==2,60):finish();return
	for zone in 2:send(zone,{"kind":"start","friendly_fire":true});heartbeat(zone)
	var settings:=await snap(0);await snap(1)
	check(settings.friendly_fire,"Workers receive authoritative friendly-fire policy")
	send(0,{"kind":"admit","actor":fixture,"generation":1})
	var row:=actor(await snap(0),42)
	if row.is_empty():check(false,"Actor admitted");finish();return
	check(row.state.hp==73 and row.state.armor==41 and row.charge.time==.4,"Health, armour, charge preserved")
	check(is_equal_approx(row.state.fire_pending[2],.25) and is_equal_approx(row.state.view_time,-.08),"Relative fire/view clocks")
	check(is_equal_approx(row.state.melee_state.ready_at,.4) and is_equal_approx(row.state.offhand_melee_state.swing_until,.3),"Nested melee deadlines")
	input(0,row,0,999);input(1,row,1,999)
	var before:=await snap(0);var wrong:=await snap(1)
	check(actor(before,42).state.last_seq==-1 and actor(wrong,42).is_empty(),"Stale generation and wrong owner reject input")
	input(0,row,1,17)
	row=actor(await snap(0),42);check(row.state.last_seq==17 and row.state.move==Vector2(1,0),"Production input routed to sole owner")
	heartbeat(0,true)
	var offer:=await receive("offer",0)
	if offer.is_empty():finish();return
	heartbeat(0)
	check(offer.target==1 and offer.actor.id==42,"Physical crossing offers destination")
	check(actor(await snap(0),42).is_empty() and actor(await snap(1),42).is_empty(),"Neither worker simulates actor in escrow")
	var prepare:={"kind":"prepare","tx":offer.tx,"actor":offer.actor,"generation":2}
	send(1,prepare);send(1,prepare)
	await receive("prepared",1);await receive("prepared",1)
	check(actor(await snap(1),42).is_empty(),"Prepare does not activate actor")
	send(1,{"kind":"commit","tx":offer.tx});send(1,{"kind":"commit","tx":offer.tx})
	var committed:=await receive("committed",1);await receive("committed",1)
	send(0,{"kind":"release","tx":offer.tx})
	var destination:=await snap(1)
	check(destination.actors.size()==1 and destination.actors[0].id==42 and actor(await snap(0),42).is_empty(),"Duplicate commit leaves exactly one authority")
	check(committed.actor.state.cq_wait_input,"Committed human waits for fresh generation input")
	check(committed.actor.state.view_time==-1 and committed.actor.state.hp==73,"Commit invalidates source lag timestamp, preserves health")
	input(1,row,1,999);send(1,{"kind":"input","epoch":0,"id":42,"generation":2,"command":{}})
	row=actor(await snap(1),42);check(row.state.last_seq==17,"Old generation and epoch rejected after migration")
	input(1,row,2,18);row=actor(await snap(1),42);check(row.state.last_seq==18 and not row.state.cq_wait_input,"Destination resumes only with fresh generation input")
	# Replayed commit must acknowledge its original receipt even after departure.
	send(1,{"kind":"remove","id":42})
	send(1,{"kind":"commit","tx":offer.tx})
	var replay:=await receive("committed",1)
	check(replay.actor==committed.actor and actor(await snap(1),42).is_empty(),"Late commit replay cannot resurrect departed actor")
	send(1,{"kind":"forget","tx":offer.tx})
	send(1,{"kind":"reset","next_epoch":2});var reset:=await receive("reset",1);check(reset.epoch==2,"Coordinated epoch reset acknowledged")
	send(1,{"kind":"admit","actor":fixture,"generation":1}) # Previous epoch: must be ignored.
	send(1,{"kind":"heartbeat","epoch":2,"rules":rules.snapshot(),"running":false})
	var empty:=await receive("snapshot",1);check(empty.snapshot.actors.is_empty(),"Old admission cannot repopulate reset worker")
	# Test peer loss: workers must exit instead of becoming an orphaned authority.
	for wire in connections:wire.peer.disconnect_from_host()
	await wait_for(func():return pids.values().all(func(pid):return not OS.is_process_running(pid)),5)
	finish()
func finish() -> void:
	if finished:return
	finished=true
	for wire in connections:wire.peer.disconnect_from_host()
	server.stop()
	for pid in pids.values():
		if OS.is_process_running(pid):OS.kill(pid)
	if is_instance_valid(game):game.disconnect_game();game.queue_free()
	var report:={"checks":checks,"failures":failures,"workers":2,"runtime":"console-only dedicated executable","scope":"Private coordinator and routed production inputs; no public ENet gateway or client prediction test."}
	FileAccess.open("res://test-results/district-sim/server-probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DISTRICT_SERVER_PROBE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
