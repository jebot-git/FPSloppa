extends Node
## CQ-only public ENet gateway. Workers alone simulate actors and combat.
const External=preload("res://deathmatch/server/districts/external.gd")
const State=preload("res://deathmatch/server/districts/state.gd")
const Wire=preload("res://deathmatch/server/districts/wire.gd")
const Rules=preload("res://deathmatch/conquest/rules.gd")
const Capacity=preload("res://deathmatch/conquest/capacity.gd")
const Replication=preload("res://deathmatch/network/replication.gd")
const Codec=preload("res://deathmatch/network/snapshot_codec.gd")
const Events=preload("res://deathmatch/server/districts/events.gd")
var game
var external_session:=""
var connection_started: Dictionary={}
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
var capacity_counts: Array=[]
var capacity_revision:=0
var resetting:=false
var stats: Dictionary={"transfers":0,"inputs":0,"stale_inputs":0,"baselines":0,"events":0,"max_workers":0}
func setup(arena,worker_limit: int) -> void:
	game=arena;limit=worker_limit
	var path: String=game._arg_value(OS.get_cmdline_user_args(),"--cq-external-workers","")
	if not path.is_empty():
		var inventory:=External.gateway(path,limit)
		if inventory.has("error"):fail(inventory.error);return
		port=int(inventory.port);external_session=inventory.session
		if listener.listen(port,"127.0.0.1")!=OK:fail("Cannot bind external worker tunnel listener");return
		for row in inventory.workers:
			workers[int(row.zone)]={"external":true,"instance":row.instance,"pid":0,"token":row.token,"wire":null,"ready":false,"last":Time.get_ticks_msec(),"sequence":-1,"snapshot":{}}
		stats.max_workers=workers.size();print("CQ_EXTERNAL_LISTEN port=",port," workers=",workers.size());return
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
		if not worker.get("external",false) and OS.is_process_running(worker.pid):OS.kill(worker.pid)
	workers.clear();connections.clear();connection_started.clear()
func _exit_tree() -> void:stop()
func need(zone: int) -> bool:
	if workers.has(zone):return true
	if not external_session.is_empty():fail("District %d has no provisioned external worker"%zone);return false
	# Empty workers can be replaced; no actor or pending transaction may reference them.
	if workers.size()>=limit:
		for other in workers.keys():
			var w: Dictionary=workers[other]
			if reset_pending.has(other) or owners.values().any(func(o):return o.zone==other or o.get("source",-1)==other):continue
			if not w.get("snapshot",{}).get("projectiles",[]).is_empty():continue
			sleeping[other]={"pickups":w.snapshot.get("pickups",[]).duplicate(true),"at":w.get("snapshot_at",game.clock)}
			if w.wire:reject(w.wire)
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
	if not Capacity.available(owners,zone,id) or (game.players[id].dead and not game.players[id].spectator):
		game.players[id].dead=true;game.players[id].hp=0
		owners[id]={"zone":-1,"generation":gen,"phase":"spawn_wait","ack":id<0,"started":Time.get_ticks_msec(),"last_seq":-1,"baseline":true}
		streams.erase(id)
		if id>0:
			game._cq_transition.rpc_id(id,game.map_epoch,gen,-1)
			game._announcement.rpc_id(id,"No friendly deployment slot is available. Waiting for reinforcements.")
		return
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
func publish_capacity() -> void:
	var counts:=Capacity.counts(owners)
	if counts==capacity_counts:return
	capacity_counts=counts;capacity_revision+=1
	for zone in workers:send(zone,{"kind":"capacity","counts":counts})
	game._cq_capacity.rpc(game.map_epoch,counts,capacity_revision)
func respawn(id: int) -> void:
	var o: Dictionary=owners[id]
	if o.phase!="active" or not o.get("respawn_pending",false) or o.has("respawn_zone"):return
	var target:=Capacity.nearest(owners,game.match_mode.conquest.rules.owners,int(game.players[id].team),game.fighters[id].position,id)
	if target<0:
		# Retire is ordered before any later admission on this worker's TCP stream.
		# The master keeps the dead player's state; waiting rooms consume no district slot.
		send(o.zone,{"kind":"retire","id":id})
		o.zone=-1;o.phase="spawn_wait";o.generation+=1;o.ack=id<0;o.started=Time.get_ticks_msec();o.erase("respawn_pending")
		streams.erase(id)
		if id>0:game._cq_transition.rpc_id(id,game.map_epoch,o.generation,-1)
		return
	o.respawn_zone=target
	send(o.zone,{"kind":"respawn_grant","id":id,"generation":o.generation,"target":target})
func progress(id: int) -> void:
	if not owners.has(id) or not reset_pending.is_empty():return
	var o: Dictionary=owners[id]
	if o.phase=="spawn_wait":
		var target:=Capacity.nearest(owners,game.match_mode.conquest.rules.owners,int(game.players[id].team),game.fighters[id].position,id)
		if target<0:return
		game.players[id].cq_spawn_zone=target;game._spawn(id);game.players[id].erase("cq_spawn_zone")
		if game.players[id].dead:return
		o.zone=target;o.phase="waiting";o.actor=State.actor(game,id);o.baseline=true;o.generation+=1;o.ack=id<0;o.started=Time.get_ticks_msec()
		if id>0:game._cq_transition.rpc_id(id,game.map_epoch,o.generation,target)
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
		var accepted=Wire.new(peer);connections.append(accepted);connection_started[accepted]=Time.get_ticks_msec()
	for wire in connections.duplicate():
		for message in wire.poll():
			handle(wire,message)
			if closing or not connections.has(wire):break
		if closing:return
		if wire.failed:
			if workers.values().any(func(w):return w.wire==wire):fail("Worker transport exceeded bounds");return
			reject(wire);continue
		if not workers.values().any(func(w):return w.wire==wire) and (wire.peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec()-int(connection_started.get(wire,0))>5000):reject(wire)
	var now:=Time.get_ticks_msec()
	for zone in workers:
		var w: Dictionary=workers[zone]
		if (not w.get("external",false) and not OS.is_process_running(w.pid)) or now-w.last>(5000 if w.ready else 60000):fail("District %d unavailable"%zone);return
		if w.ready and w.wire.peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:fail("District %d disconnected"%zone);return
	for id in owners.keys():
		respawn(id)
		progress(id)
		if owners[id].phase not in ["active","spawn_wait"] and now-owners[id].started>60000:fail("Actor handoff timed out");return
	publish_capacity()
	if now-heartbeat_at>=250:
		heartbeat_at=now
		for zone in workers:send(zone,{"kind":"heartbeat","rules":game.match_mode.conquest.rules.snapshot(),"capacity":capacity_counts,"running":game.intermission<=0 and reset_pending.is_empty()})
func reject(wire) -> void:
	wire.peer.disconnect_from_host();connections.erase(wire);connection_started.erase(wire)
func handle(wire,message: Dictionary) -> void:
	if not message.get("kind") is String:reject(wire);return
	var candidate=message.get("zone")
	if not candidate is int or candidate not in range(16):reject(wire);return
	var zone: int=candidate
	if not workers.has(zone):reject(wire);return
	var w: Dictionary=workers[zone]
	if message.get("kind","")=="hello":
		if w.ready:reject(wire);return
		if not message.get("pid") is int or not message.get("schema") is int or not message.get("token") is String or not message.get("map") is String:reject(wire);return
		if w.get("external",false) and not ["session","instance","link","version"].all(func(key):return message.get(key) is String):reject(wire);return
		var identity: bool=message.get("pid")==w.pid
		if w.get("external",false):identity=message.get("pid") is int and message.pid>0 and message.get("session")==external_session and message.get("instance")==w.instance and message.get("link")==External.PROTOCOL and message.get("version")==ProjectSettings.get_setting("application/config/version")
		if not identity or message.get("token")!=w.token or message.get("map")!=game.map_sha or message.get("schema")!=State.SCHEMA:reject(wire);return
		if w.get("external",false):w.pid=int(message.get("pid",0)) # Diagnostic only, never a local process handle.
		w.wire=wire;w.ready=true;w.last=Time.get_ticks_msec();wire.send({"kind":"welcome","token":w.token,"session":external_session,"instance":w.get("instance","")});w.erase("token")
		var parked: Dictionary=sleeping.get(zone,{})
		var items: Array=parked.get("pickups",[]).duplicate(true)
		for item in items:
			item.respawn=maxf(0,item.respawn-(game.clock-float(parked.get("at",game.clock))))
			if item.respawn<=0:item.available=true
		send(zone,{"kind":"start","pickups":items,"capacity":Capacity.counts(owners)});sleeping.erase(zone);print("CQ_WORKER_READY zone=",zone);return
	if not w.ready or w.wire!=wire or message.get("epoch",-1)!=epoch:return
	w.last=Time.get_ticks_msec()
	match message.kind:
		"respawn_request":
			var id: int=message.id
			if not owners.has(id) or owners[id].zone!=zone or owners[id].phase!="active" or message.generation!=owners[id].generation:return
			if not State.valid(message.actor) or not message.actor.state.dead:fail("Invalid respawn request");return
			apply(message.actor);owners[id].respawn_pending=true;respawn(id)
		"respawn_done","respawn_failed":
			var id: int=message.id
			if not owners.has(id) or owners[id].zone!=zone or not owners[id].has("respawn_zone"):return
			if message.kind=="respawn_done":
				if owners[id].respawn_zone!=zone or not State.valid(message.actor):fail("Invalid local respawn completion");return
				apply(message.actor)
			owners[id].erase("respawn_zone");owners[id].erase("respawn_pending")
		"rolled_back":
			for id in owners:
				var o: Dictionary=owners[id]
				if o.phase=="rolling_back" and o.zone==zone and o.get("tx","")==message.tx:
					apply(message.actor);o.phase="active";o.erase("tx");break
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
			var is_respawn: bool=message.get("respawn",false)
			var permitted: bool=Capacity.available(owners,int(message.target),id)
			if is_respawn:permitted=permitted and o.get("respawn_zone",-1)==message.target and game.match_mode.conquest.rules.owners[message.target]==game.players[id].team
			if not permitted:
				o.phase="rolling_back";o.tx=message.tx;o.started=Time.get_ticks_msec();o.erase("respawn_zone");o.erase("respawn_pending")
				send(zone,{"kind":"rollback","tx":message.tx});return
			o.source=zone;o.zone=message.target;o.actor=message.actor;o.tx=message.tx;o.generation+=1;o.phase="preparing";o.ack=id<0;o.started=Time.get_ticks_msec();o.baseline=true
			o.erase("respawn_zone");o.erase("respawn_pending")
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
	# Initial placement has already reset all actors. Retire old reservations first.
	var generations: Dictionary={}
	for id in owners:generations[id]=owners[id].generation
	owners.clear()
	for id in generations:owners[id]={"generation":generations[id]}
	for id in game.players:admit(id)
	resetting=false
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
	result[10].cq_capacity={"counts":capacity_counts,"revision":capacity_revision}
	for key in ["locomotion","movement_ack","weapon_charge"]:
		for other in result[10].get(key,{}).keys():
			if other not in visible:result[10][key].erase(other)
	for index in game.pickups.size():
		if State.district(game.pickups[index].position)!=zone:result[1][index]=0
	return result
func replicate(state: Array) -> void:
	publish_capacity()
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
	return {"backend":"districts","district_capacity":Capacity.LIMIT,"occupancy":Capacity.counts(owners),"respawn_waiting":owners.values().filter(func(o):return o.get("respawn_pending",false) or o.phase=="spawn_wait").size(),"placement":"external" if not external_session.is_empty() else "local","transport":workers.keys().reduce(func(result,z):
		var w: Dictionary=workers[z];result[z]={"ready":w.ready,"sent":w.wire.sent if w.wire else 0,"received":w.wire.received if w.wire else 0,"snapshot_age_ms":Time.get_ticks_msec()-w.last};return result,{}),"workers":workers.size(),"limit":limit,"worker_pids":workers.keys().reduce(func(result,z):result[z]=workers[z].pid;return result,{}),"stats":stats.duplicate(),"actors":actors,"epoch":epoch}

func apply(row: Dictionary) -> void:
	# Admission, model choice and transport RTT remain owned by the gateway.
	row.state.ping=game.players[row.id].ping
	row.avatar=game.avatars.choices.get(row.id,{})
	State.apply(game,row)
