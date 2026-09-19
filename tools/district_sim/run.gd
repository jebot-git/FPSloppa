extends SceneTree
const Wire=preload("res://tools/district_sim/wire.gd")
const OUT="res://test-results/district-sim/"
var options: Dictionary
var server:=TCPServer.new()
var connections: Array=[]
var workers: Dictionary={}
var worker_pids: Dictionary={}
var pids: Array=[]
var owners: Dictionary={}
var transactions: Dictionary={}
var receipts: Array=[]
var rollbacks: Array=[]
var reject_used:=false
var stale_tested:=false
var stats: Dictionary={}
var failures: Array=[]
var view
var label: Label
var active_zone:=0
var begun:=0
var snapshots:=0
var discarded:=0
var duplicate_acks:=0
var frames: Array=[]
var ages: Array=[]
var last_frame:=0
var last_hud:=0
var walk_index:=0
var stopping:=false
var stopped: Dictionary={}
var final_snapshot: Dictionary={}
func _initialize():run.call_deferred()
func check(ok: bool,what: String) -> void:
	if not ok:failures.append(what);push_error(what)
func distribution(values: Array) -> Dictionary:
	values.sort()
	if values.is_empty():return {}
	return {"mean":values.reduce(func(a,b):return a+b,0.0)/values.size(),"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values.back(),"samples":values.size()}
func run() -> void:
	options={"zones":16,"seconds":32,"speed":1,"port":29341,"name":"districts1x"}
	if OS.get_cmdline_user_args().size()>0:options.merge(JSON.parse_string(OS.get_cmdline_user_args()[0]),true)
	Engine.max_fps=120
	DirAccess.make_dir_recursive_absolute(OUT)
	if server.listen(int(options.port),"127.0.0.1")!=OK:push_error("District broker port unavailable");quit(1);return
	if DisplayServer.get_name()!="headless":
		view=preload("res://tools/district_sim/view.gd").new()
		if not view.setup(self):
			push_error("District viewer setup failed");view.close();server.stop();quit(1);return
		var overlay:=CanvasLayer.new();root.add_child(overlay);label=Label.new();overlay.add_child(label);label.position=Vector2(16,16);label.add_theme_color_override("font_outline_color",Color.BLACK);label.add_theme_constant_override("outline_size",6);label.text="Starting isolated districts…"
		DisplayServer.window_set_title("FPSloppa — isolated district simulation")
	for zone in int(options.zones):
		var args:=PackedStringArray(["--headless","--xr-mode","off","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path(OUT+str(options.name)+"-worker-%02d.log"%zone),"--script","res://tools/district_sim/worker.gd","--",JSON.stringify({"zone":zone,"port":options.port})])
		var pid:=OS.create_process(OS.get_executable_path(),args)
		if pid<0:check(false,"Worker process launch failed");break
		pids.append(pid)
		# Stagger startup resource imports; all simulations wait at the ready barrier.
		await create_timer(.15).timeout
	var deadline:=Time.get_ticks_msec()+120000
	while workers.size()<int(options.zones) and failures.is_empty():
		await process_frame;poll()
		if pids.any(func(pid):return not OS.is_process_running(pid)):check(false,"Worker exited before ready barrier");break
		if Time.get_ticks_msec()>deadline:check(false,"Worker readiness timeout");break
	if not failures.is_empty():await finish();return
	check(owners.size()==int(options.zones)*4,"Initial actor ownership count")
	begun=Time.get_ticks_msec();last_frame=Time.get_ticks_usec()
	for zone in workers:workers[zone].send({"kind":"start","speed":options.speed})
	workers[0].send({"kind":"subscribe","enabled":true})
	print("DISTRICTS_STARTED ",workers.size()," actors=",owners.size()," speed=",options.speed)
	while Time.get_ticks_msec()-begun<float(options.seconds)*1000 and failures.is_empty():
		await process_frame
		var now:=Time.get_ticks_usec();var delta: float=(now-last_frame)/1000000.0;last_frame=now
		poll()
		if Time.get_ticks_msec()-begun>5000:frames.append(delta*1000)
		if view:view.frame(minf(delta,.1));if view.received_at>0:ages.append(Time.get_ticks_msec()-view.received_at)
		walk_test()
		for key in transactions:
			if not transactions[key].status in ["done","rolled_back"] and Time.get_ticks_msec()-transactions[key].started>5000:check(false,"Transfer timeout; stop all authorities: "+key)
		if label and Time.get_ticks_msec()-last_hud>250:
			last_hud=Time.get_ticks_msec();var clocks: Array=stats.values().map(func(row):return row.clock);clocks.sort()
			label.text="1 km² | %d independent districts | %d actors | target %sx\nViewing district %d: %d actors | %d FPS | %d transfers\nSlowest district %.1f sim s / %.1f wall s | snapshot age %d ms"%[workers.size(),owners.size(),options.speed,active_zone,view.game.players.size(),Engine.get_frames_per_second(),receipts.size(),clocks[0] if not clocks.is_empty() else 0,(Time.get_ticks_msec()-begun)/1000.0,Time.get_ticks_msec()-view.received_at]
	await finish()
func poll() -> void:
	while server.is_connection_available():connections.append(Wire.new(server.take_connection()))
	for connection in connections:
		for message in connection.poll():handle(connection,message)
		if connection.failed:check(false,"Bounded district transport failed")
		if begun>0 and not stopping and connection.peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:check(false,"District authority disconnected; stopping prototype")
func handle(connection,message: Dictionary) -> void:
	var zone: int=message.zone
	match message.kind:
		"ready":
			if workers.has(zone):check(false,"Duplicate district authority");return
			workers[zone]=connection;worker_pids[zone]=message.pid
			for id in message.ids:check(not owners.has(id),"Duplicate actor on startup");owners[id]=zone
			check(message.pickups==8 and message.spawns==4,"District content partition")
		"stats":stats[zone]=message
		"snapshot":
			if zone!=active_zone:discarded+=1;return
			snapshots+=1;final_snapshot=message.snapshot
			if view:
				var accepted: bool=view.apply(message.snapshot,view.zone!=zone)
				if accepted and not stale_tested:
					check(not view.apply(message.snapshot),"Duplicate view sequence rejected")
					var stale: Dictionary=message.snapshot.duplicate(true);stale.sequence-=1;check(not view.apply(stale),"Stale view sequence rejected")
					stale.zone=(zone+1)%16;stale.sequence+=10000;check(not view.apply(stale),"Other district snapshot rejected");stale_tested=true
		"offer":
			var id: int=message.actor.id;var key: String=message.tx;var target: int=message.target
			if stopping or not workers.has(target):connection.send({"kind":"rollback","tx":key});return
			check(owners.get(id,-1)==zone,"Transfer offered by non-owner")
			if transactions.has(key):return
			transactions[key]={"status":"offered","source":zone,"target":target,"id":id,"actor":message.actor,"started":Time.get_ticks_msec()}
			var prepare: Dictionary={"kind":"prepare","tx":key,"actor":message.actor}
			if options.get("reject_once",false) and not reject_used:prepare.reject=true;reject_used=true
			workers[target].send(prepare);workers[target].send(prepare) # Deliberate replay exercises idempotence.
		"prepared":
			var key: String=message.tx
			if not transactions.has(key):return
			var tx: Dictionary=transactions[key]
			if tx.status!="offered":duplicate_acks+=1;return
			check(zone==tx.target and message.has("snapshot"),"Destination must acknowledge a complete snapshot")
			tx.status="committing";tx.snapshot_bytes=var_to_bytes(message.snapshot).size();tx.prepared_sequence=message.snapshot.sequence
			workers[zone].send({"kind":"commit","tx":key});workers[zone].send({"kind":"commit","tx":key})
		"committed":
			var key: String=message.tx
			if not transactions.has(key):return
			var tx: Dictionary=transactions[key]
			if tx.status=="done":duplicate_acks+=1;return
			check(zone==tx.target and tx.status=="committing","Commit acknowledgement owner")
			var preserved:=true
			for field in ["hp","armor","ammo","owned","weapon","kills","deaths","serial","cooldown","offhand_cooldown","charge","benchmark_stamp"]:
				if tx.actor.state.get(field)!=message.actor.state.get(field):preserved=false
			for field in ["position","velocity","body","avatar"]:
				if tx.actor[field]!=message.actor[field]:preserved=false
			for field in preload("res://tools/district_sim/state.gd").DEADLINES:
				if absf(tx.actor.state.get(field,0)-message.actor.state.get(field,0))>.001:preserved=false
			check(preserved,"Transfer preserves actor inventory, health, body and relative timers")
			check(message.snapshot.actors.filter(func(row):return row.id==tx.id).size()==1,"Committed snapshot has exactly one incoming actor")
			owners[tx.id]=zone;tx.status="done";workers[tx.source].send({"kind":"release","tx":key})
			receipts.append({"id":tx.id,"source":tx.source,"target":zone,"latency_ms":Time.get_ticks_msec()-tx.started,"snapshot_bytes":tx.snapshot_bytes,"state_preserved":preserved,"prepared_sequence":tx.prepared_sequence,"commit_sequence":message.snapshot.sequence})
			if tx.id==-1:
				workers[active_zone].send({"kind":"subscribe","enabled":false});active_zone=zone;workers[zone].send({"kind":"subscribe","enabled":true});final_snapshot=message.snapshot
				if view:view.apply(message.snapshot,true)
			print("DISTRICT_TRANSFER ",JSON.stringify(receipts.back()))
		"rejected":
			var tx: Dictionary=transactions.get(message.tx,{})
			if tx.is_empty() or tx.status!="offered":duplicate_acks+=1;return
			tx.status="rolling_back";workers[tx.target].send({"kind":"cancel","tx":message.tx});workers[tx.source].send({"kind":"rollback","tx":message.tx})
		"rolled_back":
			var tx: Dictionary=transactions.get(message.tx,{})
			if tx.is_empty() or tx.status!="rolling_back":return
			check(zone==tx.source,"Rollback restored source authority");tx.status="rolled_back";rollbacks.append({"source":zone,"id":tx.id,"latency_ms":Time.get_ticks_msec()-tx.started});walk_index=maxi(0,walk_index-1)
		"stopped":stopped[zone]=true
func walk_test() -> void:
	var limit:=4 if int(options.zones)==16 else 1
	if walk_index>=limit or Time.get_ticks_msec()-begun<6000+walk_index*5000:return
	if transactions.values().any(func(tx):return not tx.status in ["done","rolled_back"]):return
	var route: Array=[{"source":0,"position":Vector3(-252,.1,-375),"target":Vector3(-246,.1,-375)},{"source":1,"position":Vector3(-125,.1,-252),"target":Vector3(-125,.1,-246)},{"source":5,"position":Vector3(-248,.1,-125),"target":Vector3(-254,.1,-125)},{"source":4,"position":Vector3(-375,.1,-248),"target":Vector3(-375,.1,-254)}]
	var row: Dictionary=route[walk_index]
	if owners.get(-1,-1)!=row.source:return
	workers[row.source].send({"kind":"walk","id":-1,"position":row.position,"target":row.target,"stamp":100+walk_index});walk_index+=1
func finish() -> void:
	stopping=true
	for zone in workers:workers[zone].send({"kind":"stop"})
	var deadline:=Time.get_ticks_msec()+5000
	while stopped.size()<workers.size() and Time.get_ticks_msec()<deadline:await process_frame;poll()
	check(stopped.size()==workers.size(),"All district workers stopped cleanly at report barrier")
	var active: Dictionary={};var clocks: Array=[];var memory:=0.0;var events: Dictionary={};var pending:=0
	for row in stats.values():
		clocks.append(row.clock);memory+=row.memory_bytes;pending+=int(row.escrow)
		for id in row.active:check(not active.has(id),"Duplicate active actor after transfers");active[id]=row.zone
		for event in row.events:events[event]=events.get(event,0)+row.events[event]
	clocks.sort();check(active.size()==int(options.zones)*4 and pending==0,"All actors conserved with no pending escrow")
	check(active==owners,"Broker directory agrees with district owners")
	check(receipts.size()>0 or float(options.seconds)<7,"At least one physical gate transfer completed")
	if int(options.zones)==16 and float(options.seconds)>=26:check(receipts.filter(func(row):return row.id==-1).size()>=4,"Four scripted gate crossings completed")
	var result: Dictionary={"map_sha256":FileAccess.get_sha256("res://maps/Benchmark1km/prototype_km1.bsp"),"options":options,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"districts":workers.size(),"worker_pids":worker_pids,"population":active.size(),"frames_ms":distribution(frames),"snapshot_age_ms":distribution(ages),"transfers":receipts,"rollbacks":rollbacks,"stale_view_checks":stale_tested,"duplicate_acknowledgements":duplicate_acks,"current_district_snapshots":snapshots,"discarded_other_district_snapshots":discarded,"worker_stats":stats,"slowest_sim_seconds":clocks[0] if not clocks.is_empty() else 0,"fastest_sim_seconds":clocks.back() if not clocks.is_empty() else 0,"workers_static_bytes":memory,"viewer_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"transport_received_bytes":connections.reduce(func(total,channel):return total+channel.received,0),"transport_sent_bytes":connections.reduce(func(total,channel):return total+channel.sent,0),"events":events,"viewer_peak_actors":view.peak_actors if view else 0,"failures":failures}
	if view:
		await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png(OUT+str(options.name)+".png");view.close()
	FileAccess.open(OUT+str(options.name)+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	for pid in pids:
		if OS.is_process_running(pid):OS.kill(pid)
	server.stop();print("DISTRICT_RESULT ",JSON.stringify({"population":active.size(),"transfers":receipts.size(),"frames_ms":result.frames_ms,"failures":failures}));quit(0 if failures.is_empty() else 1)
