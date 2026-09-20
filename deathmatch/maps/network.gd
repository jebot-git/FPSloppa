extends Node
## Only the current host-selected raw BSP is served. No executable scenes cross the network.
const Loader=preload("res://deathmatch/maps/loader.gd")
const Hash=preload("res://deathmatch/avatars/library.gd")
const MAX_BYTES=Loader.MAX_BYTES
const CHUNK=32_768
const WINDOW=262_144
const IO=preload("res://deathmatch/network/disk_worker.gd")
const Jobs=preload("res://deathmatch/network/asset_jobs.gd")
var disk=IO.new()
var game
var outgoing: Dictionary={}
var expected: Dictionary={}
var incoming: Dictionary={}
var cursor:=0
var message:=""
func setup(arena: Node) -> void:
	game=arena;add_child(disk)
func reset() -> void:
	outgoing.clear();expected.clear()
	if incoming.has("path"):disk.discard(incoming.path)
	incoming={};message=""
func offer(peer: int) -> void:
	var size:=0
	for row in game.map_catalog:
		if row.id==game.current_map: 
			size=int(row.get("size",0))
			break
	_offer.rpc_id(peer,game.current_map,game.map_sha,size,game.map_title,game.map_epoch,game.match_mode.kind,game.armory.kind,source_name())
func source_name() -> String:
	for row in game.map_catalog:
		if row.id==game.current_map:return row.get("source_name",row.id)
	return ""
@rpc("authority","call_remote","reliable",5)
func _offer(map_id: String,hash: String,size: int,title: String,epoch: int=0,mode: String="dm",weapon_rules: String="doom",source: String="") -> void:
	if game.cq_profile and (mode!="cq" or map_id!=game.match_mode.conquest.MAP_ID or hash!=game.match_mode.conquest.map_hash()):game.disconnect_game("CQ cannot transfer to another mode, map or lobby.");return
	if not game.cq_profile and mode=="cq":game.disconnect_game("Use the separate CQ launcher.");return
	if epoch<game.map_epoch: return
	if epoch>game.map_epoch or game.active: game._prepare_client_map(epoch)
	if not expected.is_empty() or not incoming.is_empty(): return
	if not game.match_mode.NAMES.has(mode):game.disconnect_game("Host selected an unknown game mode.");return
	# Mode must arrive before loading: an AS client must accept a voted DM/IG map.
	game.match_mode.kind=mode
	if not game.armory.select(weapon_rules):game.disconnect_game("Unknown weapon ruleset.");return
	if map_id==game.lobby.ID and hash==game.lobby.HASH.sha256_text() and size==0:
		game.lobby.build();game.map_loading=false;game._map_ready.rpc_id(1,hash);return
	for row in game.map_catalog:
		if row.sha256==hash and game._load_map(row.id):
			game.map_loading=false
			game._map_ready.rpc_id(1,hash)
			return
	if not Hash.valid_hash(hash) or size<124 or size>MAX_BYTES:
		game.disconnect_game("Host map has invalid size or identity.")
		return
	game.loading.phase="Downloading map · "+title.left(60)
	game.loading.begin_item("map:"+hash,size,title)
	expected={"hash":hash,"size":size,"title":title.left(60),"source_name":source.left(80),"time":Time.get_ticks_msec()}
	game.connect_deadline=game.clock+240
	game.status("Downloading host map · "+title.left(60))
	_request.rpc_id(1,hash)
@rpc("any_peer","call_remote","reliable",5)
func _request(hash: String) -> void:
	if not multiplayer.is_server(): return
	var peer:=multiplayer.get_remote_sender_id()
	if not game.pending_names.has(peer) or hash!=game.map_sha or outgoing.has(peer): return
	for row in game.map_catalog:
		if row.id!=game.current_map: continue
		var size: int=row.get("size",0)
		if size<124 or size>MAX_BYTES:return
		outgoing[peer]={"hash":hash,"size":size,"path":row.path,"reading":false,"sent":0,"ack":0,"time":Time.get_ticks_msec()}
		_begin.rpc_id(peer,hash,size)
		return

@rpc("authority","call_remote","reliable",5)
func _begin(hash: String,size: int) -> void:
	if size<124 or size>MAX_BYTES: return
	if expected.get("hash","")!=hash or expected.get("size",0)!=size or not incoming.is_empty(): return
	var path:=Loader.Paths.folder("maps")+hash+".%d.%d.download"%[get_instance_id(),Time.get_ticks_usec()]
	disk.track(path)
	incoming={"hash":hash,"size":size,"path":path,"offset":0,"written":0,"time":Time.get_ticks_msec()}
@rpc("authority","call_remote","reliable",5)
func _chunk(hash: String,offset: int,bytes: PackedByteArray) -> void:
	if incoming.get("hash","")!=hash: return
	if offset!=incoming.offset or bytes.is_empty() or bytes.size()>CHUNK or offset+bytes.size()>incoming.size:
		game.disconnect_game("Invalid map download chunk."); return
	var row:=incoming
	var end:=offset+bytes.size()
	# Reject floods beyond the sender's acknowledged window, even while disk is slow.
	if end-row.written>WINDOW:game.disconnect_game("Map download exceeded window.");return
	row.offset=end;row.time=Time.get_ticks_msec()
	if not disk.submit(IO.write.bind(row.path,offset,bytes),func(error):
		if not is_same(incoming,row):return
		if error!=OK:game.disconnect_game("Cannot write downloaded map.");return
		row.written=end;row.time=Time.get_ticks_msec()
		game.loading.advance("map:"+hash,end);game.connect_deadline=game.clock+120
		message="Downloading map · %d%%"%int(100.0*end/row.size)
		game.status(message);_ack.rpc_id(1,hash,end)
		if end==row.size:finish()):
		game.disconnect_game("Map disk queue is full.")
func finish() -> void:
	if incoming.is_empty():return
	var row:=incoming
	var title: String=expected.title
	var source: String=expected.get("source_name","")
	game.loading.phase="Verifying and preparing map…"
	game.status("Preparing downloaded arena…")
	if not disk.submit(Jobs.map_file.bind(row.path,row.hash,title,Loader.Paths.folder("maps"),source),func(result):
		if not is_same(incoming,row):return
		disk.discard(row.path)
		incoming={};expected.clear()
		if result.has("error"):game.disconnect_game("Map import failed: "+result.error);return
		game.map_catalog.append(result)
		# Scene instantiation/physics registration must stay on the main thread.
		if not game._load_map(result.id):game.disconnect_game("Downloaded map could not load.");return
		game.map_title=title;game.selected_map=result.id
		if game.hud:game.hud.refresh_maps()
		game.loading.complete("map:"+row.hash)
		message="Map downloaded and verified."
		game.map_loading=false;game._map_ready.rpc_id(1,row.hash)):
		game.disconnect_game("Map disk queue is full.")
@rpc("any_peer","call_remote","reliable",5)
func _ack(hash: String,offset: int) -> void:
	if not multiplayer.is_server(): return
	var peer:=multiplayer.get_remote_sender_id()
	if not outgoing.has(peer): return
	var row: Dictionary=outgoing[peer]
	if row.hash!=hash or offset<row.ack or offset>row.sent: return
	row.ack=offset
	row.time=Time.get_ticks_msec()
	game.pending_joins[peer]=game.clock+120
	if row.ack==row.size: outgoing.erase(peer)
func _process(_delta: float) -> void:
	var peers:=outgoing.keys()
	if not peers.is_empty(): cursor=(cursor+1)%peers.size()
	for i in range(peers.size()):
		var peer: int=peers[(cursor+i)%peers.size()]
		var row: Dictionary=outgoing[peer]
		if not multiplayer.get_peers().has(peer) or Time.get_ticks_msec()-row.time>30000:
			outgoing.erase(peer); continue
		if not row.reading and row.sent<row.size and row.sent-row.ack<WINDOW:
			var count: int=game.asset_allowance(peer,mini(CHUNK,row.size-row.sent))
			if count<=0:continue
			row.reading=true;row.reading_bytes=count
			if not disk.submit(IO.read.bind(row.path,row.sent,count,row.size),func(bytes):
				if not is_same(outgoing.get(peer),row):return
				row.reading=false;row.reading_bytes=0
				if bytes.size()!=count:outgoing.erase(peer);return
				for offset in range(0,bytes.size(),CHUNK):
					var part: PackedByteArray=bytes.slice(offset,offset+CHUNK)
					_chunk.rpc_id(peer,row.hash,row.sent,part);row.sent+=part.size()):
				row.reading=false;row.reading_bytes=0

	var timestamp: int=incoming.get("time",expected.get("time",Time.get_ticks_msec()))
	if Time.get_ticks_msec()-timestamp>30000: game.disconnect_game("Map download timed out.")
