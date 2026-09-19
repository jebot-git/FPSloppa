extends Node
## Authenticated raw-BSP uploads; no scenes/scripts or client-controlled disk paths are accepted.
const Maps=preload("res://deathmatch/maps/loader.gd")
const Hash=preload("res://deathmatch/avatars/library.gd")
const CHUNK:=32768
const MAX_BYTES:=Maps.MAX_BYTES
const DISK_BUDGET:=2_000_000_000
const IO=preload("res://deathmatch/network/disk_worker.gd")
const Jobs=preload("res://deathmatch/network/asset_jobs.gd")
var disk=IO.new()
var game
var incoming: Dictionary={}
var outgoing: Dictionary={}
var offered: Dictionary={}
var cooldowns: Dictionary={}
var budget:=0.0
var pending_maplists: Dictionary={}
func setup(arena: Node) -> void:
	game=arena;add_child(disk)
func upload(row: Dictionary) -> void:
	if not game.active or multiplayer.is_server() or not outgoing.is_empty() or not offered.is_empty():return
	var size: int=row.get("size",0)
	if size<124 or size>MAX_BYTES:game.status("BSP uploads must be between 124 bytes and 25 MB.");return
	offered=row.duplicate();offered.time=Time.get_ticks_msec();offer.rpc_id(1,row.sha256,size,row.title,row.get("source_name",row.id),game.map_previews.bytes_for(row.sha256))
@rpc("any_peer","call_remote","reliable",5)
func offer(hash: String,size: int,title: String,source_name: String="",preview: PackedByteArray=PackedByteArray()) -> void:
	if not multiplayer.is_server():return
	var peer:=multiplayer.get_remote_sender_id()
	if game.players.has(peer) and not game.map_uploads:rejected.rpc_id(peer,"Server map uploads are disabled.");return
	if not game.players.has(peer) or not Hash.valid_hash(hash):return
	if source_name.length()>256 or preview.size()>game.map_previews.MAX_BYTES:rejected.rpc_id(peer,"Invalid map metadata or preview size.");return
	if size<124 or size>MAX_BYTES:rejected.rpc_id(peer,"BSP uploads must be between 124 bytes and 25 MB.");return
	for row in game.map_catalog:
		if row.sha256==hash:
			if not preview.is_empty() and game.map_previews.bytes_for(hash).is_empty():game.map_previews.store_png(hash,preview)
			if row.get("imported",false):register_map(row)
			stored.rpc_id(peer,hash,row.id);return
	if incoming.has(peer) or incoming.size()>=2:rejected.rpc_id(peer,"Server is receiving maps; try again shortly.");return
	if Time.get_ticks_msec()<cooldowns.get(peer,0):rejected.rpc_id(peer,"Please wait 30 seconds between new map uploads.");return
	cooldowns[peer]=Time.get_ticks_msec()+30000
	var total:=size
	for transfer in incoming.values():total+=transfer.size
	var path:=Maps.Paths.folder("maps")+hash+".%d.%d.upload"%[peer,Time.get_ticks_usec()]
	var row:={"hash":hash,"size":size,"offset":0,"written":0,"path":path,"accepting":false,"title":title.left(60),"source_name":Maps.ImportPolicy.source_name(source_name),"preview":preview,"time":Time.get_ticks_msec()}
	incoming[peer]=row;disk.track(path)
	if not disk.submit(Jobs.room.bind(Maps.Paths.folder("maps"),"bsp",total,DISK_BUDGET),func(allowed):
		if not is_same(incoming.get(peer),row):return
		if not allowed:drop(peer);rejected.rpc_id(peer,"Server map folder has reached its 2 GB limit.");return
		row.accepting=true;ready.rpc_id(peer,hash)):
		drop(peer);rejected.rpc_id(peer,"Server disk queue is full." )
@rpc("authority","call_remote","reliable",5)
func ready(hash: String) -> void:
	if offered.get("sha256","")!=hash:return
	outgoing={"hash":hash,"path":offered.path,"size":offered.size,"reading":false,"sent":0,"ack":0,"time":Time.get_ticks_msec()}
@rpc("any_peer","call_remote","reliable",5)
func chunk(hash: String,offset: int,bytes: PackedByteArray) -> void:
	if not multiplayer.is_server():return
	var peer:=multiplayer.get_remote_sender_id()
	if not incoming.has(peer):return
	var row: Dictionary=incoming[peer]
	if not row.accepting or row.hash!=hash or offset!=row.offset or bytes.is_empty() or bytes.size()>CHUNK or offset+bytes.size()>row.size:drop(peer);return
	var end:=offset+bytes.size()
	if end-row.written>262144:drop(peer);return
	row.offset=end;row.time=Time.get_ticks_msec()
	if not disk.submit(IO.write.bind(row.path,offset,bytes),func(error):
		if not is_same(incoming.get(peer),row):return
		if error!=OK:drop(peer);rejected.rpc_id(peer,"Cannot write map upload.");return
		row.written=end;row.time=Time.get_ticks_msec();ack.rpc_id(peer,hash,end)
		if end==row.size:finish_upload(peer,row)):
		drop(peer);rejected.rpc_id(peer,"Server disk queue is full.")
func finish_upload(peer: int,row: Dictionary) -> void:
	if not disk.submit(Jobs.map_file.bind(row.path,row.hash,row.title,Maps.Paths.folder("maps"),row.source_name),func(result):
		if not is_same(incoming.get(peer),row):return
		disk.discard(row.path);incoming.erase(peer)
		if result.has("error"):rejected.rpc_id(peer,result.error);return
		var id: String=result.id
		var known:=false
		for entry in game.map_catalog:
			if entry.sha256==row.hash:known=true;break
		if not known:game.map_catalog.append(result)
		var full_lists:=register_map(result)
		if not row.preview.is_empty():game.map_previews.store_png(row.hash,row.preview)
		for client in multiplayer.get_peers():game.votes.offer(client)
		stored.rpc_id(peer,row.hash,id,"Full maplists: "+", ".join(full_lists).to_upper() if not full_lists.is_empty() else "")):
		drop(peer);rejected.rpc_id(peer,"Server disk queue is full.")
func register_map(row: Dictionary) -> Array:
	var full: Array=[]
	# Never choose the running mode: classification belongs to the imported file.
	for mode in row.get("modes",Maps.ImportPolicy.DEFAULT_MODES):
		var maps: Array=game.mode_maplists.get(mode,[]).duplicate()
		var destination: String=Maps.Paths.folder("maps")+mode+"_maplist.txt"
		if maps.is_empty() and FileAccess.file_exists(destination):
			for line in FileAccess.get_file_as_string(destination).split("\n"):
				for name in line.split("#")[0].replace("\t"," ").strip_edges().split(" ",false):
					if not name in maps:maps.append(name)
		if maps.is_empty():maps=Maps.choices_for_mode(game.map_catalog.filter(func(entry):return entry.id!=row.id),mode).slice(0,31)
		if not row.id in maps:
			if maps.size()<32:maps.append(row.id)
			else:full.append(mode)
		game.mode_maplists[mode]=maps
		if mode==game.match_mode.kind:game.map_rotation=maps.duplicate()
		pending_maplists[destination]="\n".join(maps)+"\n"
	return full
@rpc("authority","call_remote","reliable",5)
func ack(hash: String,offset: int) -> void:
	if outgoing.get("hash","")!=hash or offset<outgoing.ack or offset>outgoing.sent:return
	outgoing.ack=offset;outgoing.time=Time.get_ticks_msec()
	if offset==outgoing.size:outgoing={}
@rpc("authority","call_remote","reliable",5)
func stored(hash: String,id: String,note: String="") -> void:
	if offered.get("sha256","")!=hash:return
	outgoing={};offered.clear();game.status("Map stored on server · vote for "+id+(" · "+note.left(100) if not note.is_empty() else ""))
@rpc("authority","call_remote","reliable",5)
func rejected(reason: String) -> void:
	outgoing={};offered.clear();game.status(reason.left(160))
func drop(peer: int) -> void:
	if not incoming.has(peer):return
	disk.discard(incoming[peer].path);incoming.erase(peer)
func reset() -> void:
	for peer in incoming.keys():drop(peer)
	outgoing={};offered.clear();cooldowns.clear()
func _process(delta: float) -> void:
	for path in pending_maplists.keys():
		if disk.submit(IO.text_file.bind(path,pending_maplists[path])):pending_maplists.erase(path)
		else:break
	for peer in incoming.keys():
		if not game.players.has(peer) or Time.get_ticks_msec()-incoming[peer].time>30000:drop(peer)
	if not offered.is_empty() and Time.get_ticks_msec()-offered.time>120000:rejected("Map upload timed out or was rejected.")
	if outgoing.is_empty():return
	if not game.active or Time.get_ticks_msec()-outgoing.time>30000:outgoing={};return
	budget=minf(budget+delta*2_097_152,262144)
	var row:=outgoing
	if not row.reading and row.sent-row.ack<262144 and row.sent<row.size and budget>=CHUNK:
		var count:=mini(mini(262144-(row.sent-row.ack),row.size-row.sent),int(budget/CHUNK)*CHUNK)
		row.reading=true;budget-=count
		if not disk.submit(IO.read.bind(row.path,row.sent,count,row.size),func(bytes):
			if not is_same(outgoing,row):return
			row.reading=false
			if bytes.size()!=count:outgoing={};return
			for offset in range(0,bytes.size(),CHUNK):
				var part: PackedByteArray=bytes.slice(offset,offset+CHUNK)
				chunk.rpc_id(1,row.hash,row.sent,part);row.sent+=part.size()):
			row.reading=false;budget+=count
