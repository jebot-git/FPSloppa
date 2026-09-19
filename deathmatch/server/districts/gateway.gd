extends Node
## CQ-only public ENet gateway. Workers alone simulate actors and combat.
const State=preload("res://deathmatch/server/districts/state.gd")
const Wire=preload("res://deathmatch/server/districts/wire.gd")
const Rules=preload("res://deathmatch/conquest/rules.gd")
const Replication=preload("res://deathmatch/network/replication.gd")
const Codec=preload("res://deathmatch/network/snapshot_codec.gd")
const Events=preload("res://deathmatch/server/districts/events.gd")
var game
var listener:=TCPServer.new()
var port:=0
var limit:=16
var workers: Dictionary={}
var connections: Array=[]
var owners: Dictionary={}
var streams: Dictionary={}
var sleeping: Dictionary={}
var closing:=false
var heartbeat_at:=0
var reset_pending: Dictionary={}
var epoch:=1
var stats: Dictionary={"transfers":0,"inputs":0,"stale_inputs":0,"baselines":0,"events":0,"max_workers":0}
func setup(arena,worker_limit: int) -> void:
	game=arena;limit=worker_limit
	for attempt in 20:
		port=randi_range(30000,39999)
		if listener.listen(port,"127.0.0.1")==OK:return
	fail("Cannot bind private worker transport")
func fail(reason: String) -> void:
	if closing:return
	push_error("CQ_GATEWAY_FAILURE "+reason);game.server_log.record("cq_failure",{"reason":reason})
	game._announcement.rpc("CQ district server stopped: "+reason)
	stop();game.disconnect_game("CQ district server stopped: "+reason);get_tree().quit(3)
func stop() -> void:
	if closing:return
	closing=true;listener.stop()
	for wire in connections:wire.peer.disconnect_from_host()
	for worker in workers.values():
		if OS.is_process_running(worker.pid):OS.kill(worker.pid)
	workers.clear();connections.clear()
func _exit_tree() -> void:stop()
func need(zone: int) -> bool:
	if workers.has(zone):return true
	# Empty workers can be replaced; no actor or pending transaction may reference them.
	if workers.size()>=limit:
		for other in workers.keys():
			var w: Dictionary=workers[other]
			if reset_pending.has(other) or owners.values().any(func(o):return o.zone==other or o.get("source",-1)==other):continue
			if not w.get("snapshot",{}).get("projectiles",[]).is_empty():continue
			sleeping[other]={"pickups":w.snapshot.get("pickups",[]).duplicate(true),"at":w.get("snapshot_at",game.clock)}
			if w.wire:w.wire.peer.disconnect_from_host();connections.erase(w.wire)
			if OS.is_process_running(w.pid):OS.kill(w.pid)
			workers.erase(other);break
	if workers.size()>=limit:fail("Active districts exceed configured worker limit");return false
	var token:=Crypto.new().generate_random_bytes(32).hex_encode()
	var args:=PackedStringArray(["--headless","--xr-mode","off"])
	if OS.has_feature("editor"):args.append_array(["--path",ProjectSettings.globalize_path("res://")])
	var log_dir:=ProjectSettings.globalize_path("user://cq-workers")
	DirAccess.make_dir_recursive_absolute(log_dir)
	args.append_array(["--log-file",log_dir+"/worker-%d.log"%zone,"--","--experimental-cq","--cq-worker",str(zone),"--worker-port",str(port),"--worker-token",token,"--asset-root",game.Maps.Paths.root()])
	var pid:=OS.create_process(OS.get_executable_path(),args)
	if pid<0:fail("Worker launch failed");return false
	workers[zone]={"pid":pid,"token":token,"wire":null,"ready":false,"last":Time.get_ticks_msec(),"sequence":-1,"snapshot":{}}
	stats.max_workers=maxi(stats.max_workers,workers.size());return true
func send(zone: int,message: Dictionary) -> void:
	if not workers.has(zone) or not workers[zone].ready:return
	message.epoch=epoch;message.map_epoch=game.map_epoch;message.friendly_fire=game.match_mode.friendly_fire;workers[zone].wire.send(message)
func admit(id: int) -> void:
	var zone:=State.district(game.fighters[id].position)
	var gen: int=owners.get(id,{}).get("generation",0)+1
	owners[id]={"zone":zone,"generation":gen,"phase":"waiting","actor":State.actor(game,id),"ack":id<0,"started":Time.get_ticks_msec(),"last_seq":-1,"baseline":true}
	streams.erase(id)
	if id>0:game._cq_transition.rpc_id(id,game.map_epoch,gen,zone)
	if reset_pending.is_empty():need(zone)
func remove(id: int) -> void:
	if not owners.has(id):return
	var o: Dictionary=owners[id]
	# Remove at every potential owner, including staged transfers, before retiring identity.
	for zone in workers:send(zone,{"kind":"retire","id":id})
	owners.erase(id);streams.erase(id)
func ready(id: int,generation: int) -> void:
	if owners.has(id) and owners[id].generation==generation:owners[id].ack=true;progress(id)
func progress(id: int) -> void:
	if not owners.has(id) or not reset_pending.is_empty():return
	var o: Dictionary=owners[id]
	if not workers.has(o.zone):need(o.zone);return
	if not workers[o.zone].ready:return
	if o.phase=="waiting" and o.ack:
		o.phase="admitting";send(o.zone,{"kind":"admit","actor":o.actor,"id":id,"generation":o.generation})
	elif o.phase=="preparing":
		o.phase="prepared_wait";send(o.zone,{"kind":"prepare","tx":o.tx,"actor":o.actor,"generation":o.generation})
	elif o.phase=="prepared" and o.ack:
		o.phase="committing";send(o.zone,{"kind":"commit","tx":o.tx})
func input(id: int,command: Dictionary) -> void:
	if not owners.has(id):return
	var o: Dictionary=owners[id]
	if o.phase!="active" or command.get("cq_generation",-1)!=o.generation or command.seq<=o.last_seq:
		stats.stale_inputs+=1;return
	o.last_seq=command.seq;stats.inputs+=1
	send(o.zone,{"kind":"input","id":id,"generation":o.generation,"gateway_clock":game.clock,"ping":game.players[id].ping,"command":command})
func action(id: int,kind: String) -> void:
	if owners.has(id) and owners[id].phase=="active":send(owners[id].zone,{"kind":"action","id":id,"generation":owners[id].generation,"action":kind})
func _process(_delta: float) -> void:
	if closing:return
	while listener.is_connection_available():
		var peer:=listener.take_connection()
		if connections.size()>=limit+2:peer.disconnect_from_host();continue
		connections.append(Wire.new(peer))
	for wire in connections.duplicate():
		for message in wire.poll():handle(wire,message)
		if closing:return
		if wire.failed:fail("Worker transport exceeded bounds");return
	var now:=Time.get_ticks_msec()
	for zone in workers:
		var w: Dictionary=workers[zone]
		if not OS.is_process_running(w.pid) or now-w.last>(5000 if w.ready else 60000):fail("District %d unavailable"%zone);return
		if w.ready and w.wire.peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:fail("District %d disconnected"%zone);return
	for id in owners.keys():
		progress(id)
		if owners[id].phase!="active" and now-owners[id].started>60000:fail("Actor handoff timed out");return
	if now-heartbeat_at>=250:
		heartbeat_at=now
		for zone in workers:send(zone,{"kind":"heartbeat","rules":game.match_mode.conquest.rules.snapshot(),"running":game.intermission<=0 and reset_pending.is_empty()})
func handle(wire,message: Dictionary) -> void:
	var zone: int=message.get("zone",-1)
	if not workers.has(zone):wire.peer.disconnect_from_host();return
	var w: Dictionary=workers[zone]
	if message.get("kind","")=="hello":
		if w.ready or message.get("token")!=w.token or message.get("pid")!=w.pid or message.get("map")!=game.map_sha or message.get("schema")!=State.SCHEMA:wire.peer.disconnect_from_host();return
		w.wire=wire;w.ready=true;w.last=Time.get_ticks_msec();wire.send({"kind":"welcome","token":w.token});w.erase("token")
		var parked: Dictionary=sleeping.get(zone,{})
		var items: Array=parked.get("pickups",[]).duplicate(true)
		for item in items:
			item.respawn=maxf(0,item.respawn-(game.clock-float(parked.get("at",game.clock))))
			if item.respawn<=0:item.available=true
		send(zone,{"kind":"start","pickups":items});sleeping.erase(zone);print("CQ_WORKER_READY zone=",zone);return
	if not w.ready or w.wire!=wire or message.get("epoch",-1)!=epoch:return
	w.last=Time.get_ticks_msec()
	match message.kind:
		"snapshot":
			var snap: Dictionary=message.snapshot
			if snap.sequence<=w.sequence:return
			w.sequence=snap.sequence;w.snapshot=snap;w.snapshot_at=game.clock
			for row in snap.actors:
				var id: int=row.id
				if not owners.has(id) or not game.players.has(id):continue
				var o: Dictionary=owners[id]
				if o.zone!=zone or message.generations.get(id,-1)!=o.generation or o.phase not in ["active","admitting"]:continue
				apply(row)
				if o.phase=="admitting":o.phase="active"
			for item in snap.pickups:
				for target in game.pickups:
					if target.position==item.position:target.available=item.available;target.respawn=game.clock+item.respawn;break
			for event in message.get("events",[]):
				if event is Array and event.size()==2 and event[0] in Events.ALLOWED:
					for id in owners:
						if id>0 and owners[id].zone==zone and owners[id].phase=="active" and not owners[id].baseline:game._cq_event.rpc_id(id,game.map_epoch,owners[id].generation,event[0],event[1]);stats.events+=1
		"offer":
			var id: int=message.actor.id
			if not owners.has(id):send(zone,{"kind":"retire","id":id});return
			var o: Dictionary=owners[id]
			if o.zone!=zone or o.phase!="active" or message.generation!=o.generation:fail("Invalid ownership offer");return
			if not State.valid(message.actor) or State.district(message.actor.position)!=message.target:fail("Invalid transfer destination");return
			o.source=zone;o.zone=message.target;o.actor=message.actor;o.tx=message.tx;o.generation+=1;o.phase="preparing";o.ack=id<0;o.started=Time.get_ticks_msec();o.baseline=true
			streams.erase(id)
			if id>0:game._cq_transition.rpc_id(id,game.map_epoch,o.generation,o.zone)
			need(o.zone)
		"prepared":
			for id in owners:
				var o: Dictionary=owners[id]
				if o.get("tx","")==message.tx and o.zone==zone and o.phase=="prepared_wait":o.phase="prepared";progress(id);break
		"committed":
			for id in owners:
				var o: Dictionary=owners[id]
				if o.get("tx","")!=message.tx or o.zone!=zone or o.phase!="committing":continue
				apply(message.actor);send(o.source,{"kind":"release","tx":o.tx});send(zone,{"kind":"forget","tx":o.tx})
				o.phase="active";o.erase("source");o.erase("actor");o.erase("tx");stats.transfers+=1
				print("CQ_HANDOFF id=",id," zone=",zone," generation=",o.generation);break
		"rejected":fail("Destination rejected transfer")
		"reset":reset_pending.erase(zone)
func advance(delta: float) -> void:
	if not reset_pending.is_empty():return
	if owners.is_empty():return
	if workers.values().any(func(w):return w.ready and Time.get_ticks_msec()-w.last>1000):return
	if game.intermission>0:
		game.intermission-=delta
		if game.intermission<=0:game._restart_round()
		return
	game.round_left=maxf(0,game.round_left-delta)
	if game.round_left<=0:game._end_round()
	else:game.match_mode.conquest.tick(delta)
func reset_round() -> void:
	sleeping.clear()
	var next:=epoch+1
	for zone in workers:
		if workers[zone].ready:send(zone,{"kind":"reset","next_epoch":next});reset_pending[zone]=true
	epoch=next
	for id in game.players:admit(id)
func scoped(state: Array,id: int) -> Array:
	var zone: int=owners[id].zone
	var result:=state.duplicate(true)
	var visible: Array=owners.keys().filter(func(other):return owners[other].zone==zone and owners[other].phase=="active")
	result[0]=result[0].filter(func(row):return row[0] in visible)
	result[7]=[];result[10].ordnance={}
	var snap: Dictionary=workers[zone].snapshot
	for p in snap.get("projectiles",[]):
		result[7].append([p.id,p.position,p.owner,p.weapon,p.direction,p.yaw,p.pitch])
		if p.has("definition"):result[10].ordnance[p.id]={"extra":p.extra,"velocity":p.velocity,"life":p.life,"stuck":p.stuck}
	result[13]=snap.get("watermark",zone*100000000)
	result[10].cq_district=zone
	for key in ["locomotion","movement_ack","weapon_charge"]:
		for other in result[10].get(key,{}).keys():
			if other not in visible:result[10][key].erase(other)
	for index in game.pickups.size():
		if State.district(game.pickups[index].position)!=zone:result[1][index]=0
	return result
func replicate(state: Array) -> void:
	for id in owners:
		var o: Dictionary=owners[id]
		if id<0 or o.phase!="active" or not workers.has(o.zone):continue
		var snapshot:=scoped(state,id)
		if o.baseline:
			var bytes:=Codec.pack(snapshot)
			if bytes.is_empty():fail("District baseline too large");return
			game._cq_baseline.rpc_id(id,game.map_epoch,o.generation,bytes);o.baseline=false;stats.baselines+=1
		if not streams.has(id):streams[id]=Replication.new()
		var packets: Dictionary=streams[id].packets(snapshot)
		for bytes in packets.normal:game.bandwidth.reserve(bytes.size()+80,game.clock);game._cq_state.rpc_id(id,game.map_epoch,o.generation,bytes)
		for bytes in packets.large:game.bandwidth.reserve(bytes.size()+80,game.clock);game._cq_large.rpc_id(id,game.map_epoch,o.generation,bytes)

func diagnostics() -> Dictionary:
	var actors: Array=[]
	for id in owners:
		var o: Dictionary=owners[id]
		actors.append({"id":id,"zone":o.zone,"generation":o.generation,"phase":o.phase,"input_sequence":o.last_seq,"position":str(game.fighters[id].position) if game.fighters.has(id) else ""})
	return {"backend":"districts","workers":workers.size(),"limit":limit,"worker_pids":workers.keys().reduce(func(result,z):result[z]=workers[z].pid;return result,{}),"stats":stats.duplicate(),"actors":actors,"epoch":epoch}

func apply(row: Dictionary) -> void:
	# Admission, model choice and transport RTT remain owned by the gateway.
	row.state.ping=game.players[row.id].ping
	row.avatar=game.avatars.choices.get(row.id,{})
	State.apply(game,row)
