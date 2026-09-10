extends Node
## Server-authorized join barrier plus byte-based download telemetry.
const Library=preload("res://deathmatch/avatars/library.gd")
var game
var blocking:=false
var phase:=""
var items: Dictionary={}
var started:=0
var changed_at:=0
var required: Dictionary={}
var prepared: Dictionary={}
var ticket:=-1
var sent_ready:=false
var heartbeat:=0.0
var pending: Dictionary={}
var serial:=0
func setup(arena: Node) -> void: game=arena
func reset() -> void:
	blocking=false;phase="";items.clear();required.clear();prepared.clear();pending.clear()
	started=0;changed_at=0;ticket=-1;sent_ready=false;heartbeat=0
func begin() -> void:
	reset();blocking=true;phase="Connecting to server…"
func begin_item(key: String,size: int,title: String) -> void:
	if not blocking and not downloading():items.clear();started=0
	if not items.has(key):items[key]={"size":size,"done":0,"title":title.left(60),"verified":false}
	changed_at=Time.get_ticks_msec()
func advance(key: String,count: int) -> void:
	if not items.has(key):return
	if started==0:started=Time.get_ticks_msec()
	items[key].done=clampi(count,0,items[key].size);changed_at=Time.get_ticks_msec()
	if blocking:game.connect_deadline=game.clock+120
func complete(key: String) -> void:
	if items.has(key):items[key].done=items[key].size;items[key].verified=true;changed_at=Time.get_ticks_msec()
func fail(key: String,reason: String) -> void:
	items.erase(key)
	if blocking:game.disconnect_game(reason)
func downloading() -> bool:
	for row in items.values():
		if not row.verified:return true
	return false
func snapshot() -> Dictionary:
	var total:=0;var done:=0;var count:=0
	for row in items.values():
		total+=row.size;done+=row.done
		if not row.verified:count+=1
	var elapsed:float=(Time.get_ticks_msec()-started)/1000.0 if started>0 else 0.0
	var rate:float=done/elapsed if elapsed>.25 else 0.0
	var eta:="Estimating time…"
	if count==0:eta="Verifying / preparing…" if blocking else "Download complete"
	elif rate>0:
		var seconds:=ceili(maxi(0,total-done)/rate)
		eta="About %d:%02d remaining"%[seconds/60,seconds%60]
	return {"visible":blocking or count>0 or (changed_at>0 and Time.get_ticks_msec()-changed_at<3000),"blocking":blocking,"phase":phase,"total":total,"done":done,"count":count,"fraction":float(done)/total if total>0 else 0.0,"eta":eta}
func manifest(peer: int) -> Dictionary:
	var data:Dictionary=game.avatars.choices.duplicate(true)
	var defaults:Array=game.avatars.library.entries.keys()
	if not defaults.is_empty():
		var hash:String=defaults[posmod(peer,mini(3,defaults.size()))]
		data[peer]={"hash":hash,"size":game.avatars.library.entries[hash].size}
	return data
func offer(peer: int) -> void:
	serial+=1
	var data:=manifest(peer)
	pending[peer]={"ticket":serial,"epoch":game.map_epoch,"data":data}
	game.pending_joins[peer]=game.clock+240
	_manifest.rpc_id(peer,game.map_epoch,serial,data)
@rpc("authority","call_remote","reliable",4)
func _manifest(epoch: int,value: int,data: Dictionary) -> void:
	if epoch!=game.map_epoch or not blocking or value<ticket or data.size()>game.SERVER_MAX_PLAYERS:return
	var needed:Dictionary={}
	for id in data:
		var row=data[id]
		if not id is int or not row is Dictionary or not row.get("hash") is String or not row.get("size") is int:
			game.disconnect_game("Invalid model manifest.");return
		if not Library.valid_hash(row.hash) or row.size<=0 or row.size>Library.MAX_BYTES:
			game.disconnect_game("Invalid model manifest.");return
		needed[row.hash]=row.size
	game.connect_deadline=game.clock+240
	ticket=value;sent_ready=false;required=needed;phase="Downloading player models…"
	# Revalidate cached bytes before declaring a model ready for this connection.
	for hash in required:
		if game.avatars.library.entries.has(hash):
			var entry:Dictionary=game.avatars.library.entries[hash]
			if entry.size!=required[hash] or FileAccess.get_sha256(entry.path)!=hash:
				game.avatars.library.entries.erase(hash);game.avatars.library.scenes.erase(hash);prepared.erase(hash)
	game.avatars._catalog(data)
@rpc("any_peer","call_remote","reliable",4)
func _ready_assets(epoch: int,value: int) -> void:
	if not multiplayer.is_server():return
	var peer:=multiplayer.get_remote_sender_id()
	if not pending.has(peer) or not game.pending_names.has(peer):return
	var row:Dictionary=pending[peer]
	if epoch!=game.map_epoch or epoch!=row.epoch or value!=row.ticket:return
	if manifest(peer)!=row.data:offer(peer);return
	pending.erase(peer)
	game._finish_join(peer)
@rpc("any_peer","call_remote","reliable",4)
func _keepalive(epoch: int,value: int) -> void:
	if not multiplayer.is_server():return
	var peer:=multiplayer.get_remote_sender_id()
	if pending.has(peer) and pending[peer].epoch==epoch and pending[peer].ticket==value:
		game.pending_joins[peer]=game.clock+120
func _process(delta: float) -> void:
	if not game or not blocking or ticket<0 or multiplayer.is_server():return
	heartbeat+=delta
	if heartbeat>=2:
		game.connect_deadline=game.clock+120
		heartbeat=0;_keepalive.rpc_id(1,game.map_epoch,ticket)
	if sent_ready or game.map_loading:return
	for hash in required:
		if not game.avatars.library.entries.has(hash):return
	phase="Preparing player models…"
	if not game.headless:
		for hash in required:
			if prepared.has(hash):continue
			var avatar:Node3D=game.avatars.library.create_avatar(hash)
			if not avatar:game.disconnect_game("A required player model could not load.");return
			avatar.free();prepared[hash]=true
			return # Keep the loading screen responsive between model imports.
	sent_ready=true;phase="Ready · entering match…"
	_ready_assets.rpc_id(1,game.map_epoch,ticket)
