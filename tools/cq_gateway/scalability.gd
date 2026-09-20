extends Node
## Isolated capacity experiments. Does not change admission limits or launch services.
const State=preload("res://deathmatch/server/districts/state.gd")
const Rules=preload("res://deathmatch/conquest/rules.gd")
const Replication=preload("res://deathmatch/network/replication.gd")
class Arena extends "res://deathmatch/arena.gd":
	func _start_dedicated(_args: PackedStringArray) -> void:pass
class Worker extends "res://deathmatch/server/districts/worker.gd":
	# Benchmarks keep synthetic actors alive locally without a master respawn service.
	func request_respawn(_id: int) -> bool:return false
class Peer extends RefCounted:
	func get_status():return StreamPeerTCP.STATUS_CONNECTED
	func disconnect_from_host():pass
class Sink extends RefCounted:
	var peer=Peer.new()
	var failed:=false
	var bytes:=0
	var largest:=0
	var messages:=0
	func poll() -> Array:return []
	func send(value: Dictionary):
		var size:=var_to_bytes(value).size()+4
		bytes+=size;largest=maxi(largest,size);messages+=1
		if size>1048580:failed=true
class Gateway extends "res://deathmatch/server/districts/gateway.gd":
	var encoded_bytes:=0
	var packet_count:=0
	var scope_us:=0
	var encode_us:=0
	var baseline_raw:=0
	var shared:=false
	func replicate(state: Array) -> void:
		encoded_bytes=0;packet_count=0;scope_us=0;encode_us=0;baseline_raw=0
		var seen: Dictionary={}
		for id in owners:
			var zone: int=owners[id].zone
			if shared and seen.has(zone):continue
			seen[zone]=true
			var recipients: int=owners.values().filter(func(o):return o.zone==zone).size() if shared else 1
			var before:=Time.get_ticks_usec()
			var snapshot:=scoped(state,id)
			scope_us+=Time.get_ticks_usec()-before
			before=Time.get_ticks_usec()
			if not streams.has(id):streams[id]=Replication.new()
			var packets: Dictionary=streams[id].packets(snapshot)
			for bytes in packets.normal+packets.large:encoded_bytes+=bytes.size()*recipients;packet_count+=recipients
			encode_us+=Time.get_ticks_usec()-before
			# Separate from timed codec work; baseline sizes are recorded once below.
			if baseline_raw==0:baseline_raw=var_to_bytes(snapshot).size()
var game
var args: PackedStringArray
func arg(key: String,fallback: String) -> String:
	var at:=args.find(key);return args[at+1] if at>=0 and at+1<args.size() else fallback
func _ready():
	args=OS.get_cmdline_user_args();Engine.max_fps=60;Engine.physics_ticks_per_second=60
	get_tree().create_timer(300).timeout.connect(func():push_error("Scale watchdog");quit(2))
	run.call_deferred()
func summary(values: Array) -> Dictionary:
	var sorted:=values.duplicate();sorted.sort()
	return {"samples":sorted.size(),"mean":sorted.reduce(func(a,b):return a+b,0.0)/maxi(1,sorted.size()),"p50":sorted[int(sorted.size()*.5)],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"p99":sorted[mini(sorted.size()-1,int(sorted.size()*.99))],"max":sorted[-1]}
func run():
	seed(719)
	game=load("res://deathmatch/arena.tscn").instantiate();game.set_script(Arena);get_tree().root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.cq_profile=true
	game.match_mode.configure({"sv_gametype":"cq"});game.armory.select("ut99")
	game.dedicated=true;game.selected_map=game.match_mode.conquest.MAP_ID
	game.start_host("Capacity fixture",0,100,60,true)
	if not game.active:quit(2);return
	for id in game.players.keys():State.remove(game,id)
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	game.dedicated=false
	await get_tree().physics_frame
	if arg("--kind","master")=="master":await master()
	else:await worker()
	game.queue_free();await get_tree().process_frame;quit()
func add_actor(id: int,zone: int,index: int):
	game._add_player(id,"Load %d"%id)
	game.players[id].team=index%2
	game.players[id].cq_group_zone=zone%16;game.players[id].cq_started=true;game._spawn(id)
	game.fighters[id].position=Rules.center(zone%16)+Vector3((index%8)*3-10,.1,(index/8)*3-10)
	game.players[id].invulnerable=0.0
	if args.has("--xr"):
		game.players[id].xr=preload("res://deathmatch/vr/poses.gd").neutral();game.players[id].vr_device=true
func master():
	var districts:=int(arg("--districts","16"));var each:=int(arg("--players","4"));var n:=districts*each
	var gateway=Gateway.new();gateway.game=game;gateway.shared=args.has("--shared");game.add_child(gateway);gateway.set_process(false)
	var messages: Array=[]
	for z in districts:
		var actors: Array=[]
		var ordnance: Array=[]
		for i in each:
			var id:=1000+z*each+i;add_actor(id,z,i)
			gateway.owners[id]={"zone":z,"generation":1,"phase":"active","last_seq":0,"baseline":false}
			actors.append(State.actor(game,id))
		for i in int(arg("--ordnance","0")):
			ordnance.append({"id":z*100000000+i,"position":Rules.center(z%16)+Vector3(i*.2,1,0),"owner":1000+z*each,"weapon":6,"direction":Vector3.FORWARD,"yaw":0.0,"pitch":0.0,"definition":game.armory.data(6),"extra":{"alternate":false},"velocity":Vector3.FORWARD*22,"life":4.0,"stuck":false})
		gateway.workers[z]={"snapshot":{"projectiles":ordnance,"watermark":z*100000000},"wire":Sink.new(),"pid":0,"external":true,"ready":true}
		messages.append(var_to_bytes({"kind":"snapshot","zone":z,"epoch":1,"snapshot":{"actors":actors,"pickups":[],"projectiles":ordnance,"sequence":0},"generations":{}}))
	game.district_gateway=gateway
	var times: Array=[];var ingress: Array=[];var scope: Array=[];var encode: Array=[];var output: Array=[];var packets: Array=[];var capture: Array=[];var input_times: Array=[]
	var inputs: Dictionary={}
	for id in game.players:
		var command:={"seq":1,"move":Vector2(.5,.5),"yaw":.1,"pitch":0.0,"fire":false,"weapon":2,"slow":false,"respawn":false,"cq_generation":1,"map_epoch":game.map_epoch,"xr":game.players[id].xr,"input_life":game.players[id].serial}
		inputs[id]=game.NetCodec.pack(command)
	for iteration in int(arg("--iterations","60"))+5:
		var before:=Time.get_ticks_usec()
		# Exact production deserializer and actor application, excluding TCP, ownership validation and pickup/event routing.
		for bytes in messages:
			var decoded: Dictionary=bytes_to_var(bytes)
			for row in decoded.snapshot.actors:gateway.apply(row)
		var ingest: float=(Time.get_ticks_usec()-before)/1000.0
		for id in gateway.owners:gateway.owners[id].last_seq=-1
		before=Time.get_ticks_usec()
		for id in inputs:game._accept_input(id,game.NetCodec.unpack(inputs[id]))
		var input_time: float=(Time.get_ticks_usec()-before)/1000.0
		game.clock+=.05
		for id in game.players:
			game.players[id].last_seq=iteration;game.players[id].yaw=sin(iteration*.1+id)*PI
			game.fighters[id].position.x+=sin(iteration*.2+id)*.05
		before=Time.get_ticks_usec();game.match_mode.conquest.tick(1.0/60)
		var cap: float=(Time.get_ticks_usec()-before)/1000.0
		before=Time.get_ticks_usec();game._send_snapshot()
		var elapsed: float=(Time.get_ticks_usec()-before)/1000.0
		if iteration>=5:
			times.append(elapsed);ingress.append(ingest);scope.append(gateway.scope_us/1000.0);encode.append(gateway.encode_us/1000.0);output.append(gateway.encoded_bytes);packets.append(gateway.packet_count);capture.append(cap);input_times.append(input_time)
		await get_tree().process_frame
	print("CQ_SCALE ",JSON.stringify({"kind":"master","districts":districts,"players_per_district":each,"actors":n,"shared_encoding_proposal":gateway.shared,"xr":args.has("--xr"),"replication_ms":summary(times),"worker_ingress_ms":summary(ingress),"input_batch_ms":summary(input_times),"scope_ms":summary(scope),"encode_ms":summary(encode),"capture_tick_ms":summary(capture),"public_bytes_per_snapshot":summary(output),"public_packets_per_snapshot":summary(packets),"private_snapshot_bytes_total":messages.reduce(func(a,b):return a+b.size(),0),"baseline_uncompressed_bytes":gateway.baseline_raw,"beyond_current_limits":districts>16 or n>64}))
func worker():
	var n:=int(arg("--players","16"));var scenario:=arg("--scenario","movement")
	var worker=Worker.new();game.add_child(worker);worker.set_physics_process(false)
	worker.game=game;worker.zone=0;worker.wire=Sink.new();worker.booted=true;worker.authenticated=true;worker.running=true;worker.epoch=1;game.district_worker=worker
	game.pickups=game.pickups.filter(func(p):return State.district(p.position)==0)
	for i in n:
		var id:=1000+i;add_actor(id,0,i);worker.generation[id]=1
		game.players[id].owned=[2,3,5,6,7,8,9,10];game.players[id].weapon=[2,3,5,6,7,8,9,10][i%8];game.players[id].ammo=[9999,9999,9999,9999]
	var times: Array=[];var intervals: Array=[];var projects: Array=[];var started:=Time.get_ticks_msec();var last:=0;var ticks:=0;var sampled_start:=0
	var duration:=float(arg("--seconds","15"));var warmup:=3.0
	while Time.get_ticks_msec()-started<(duration+warmup)*1000:
		await get_tree().physics_frame
		var now:=Time.get_ticks_usec();var measuring:=Time.get_ticks_msec()-started>=warmup*1000
		if measuring and sampled_start==0:sampled_start=now;worker.wire.bytes=0;worker.wire.messages=0
		if measuring and last>0:intervals.append((now-last)/1000.0)
		last=now
		# Synthetic clients send normal input every other physics tick (30 Hz). No bot decision cost.
		var before:=Time.get_ticks_usec()
		for i in n:
			var id:=1000+i;var s: Dictionary=game.players[id]
			if s.dead:game._spawn(id);game.fighters[id].position=Rules.center(0)+Vector3((i%8)*3-10,.1,(i/8)*3-10)
			s.owned=[2,3,5,6,7,8,9,10];s.weapon=[2,3,5,6,7,8,9,10][i%8];s.ammo=[9999,9999,9999,9999]
			if State.district(game.fighters[id].position)!=0:game.fighters[id].position=Rules.center(0)
			if ticks%2==0:
				var command:={"seq":ticks,"move":Vector2(sin(ticks*.025+i),cos(ticks*.025+i)),"yaw":float(i)*TAU/n+ticks*.003,"pitch":0.0,"fire":scenario=="combat","weapon":s.weapon,"slow":false,"respawn":true,"input_life":s.serial,"view_time":-1.0}
				if args.has("--xr"):command.xr=preload("res://deathmatch/vr/poses.gd").neutral()
				worker.command({"kind":"input","epoch":1,"id":id,"generation":1,"gateway_clock":game.clock,"command":command})
		worker.last_contact=Time.get_ticks_msec();worker._physics_process(1.0/60)
		var elapsed: float=(Time.get_ticks_usec()-before)/1000.0
		if worker.wire.failed:push_error("Private wire message exceeded bound");quit(3);return
		if measuring:times.append(elapsed);projects.append(game.projectiles.size())
		ticks+=1
	var sample_seconds: float=(Time.get_ticks_usec()-sampled_start)/1000000.0
	print("CQ_SCALE ",JSON.stringify({"kind":"worker","scenario":scenario,"actors":n,"tick_ms":summary(times),"interval_ms":summary(intervals),"physics_ticks_per_second":times.size()/sample_seconds,"sample_seconds":sample_seconds,"projectiles":summary(projects),"snapshot_messages":worker.wire.messages,"private_bytes_per_second":worker.wire.bytes/sample_seconds,"largest_private_message":worker.wire.largest,"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"beyond_current_limits":n>64}))

func quit(code: int=0):get_tree().quit(code)
