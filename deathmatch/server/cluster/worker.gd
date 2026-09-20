extends Node
## Opt-in persistent cluster adapter. Uses existing BSP physics and combat;
## topology, reservations and ownership belong to the external coordinator.
const State=preload("res://deathmatch/server/districts/state.gd")
const Rules=preload("res://deathmatch/conquest/rules.gd")
var game
var zone:=0 # Local asset template, independent of the cluster district identity.
var respawn_destination: Dictionary={}
var config: Dictionary
var socket:=StreamPeerTCP.new()
var incoming:=PackedByteArray()
var outgoing:=PackedByteArray()
var grants: Dictionary={}
var generations: Dictionary={}
var escrow: Dictionary={}
var staged: Dictionary={}
var retired: Dictionary={}
var events: Array=[]
var metadata: Dictionary={}
var instance:=""
var until:=0
var revision:=-1
var sequence:=0
var last_snapshot:=0
var connected:=false
var next_connect:=0
var booted:=false
var journal:=""
var campaign: Dictionary={}
var last_capture:=0
var capture_sequence:=0
func no_fire() -> bool:return metadata.get("campaign_role","")=="hub"
func setup(arena,args: PackedStringArray) -> void:
	game=arena;game.district_worker=self;game.set_process(false);game.set_physics_process(false)
	var value=JSON.parse_string(FileAccess.get_file_as_string(game._arg_value(args,"--cluster-worker","")))
	if not value is Dictionary or not value.has_all(["district","map_slot","address","token","state_dir"]):get_tree().quit(2);return
	config=value;zone=int(config.map_slot)
	if zone!=game._arg_int(args,"--cq-worker",-1) or zone not in range(16) or config.address[0]!="127.0.0.1" or not game.cq_maps.enabled:get_tree().quit(2);return
	instance=Crypto.new().generate_random_bytes(16).hex_encode()
	DirAccess.make_dir_recursive_absolute(config.state_dir);journal=config.state_dir+"/transfers.dat"
	if FileAccess.file_exists(journal):
		var stored=FileAccess.open(journal,FileAccess.READ).get_var(false)
		if stored is Dictionary:escrow=stored.get("escrow",{});staged=stored.get("staged",{});retired=stored.get("retired",{})
	boot.call_deferred()
func boot() -> void:
	Engine.max_fps=60;Engine.physics_ticks_per_second=60
	game.armory.select("ut99");game.selected_map=game.match_mode.conquest.MAP_ID
	game.dedicated=true;game.max_clients=16;game.start_host("Persistent district",0,100,60,true)
	if not game.active:get_tree().quit(2);return
	for id in game.players.keys():State.remove(game,id)
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	game.dedicated=false;game.pickups=game.pickups.filter(func(p):return State.district(p.position)==zone)
	game.projectile_id=zone*100000000;booted=true
	print("CLUSTER_WORKER_READY district=",config.district," asset=",zone)
func persist() -> bool:
	var file:=FileAccess.open(journal+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_var({"escrow":escrow,"staged":staged,"retired":retired},false);file.flush();file.close()
	return DirAccess.rename_absolute(journal+".tmp",journal)==OK
func event(method: String,args: Array) -> void:
	if events.size()<256:events.append([method,args])
func request_respawn(_id: int) -> bool:return true # Explicit worker-validated cluster respawn.
func send(message: Dictionary) -> void:
	var bytes:=(JSON.stringify(message)+"\n").to_utf8_buffer()
	if bytes.size()>1048576 or outgoing.size()+bytes.size()>2097152:socket.disconnect_from_host();return
	outgoing.append_array(bytes)
func reply(message: Dictionary,result: Dictionary) -> void:
	if message.has("request"):send({"request":message.request,"result":result})
func reject(message: Dictionary,reason: String) -> void:
	if message.has("request"):send({"request":message.request,"error":reason})
func clear_actor(id: int) -> void:
	for shot in game.projectiles.keys():
		if game.projectiles[shot].owner==id:game._projectile_end.rpc(shot,game.projectiles[shot].position,game.projectiles[shot].weapon)
	if game.players.has(id):State.remove(game,id)
func reconcile() -> void:
	var keep: Dictionary={}
	for key in grants:
		var a: Dictionary=grants[key];var id:=int(a.id)
		if a.get("district")!=config.district or a.phase!="active":continue
		keep[id]=true
		if int(retired.get(id,-1))>=int(a.generation):continue
		if game.players.has(id) and generations.get(id,-1)!=int(a.generation):clear_actor(id)
		if not game.players.has(id):
			var row: Dictionary={}
			for tx in escrow.keys():
				if int(escrow[tx].id)==id and int(escrow[tx].generation)==int(a.generation):row=bytes_to_var(Marshalls.base64_to_raw(escrow[tx].payload));escrow.erase(tx);break
			if row.is_empty() and a.get("arrival")!=null:
				if not staged.has(a.arrival):continue # Never invent a lost migration baseline.
				var stage: Dictionary=staged[a.arrival]
				row=bytes_to_var(Marshalls.base64_to_raw(stage.payload))
				if not row is Dictionary or not State.valid(row):continue
				var offset: Vector3=row.position-row.get("cluster_origin",Vector3.ZERO)-Vector3(stage.exit[0],stage.exit[1],stage.exit[2])
				row.position=Rules.center(zone)+Vector3(stage.entry[0],stage.entry[1],stage.entry[2])+offset.rotated(Vector3.UP,float(stage.yaw));row.state.yaw+=float(stage.yaw)
				row.body.jetpack_state.heading=row.body.jetpack_state.heading.rotated(-float(stage.yaw))
				row.body.blast_velocity=row.body.blast_velocity.rotated(-float(stage.yaw))
				row.velocity=row.velocity.rotated(Vector3.UP,float(stage.yaw))
			if row.is_empty():
				if game.players.size()>=16:continue
				game.players[id]=game._new_state(a.name,id);game._create_fighter(id);game._spawn(id)
				if config.has("spawn"):game.fighters[id].position=Rules.center(zone)+Vector3(config.spawn[0],config.spawn[1],config.spawn[2])
			else:
				if game.players.size()>=16:continue
				State.restore(game,row)
		generations[id]=int(a.generation);game.players[id].cq_wait_input=false
		if a.has("team"):game.players[id].team=int(a.team)
		if no_fire():game.players[id].fire=false;game.players[id].offhand_fire=false;game.players[id].melee=false
	for id in game.players.keys():
		if not keep.has(id):
			# Keep a moving source frozen in memory until the explicit escrow RPC.
			var moving:=false
			for a in grants.values():
				if int(a.id)==id and a.phase=="moving" and a.district==config.district:moving=true
			if moving:game.players[id].cq_wait_input=true
			else:clear_actor(id)
func prune_journal() -> void:
	var keep: Dictionary={};var ids: Dictionary={}
	for a in grants.values():
		ids[int(a.id)]=true
		if a.get("arrival")!=null:keep[a.arrival]=true
		if a.get("tx")!=null:keep[a.tx]=true
	var changed:=false
	for tx in staged.keys():
		if not keep.has(tx):staged.erase(tx);changed=true
	for id in retired.keys():
		if not ids.has(id):retired.erase(id);generations.erase(id);changed=true
	if changed and not persist():until=0
func command(m: Dictionary) -> void:
	if m.get("op")=="welcome":return
	if m.get("op")=="authority":
		if int(m.revision)<revision:return
		revision=int(m.revision);until=Time.get_ticks_msec()+int(clampf(minf(float(m.valid_for),float(m.get("expires_at",0))-Time.get_unix_time_from_system()),0,2)*1000)
		grants=m.actors;metadata=m.metadata;campaign=m.campaign if m.get("campaign") is Dictionary else {};reconcile();prune_journal();return
	if Time.get_ticks_msec()>=until:reject(m,"Worker authority expired");return
	var op: String=m.get("op","")
	var id:=int(m.get("id",-1))
	if op=="stage":
		if str(m.payload).length()>512000 or str(m.payload).sha256_text()!=m.digest:reject(m,"Migration checksum mismatch");return
		var row=bytes_to_var(Marshalls.base64_to_raw(m.payload))
		if not row is Dictionary or not State.valid(row) or row.id!=id:reject(m,"Invalid actor payload");return
		if staged.has(m.tx) and staged[m.tx].digest!=m.digest:reject(m,"Conflicting prepared state");return
		if staged.size()>=128 and not staged.has(m.tx):reject(m,"Transfer journal full");return
		staged[m.tx]={"id":id,"payload":m.payload,"digest":m.digest,"entry":m.entry,"exit":m.exit,"yaw":m.yaw,"generation":m.generation}
		if not persist():reject(m,"Cannot persist prepared state");return
		reply(m,{"prepared":true});return
	if op=="freeze":
		if escrow.has(m.tx):reply(m,{"payload":escrow[m.tx].payload});return
		if not game.players.has(id) or generations.get(id,-1)!=int(m.generation):reject(m,"Actor generation not resident");return
		var exit_point:=Rules.center(zone)+Vector3(m.exit[0],m.exit[1],m.exit[2])
		if game.fighters[id].position.distance_to(exit_point)>(3 if m.get("terminal",false) else 8):reject(m,"Actor is not at the gate");return
		var transfer:=State.actor(game,id);transfer.cluster_origin=Rules.center(zone)
		var payload:=Marshalls.raw_to_base64(var_to_bytes(transfer))
		escrow[m.tx]={"id":id,"payload":payload,"generation":m.generation}
		if not persist():escrow.erase(m.tx);reject(m,"Cannot persist source escrow");return
		clear_actor(id);reply(m,{"payload":payload});return
	if op in ["release","retire"]:
		if int(generations.get(id,0))>int(m.get("generation",-1)):reject(m,"Stale retirement generation");return
		retired[id]=int(m.get("generation",0));clear_actor(id)
		if m.has("tx"):escrow.erase(m.tx)
		if not persist():reject(m,"Cannot persist retirement");return
		reply(m,{"released":true});return
	if not game.players.has(id) or generations.get(id,-1)!=int(m.get("generation",-2)):reject(m,"Actor generation not active");return
	if op=="check_dead":
		if not game.players[id].dead:reject(m,"Living actor cannot respawn");return
		reply(m,{"dead":true});return
	if op=="respawn":
		if not game.players[id].dead:reject(m,"Living actor cannot respawn");return
		game.players[id].dead=false;game._spawn(id);reply(m,{"respawned":true});return
	if op=="input":
		if game.players[id].get("cq_wait_input",false):reject(m,"Actor is transferring");return
		var c: Dictionary=m.command.duplicate(true);c.seq=int(c.seq);c.weapon=int(c.get("weapon",2));var move: Array=c.get("move",[0,0]);c.move=Vector2(move[0],move[1]);c.yaw=float(c.get("yaw",0));c.pitch=float(c.get("pitch",0));c.view_time=-1.0;c.fire=c.get("fire",false);c.slow=false;c.respawn=false;c.input_life=game.players[id].serial
		if no_fire():c.fire=false
		var old: int=game.players[id].last_seq;game._accept_input(id,c)
		reply(m,{"accepted":game.players[id].last_seq>old});return
	reject(m,"Unknown worker operation")
func _physics_process(delta: float) -> void:
	if not booted:return
	var now:=Time.get_ticks_msec()
	socket.poll()
	if socket.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
		if connected:connected=false;until=0;incoming.clear();outgoing.clear()
		if now>=next_connect:socket.disconnect_from_host();socket.connect_to_host(config.address[0],int(config.address[1]));next_connect=now+2000
		return
	if not connected:
		connected=true;send({"op":"worker","district":config.district,"instance":instance,"token":config.token})
	if not outgoing.is_empty():
		var result:=socket.put_partial_data(outgoing)
		if result[0]!=OK:socket.disconnect_from_host();return
		outgoing=outgoing.slice(result[1])
	if socket.get_available_bytes()>0:
		var result:=socket.get_partial_data(mini(socket.get_available_bytes(),1048576-incoming.size()))
		if result[0]!=OK:socket.disconnect_from_host();return
		incoming.append_array(result[1])
	var handled:=0
	while handled<128:
		var end:=incoming.find(10)
		if end<0:break
		var message=JSON.parse_string(incoming.slice(0,end).get_string_from_utf8());incoming=incoming.slice(end+1);handled+=1
		if not message is Dictionary:socket.disconnect_from_host();return
		command(message)
	if incoming.size()>=1048576:socket.disconnect_from_host();return
	if now<until:
		game.round_left=1000000;game.intermission=0
		game._physics_process(delta)
		# No simulation escapes its local BSP; topology uses explicit portal handoff.
		for id in game.players:
			var p: Vector3=game.fighters[id].position-Rules.center(zone)
			p.x=clampf(p.x,-124,124);p.z=clampf(p.z,-124,124);game.fighters[id].position=Rules.center(zone)+p
	if now-last_snapshot>=50:
		last_snapshot=now;sequence+=1
		var snapshot:=State.snapshot(game,zone,sequence)
		snapshot.events=events;events=[]
		send({"op":"snapshot","sequence":sequence,"payload":Marshalls.raw_to_base64(var_to_bytes(snapshot))})
	if now<until and now-last_capture>=200 and int(metadata.get("threshold",0))>0:
		last_capture=now;capture_sequence+=1
		var occupants: Dictionary={};var center: Array=metadata.capture
		for key in grants:
			var actor: Dictionary=grants[key];var id:=int(actor.id)
			if actor.get("district")!=config.district or actor.phase!="active" or not game.players.has(id) or game.players[id].dead:continue
			var p: Vector3=game.fighters[id].position-Rules.center(zone)-Vector3(center[0],center[1],center[2])
			if absf(p.y)<2.5 and Vector2(p.x,p.z).length()<=float(metadata.capture_radius):occupants[key]=int(actor.generation)
		send({"op":"capture","capture":{"epoch":campaign.get("epoch",0),"sequence":capture_sequence,"actors":occupants}})
