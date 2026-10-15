extends "res://tools/voxel_battle/class_arena.gd"
## Opt-in live authority timings. Categories overlap: engine physics includes callbacks.
const Summary=preload("res://tools/voxel_battle/performance.gd")
var measured:Dictionary={"server_tick_ms":[],"projectiles_ms":[],"snapshot_send_ms":[],"history_ms":[],"physics_callback_ms":[],"engine_physics_ms":[],"wall_tick_interval_ms":[],"players":[],"snapshot_transport_ms":[],"snapshot_worker_ms":[],"snapshot_age_ms":[]}
var target_players:=32
var profile_seconds:=120.0
var profile_started:=0
var profile_last:=0
var profile_done:=false
var attribute_movement:=false
var stress:=false
var no_simulation:=false
var no_snapshots:=false
var trace_network:=false
var trace_next:=0
var trace_last:=0
var trace_poll_max:=0.0
var trace_poll_total:=0.0
var trace_polls:=0
var trace_poll_physics:=false
var trace_physics_since_idle:=0
var trace_max_batch:=0
func _ready() -> void:
	var args:=OS.get_cmdline_user_args();var i:=args.find("--profile-players")
	if i>=0:target_players=int(args[i+1])
	i=args.find("--profile-seconds")
	if i>=0:profile_seconds=float(args[i+1])
	stress=args.has("--stress-test");attribute_movement=args.has("--attribute-movement");Attribution.reset()
	no_simulation=args.has("--network-no-simulation");no_snapshots=args.has("--network-no-snapshots");trace_network=args.has("--trace-network");trace_poll_physics=args.has("--trace-poll-physics")
	super._ready()
	if trace_network:get_tree().multiplayer_poll=false
	if args.has("--trace-tune-buffer"):
		print("CQ_SOCKET_BUFFER ",JSON.stringify(preload("res://deathmatch/native/runtime.gd").backend().tune_udp_buffer(multiplayer.multiplayer_peer.host.get_local_port(),4194304)))
func sampling() -> bool:return profile_started>0 and not profile_done
func _server_tick(delta:float) -> void:
	if stress:
		for id in players:
			players[id].invulnerable=clock+1000
			players[id].ammo=[9999,9999,9999,9999]
	var began:=Time.get_ticks_usec()
	var token:=Attribution.begin("simulation.total")
	if not no_simulation:super._server_tick(delta)
	Attribution.end(token)
	if sampling():measured.server_tick_ms.append((Time.get_ticks_usec()-began)/1000.0)
func _update_projectiles(delta:float,movement_start:Dictionary={}) -> void:
	var began:=Time.get_ticks_usec();var token:=Attribution.begin("simulation.projectiles");super._update_projectiles(delta,movement_start);Attribution.end(token)
	if sampling():measured.projectiles_ms.append((Time.get_ticks_usec()-began)/1000.0)
func _send_snapshot() -> void:
	if no_snapshots:return
	var began:=Time.get_ticks_usec();var token:=Attribution.begin("snapshot.prepare");super._send_snapshot();Attribution.end(token)
	if sampling():measured.snapshot_send_ms.append((Time.get_ticks_usec()-began)/1000.0)
func _send_snapshot_packets(packets:Dictionary) -> void:
	var began:=Time.get_ticks_usec();var token:=Attribution.begin("snapshot.transport");super._send_snapshot_packets(packets);Attribution.end(token)
	if sampling():
		measured.snapshot_transport_ms.append((Time.get_ticks_usec()-began)/1000.0)
		if packets.has("encode_usec"):
			measured.snapshot_worker_ms.append(packets.encode_usec/1000.0)
			measured.snapshot_age_ms.append(maxf(0,clock-float(packets.time))*1000.0)

func _record_history() -> void:
	var began:=Time.get_ticks_usec();var token:=Attribution.begin("simulation.history");super._record_history();Attribution.end(token)
	if sampling():measured.history_ms.append((Time.get_ticks_usec()-began)/1000.0)
func _physics_process(delta:float) -> void:
	var began:=Time.get_ticks_usec()
	trace_physics_since_idle+=1
	if trace_network and trace_poll_physics:poll_network()
	if profile_started==0 and players.size()==target_players:
		profile_started=began;profile_last=began;print("CQ_LIVE_PROFILE_STARTED players=",target_players)
	Attribution.enabled=attribute_movement and sampling()
	var token:=Attribution.begin("callback.total")
	super._physics_process(delta)
	Attribution.end(token)
	if Attribution.enabled:Attribution.tick(Time.get_ticks_usec()-began,players.size())
	if sampling():
		measured.physics_callback_ms.append((Time.get_ticks_usec()-began)/1000.0)
		measured.engine_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		measured.wall_tick_interval_ms.append((began-profile_last)/1000.0);profile_last=began
		measured.players.append(players.size())
		if (began-profile_started)/1000000.0>=profile_seconds:finish_profile()
func finish_profile() -> void:
	profile_done=true;Attribution.enabled=false
	var report:Dictionary={"players":target_players,"wall_seconds":(Time.get_ticks_usec()-profile_started)/1000000.0,"tick_rate":Engine.physics_ticks_per_second,"achieved_tick_hz":measured.server_tick_ms.size()*1000000.0/(Time.get_ticks_usec()-profile_started),"AI":false,"rendering":false,"stress_infinite_ammo_invulnerable":stress,"bandwidth_realtime_bytes":bandwidth.realtime_bytes,"input_counters":server_log.counters,"categories_overlap":true,"replication":replication.stats,"native_backend":preload("res://deathmatch/native/runtime.gd").backend()!=null,"async_snapshots":replication.async_encoder!=null}
	report["authority_experiments"]={"player_state":native_player_state_enabled,"input_state":native_input_state_enabled,"fanout":native_snapshot_fanout_enabled,"buffers":OS.get_cmdline_user_args().has("--native-snapshot-buffers")}
	if replication.async_encoder and replication.async_encoder.has_method("snapshot_buffer_stats"):report["snapshot_buffers"]=replication.async_encoder.snapshot_buffer_stats()
	for key in measured:report[key]=Summary.summary(measured[key])
	if attribute_movement:report["attribution"]=Attribution.summary()
	DirAccess.make_dir_recursive_absolute("user://vps-validation")
	var f:=FileAccess.open("user://vps-validation/live-%d.json"%target_players,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	if attribute_movement:
		var args:=OS.get_cmdline_user_args();var at:=args.find("--attribution-output")
		var path:String=args[at+1] if at>=0 else "user://vps-validation/attribution-ticks.jsonl"
		var raw:=FileAccess.open(path,FileAccess.WRITE)
		raw.store_line(JSON.stringify({"scope_names":Attribution.names,"row_fields":["calls","inclusive_us","self_us","max_call_us"]}))
		for tick in Attribution.ticks:raw.store_line(JSON.stringify(tick))
		raw.close()
	print("CQ_LIVE_PROFILE_RESULT ",JSON.stringify(report))

func _process(delta:float) -> void:
	if trace_network:
		trace_max_batch=maxi(trace_max_batch,trace_physics_since_idle);trace_physics_since_idle=0
		poll_network()
		var now:=Time.get_ticks_msec()
		if now>=trace_next:
			var peers:Array=[]
			for id in multiplayer.get_peers():
				var row:Dictionary=server_log.transport(id);row.peer=id;row.admitted=players.has(id);peers.append(row)
			print("CQ_NETWORK_TRACE ",JSON.stringify({"wall_ms":now,"players":players.size(),"pending":pending_joins.size(),"transport":peers,"poll_max_ms":trace_poll_max,"poll_total_ms":trace_poll_total,"polls":trace_polls,"physics_batch_max":trace_max_batch,"replication":replication.stats}))
			trace_next=now+1000;trace_poll_max=0;trace_poll_total=0;trace_polls=0;trace_max_batch=0
	super._process(delta)

func poll_network() -> void:
	var started:=Time.get_ticks_usec();multiplayer.poll();var poll_ms:float=(Time.get_ticks_usec()-started)/1000.0
	trace_poll_max=maxf(trace_poll_max,poll_ms);trace_poll_total+=poll_ms;trace_polls+=1

func _accept_input(id:int,command:Dictionary) -> void:
	var token:=Attribution.begin("input.accept")
	super._accept_input(id,command);Attribution.end(token)
