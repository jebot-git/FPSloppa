extends Node
## Launched by the dedicated server, using the same executable and arena code.
const External=preload("res://deathmatch/server/districts/external.gd")
const State=preload("res://deathmatch/server/districts/state.gd")
const Wire=preload("res://deathmatch/server/districts/wire.gd")
const Rules=preload("res://deathmatch/conquest/rules.gd")
var game
var zone:=0
var wire
var token:=""
var external: Dictionary={}
var generation: Dictionary={}
var prepared: Dictionary={}
var escrow: Dictionary={}
var running:=false
var epoch:=0
var sequence:=0
var last_snapshot:=0
var last_contact:=0
var booted:=false
var authenticated:=false
var events: Array=[]
func setup(arena,args: PackedStringArray) -> void:
	game=arena;game.district_worker=self;game.dedicated=true;game.set_process(false);game.set_physics_process(false)
	zone=game._arg_int(args,"--cq-worker",-1);token=game._arg_value(args,"--worker-token","")
	var provision: String=game._arg_value(args,"--worker-session-file","")
	if not provision.is_empty():
		external=External.worker(provision,zone)
		if external.has("error"):push_error(external.error);get_tree().quit(2);return
		token=external.token
	if zone not in range(16) or token.length()!=64 or not token.is_valid_hex_number(false):get_tree().quit(2);return
	boot.call_deferred(int(external.port) if not external.is_empty() else game._arg_int(args,"--worker-port",0))
func boot(port: int) -> void:
	if port<1024 or port>65535:get_tree().quit(2);return
	Engine.max_fps=60;Engine.physics_ticks_per_second=60
	game.armory.select("ut99");game.selected_map=game.match_mode.conquest.MAP_ID;game.max_clients=64;game.start_host("District",0,100,60,true)
	if not game.active:get_tree().quit(2);return
	for id in game.players.keys():State.remove(game,id)
	game.dedicated=false
	game.pickups=game.pickups.filter(func(p):return State.district(p.position)==zone)
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	var deadline: int
	# Every projectile id belongs to exactly one district namespace for this process.
	game.projectile_id=zone*100000000
	var socket:=StreamPeerTCP.new();socket.connect_to_host("127.0.0.1",port);wire=Wire.new(socket)
	deadline=Time.get_ticks_msec()+10000
	while socket.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
		socket.poll();await get_tree().process_frame
		if Time.get_ticks_msec()>deadline:get_tree().quit(2);return
	wire.send({"kind":"hello","zone":zone,"token":token,"pid":OS.get_process_id(),"map":game.map_sha,"schema":State.SCHEMA,"session":external.get("session",""),"instance":external.get("instance",""),"link":External.PROTOCOL,"version":ProjectSettings.get_setting("application/config/version")})
	last_contact=Time.get_ticks_msec();booted=true
func ensure_bots(id: int) -> void:
	if id>=0 or is_instance_valid(game.bots):return
	game.bots=preload("res://deathmatch/bots.gd").new();game.add_child(game.bots);game.bots.setup(game)
func event(method: String,args: Array) -> void:
	if running:
		if events.size()>=512:get_tree().quit(3);return
		events.append([method,args])
func _physics_process(delta: float) -> void:
	if not booted:return
	for message in wire.poll():
		last_contact=Time.get_ticks_msec();command(message)
	if wire.failed or wire.peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec()-last_contact>15000:
		get_tree().quit(3);return
	if not running:return
	game.round_left=1000000;game.intermission=0
	# Empty districts retain timers, but have no AI or actors to simulate.
	if game.players.is_empty() and game.projectiles.is_empty():game.clock+=delta
	else:game._physics_process(delta)
	for id in game.players.keys():
		var target:=State.district(game.fighters[id].position)
		if target!=zone:offer(id,target)
	for id in game.projectiles.keys():
		if State.district(game.projectiles[id].position)!=zone:game._projectile_end.rpc(id,game.projectiles[id].position,game.projectiles[id].weapon)
	if Time.get_ticks_msec()-last_snapshot>=50:send_snapshot();last_snapshot=Time.get_ticks_msec()
func command(message: Dictionary) -> void:
	if not authenticated:
		if message.get("kind","")!="welcome" or message.get("token","")!=token or (not external.is_empty() and (message.get("session")!=external.session or message.get("instance")!=external.instance)):get_tree().quit(3);return
		authenticated=true;token="";return
	if message.kind=="start" and epoch==0:
		game.match_mode.friendly_fire=message.get("friendly_fire",false);running=true;epoch=message.epoch;game.map_epoch=message.get("map_epoch",epoch)
		for stored in message.get("pickups",[]):
			for item in game.pickups:
				if item.position==stored.position:item.available=stored.available;item.respawn=game.clock+float(stored.respawn);break
		send_snapshot();return
	if int(message.get("epoch",-1))!=epoch:return
	game.match_mode.friendly_fire=message.get("friendly_fire",game.match_mode.friendly_fire)
	match message.kind:
		"heartbeat":
			game.match_mode.conquest.rules.receive(message.rules)
			running=message.running
			if not running:send_snapshot()
		"admit":
			var row: Dictionary=message.actor
			if not State.valid(row) or State.district(row.position)!=zone:return
			if game.players.has(row.id):return
			ensure_bots(row.id);State.restore(game,row);game.players[row.id].cq_wait_input=row.id>0;generation[row.id]=int(message.generation);send_snapshot()
		"retire":
			var id: int=message.id
			if game.players.has(id):clear_projectiles(id);State.remove(game,id)
			for tx in prepared.keys():
				if prepared[tx].actor.id==id:prepared.erase(tx)
			for tx in escrow.keys():
				if escrow[tx].id==id:escrow.erase(tx)
			generation.erase(id)
		"remove":
			var id: int=message.id
			if game.players.has(id):clear_projectiles(id);State.remove(game,id)
			generation.erase(id)
		"input":
			var id: int=message.id
			if not game.players.has(id) or int(message.generation)!=int(generation.get(id,-1)):return
			game.players[id].ping=clampi(int(message.get("ping",0)),0,400)
			var input: Dictionary=message.command.duplicate(true)
			if float(input.get("view_time",-1))>=0:input.view_time+=game.clock-float(message.gateway_clock)
			game._accept_input(id,input)
			if game.players[id].last_seq==input.get("seq",-2):game.players[id].cq_wait_input=false
		"action":
			if game.players.has(message.id) and int(message.generation)==int(generation.get(message.id,-1)):
				if message.action=="suicide":game._suicide_for(message.id)
				elif message.action=="use":game._use_for(message.id)
		"prepare":
			var tx: String=message.tx
			if prepared.has(tx):
				wire.send({"kind":"prepared" if prepared[tx].actor==message.actor and prepared[tx].generation==message.generation else "rejected","zone":zone,"tx":tx,"epoch":epoch});return
			if prepared.size()>=256:get_tree().quit(3);return
			if not State.valid(message.actor) or State.district(message.actor.position)!=zone or game.players.has(message.actor.id):wire.send({"kind":"rejected","zone":zone,"tx":tx,"epoch":epoch});return
			prepared[tx]={"actor":message.actor,"generation":message.generation,"committed":false}
			wire.send({"kind":"prepared","zone":zone,"tx":tx,"epoch":epoch})
		"commit":
			if not prepared.has(message.tx):return
			var tx: Dictionary=prepared[message.tx];var id: int=tx.actor.id
			if not tx.committed:
				ensure_bots(id);State.restore(game,tx.actor);game.players[id].cq_wait_input=id>0;generation[id]=int(tx.generation);tx.committed=true
				# Destination history must never rewind into a previous visit.
				for frame in game.history:frame.positions.erase(id)
				game.players[id].view_time=-1.0
				tx.receipt=State.actor(game,id)
			wire.send({"kind":"committed","zone":zone,"tx":message.tx,"actor":tx.receipt,"epoch":epoch})
		"release":
			if escrow.has(message.tx):
				var id: int=escrow[message.tx].id
				if not game.players.has(id):generation.erase(id)
				escrow.erase(message.tx)
		"forget":prepared.erase(message.tx)
		"cancel":
			if prepared.has(message.tx) and not prepared[message.tx].committed:prepared.erase(message.tx)
		"rollback":
			if not escrow.has(message.tx):return
			var row: Dictionary=escrow[message.tx]
			var center:=Rules.center(zone);row.position.x=clampf(row.position.x,center.x-124.5,center.x+124.5);row.position.z=clampf(row.position.z,center.z-124.5,center.z+124.5);row.velocity=Vector3.ZERO
			State.restore(game,row);game.players[row.id].view_time=-1.0;escrow.erase(message.tx)
			wire.send({"kind":"rolled_back","zone":zone,"tx":message.tx,"actor":State.actor(game,row.id),"epoch":epoch})
		"reset":
			if int(message.next_epoch)<=epoch:return
			running=false
			for id in game.players.keys():clear_projectiles(id);State.remove(game,id)
			generation.clear();prepared.clear();escrow.clear();events.clear();game.history.clear()
			for item in game.pickups:item.available=true;item.respawn=0.0
			epoch=int(message.next_epoch);game.map_epoch=message.get("map_epoch",epoch)
			wire.send({"kind":"reset","zone":zone,"epoch":epoch})
		"stop":wire.peer.disconnect_from_host();get_tree().quit()
func clear_projectiles(owner: int) -> void:
	for id in game.projectiles.keys():
		if game.projectiles[id].owner==owner:game._projectile_end.rpc(id,game.projectiles[id].position,game.projectiles[id].weapon)
func offer(id: int,target: int) -> void:
	if escrow.size()>=256:get_tree().quit(3);return
	var tx:="%d:%d:%d:%d"%[epoch,zone,id,sequence];var row:=State.actor(game,id)
	row.state.move=Vector2.ZERO;row.state.fire=false;row.state.alt_fire=false;row.state.offhand_fire=false;row.state.jump=false;row.state.room=Vector3.ZERO
	clear_projectiles(id);escrow[tx]=row;State.remove(game,id)
	wire.send({"kind":"offer","zone":zone,"target":target,"tx":tx,"actor":row,"generation":generation[id],"epoch":epoch})
func send_snapshot() -> void:
	if game.projectile_id>=(zone+1)*100000000:get_tree().quit(3);return
	sequence+=1
	var snapshot:=State.snapshot(game,zone,sequence)
	snapshot.watermark=game.projectile_id
	snapshot.friendly_fire=game.match_mode.friendly_fire
	wire.send({"kind":"snapshot","zone":zone,"epoch":epoch,"snapshot":snapshot,"generations":generation.duplicate(),"events":events});events=[]
