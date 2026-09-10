extends Node
## Only the current host-selected raw BSP is served. No executable scenes cross the network.
const Loader=preload("res://deathmatch/maps/loader.gd")
const Hash=preload("res://deathmatch/avatars/library.gd")
const MAX_BYTES=128_000_000
const CHUNK=32_768
const WINDOW=262_144
var game
var outgoing: Dictionary={}
var expected: Dictionary={}
var incoming: Dictionary={}
var budget:=0.0
var cursor:=0
var message:=""
func setup(arena: Node) -> void: game=arena
func reset() -> void:
	outgoing.clear()
	expected.clear()
	if incoming.has("file"):
		incoming.file.close()
		DirAccess.remove_absolute(incoming.path)
	incoming.clear()
	message=""
func offer(peer: int) -> void:
	var size:=0
	for row in game.map_catalog:
		if row.id==game.current_map: 
			var file:=FileAccess.open(row.path,FileAccess.READ)
			if file: size=file.get_length()
			break
	_offer.rpc_id(peer,game.current_map,game.map_sha,size,game.map_title,game.map_epoch)
@rpc("authority","call_remote","reliable",5)
func _offer(map_id: String,hash: String,size: int,title: String,epoch: int=0) -> void:
	if epoch<game.map_epoch: return
	if epoch>game.map_epoch or game.active: game._prepare_client_map(epoch)
	if not expected.is_empty() or not incoming.is_empty(): return
	for row in game.map_catalog:
		if row.sha256==hash and game._load_map(row.id):
			game.map_loading=false
			game._map_ready.rpc_id(1,hash)
			return
	if not Hash.valid_hash(hash) or size<124 or size>MAX_BYTES:
		game.disconnect_game("Host map has invalid size or identity.")
		return
	expected={"hash":hash,"size":size,"title":title.left(60),"time":Time.get_ticks_msec()}
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
		var file:=FileAccess.open(row.path,FileAccess.READ)
		if not file or file.get_length()<124 or file.get_length()>MAX_BYTES: return
		outgoing[peer]={"hash":hash,"size":file.get_length(),"file":file,"sent":0,"ack":0,"time":Time.get_ticks_msec()}
		_begin.rpc_id(peer,hash,file.get_length())
		return
@rpc("authority","call_remote","reliable",5)
func _begin(hash: String,size: int) -> void:
	if size<124 or size>MAX_BYTES: return
	if expected.get("hash","")!=hash or expected.get("size",0)!=size or not incoming.is_empty(): return
	DirAccess.make_dir_recursive_absolute(Loader.Paths.folder("maps"))
	var path:=Loader.Paths.folder("maps")+hash+".download"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if not file: game.disconnect_game("Cannot write downloaded map."); return
	incoming={"hash":hash,"size":size,"file":file,"path":path,"offset":0,"time":Time.get_ticks_msec()}
@rpc("authority","call_remote","reliable",5)
func _chunk(hash: String,offset: int,bytes: PackedByteArray) -> void:
	if incoming.get("hash","")!=hash: return
	if offset!=incoming.offset or bytes.is_empty() or bytes.size()>CHUNK or offset+bytes.size()>incoming.size:
		game.disconnect_game("Invalid map download chunk."); return
	incoming.file.store_buffer(bytes)
	incoming.offset+=bytes.size()
	incoming.time=Time.get_ticks_msec()
	game.connect_deadline=game.clock+120
	message="Downloading map · %d%%"%int(100.0*incoming.offset/incoming.size)
	game.status(message)
	_ack.rpc_id(1,hash,incoming.offset)
	if incoming.offset==incoming.size: finish.call_deferred()
func finish() -> void:
	if incoming.is_empty(): return
	incoming.file.close()
	var path: String=incoming.path
	var hash: String=incoming.hash
	var title: String=expected.title
	incoming.clear()
	expected.clear()
	if FileAccess.get_sha256(path)!=hash:
		DirAccess.remove_absolute(path)
		game.disconnect_game("Map checksum failed."); return
	game.status("Preparing downloaded arena…")
	await get_tree().process_frame
	var result: Dictionary=Loader.import_custom(path,title)
	DirAccess.remove_absolute(path)
	if result.has("error"):
		game.disconnect_game("Map import failed: "+result.error); return
	game.map_catalog=Loader.catalog()
	if not game._load_map(result.id): game.disconnect_game("Downloaded map could not load."); return
	game.map_title=title
	game.selected_map=result.id
	if game.hud: game.hud.refresh_maps()
	message="Map downloaded and verified."
	game.map_loading=false
	game._map_ready.rpc_id(1,hash)
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
func _process(delta: float) -> void:
	budget=minf(budget+delta*2_097_152,WINDOW)
	var peers:=outgoing.keys()
	if not peers.is_empty(): cursor=(cursor+1)%peers.size()
	for i in range(peers.size()):
		var peer: int=peers[(cursor+i)%peers.size()]
		var row: Dictionary=outgoing[peer]
		if not multiplayer.get_peers().has(peer) or Time.get_ticks_msec()-row.time>30000:
			outgoing.erase(peer); continue
		while row.sent<row.size and row.sent-row.ack<WINDOW and budget>=CHUNK:
			var bytes: PackedByteArray=row.file.get_buffer(mini(CHUNK,row.size-row.sent))
			if bytes.is_empty(): outgoing.erase(peer); break
			_chunk.rpc_id(peer,row.hash,row.sent,bytes)
			row.sent+=bytes.size()
			budget-=bytes.size()
	var timestamp: int=incoming.get("time",expected.get("time",Time.get_ticks_msec()))
	if Time.get_ticks_msec()-timestamp>30000: game.disconnect_game("Map download timed out.")
