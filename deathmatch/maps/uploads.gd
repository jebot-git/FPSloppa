extends Node
## Authenticated raw-BSP uploads; no scenes/scripts or client filenames are accepted.
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
func setup(arena: Node) -> void:
	game=arena;add_child(disk)
func upload(row: Dictionary) -> void:
	if not game.active or multiplayer.is_server() or not outgoing.is_empty():return
	var size: int=row.get("size",0)
	if size<124 or size>MAX_BYTES:game.status("BSP uploads must be between 124 bytes and 25 MB.");return
	offered=row.duplicate();offered.time=Time.get_ticks_msec();offer.rpc_id(1,row.sha256,size,row.title)
@rpc("any_peer","call_remote","reliable",5)
func offer(hash: String,size: int,title: String) -> void:
	if not multiplayer.is_server():return
	var peer:=multiplayer.get_remote_sender_id()
	if game.players.has(peer) and not game.map_uploads:rejected.rpc_id(peer,"Server map uploads are disabled.");return
	if not game.players.has(peer) or game.players[peer].spectator or not Hash.valid_hash(hash):return
	if size<124 or size>MAX_BYTES:rejected.rpc_id(peer,"BSP uploads must be between 124 bytes and 25 MB.");return
	for row in game.map_catalog:
		if row.sha256==hash:stored.rpc_id(peer,hash,row.id);return
	if incoming.has(peer) or incoming.size()>=2 or Time.get_ticks_msec()<cooldowns.get(peer,0):return
	cooldowns[peer]=Time.get_ticks_msec()+30000
	var total:=size
	for transfer in incoming.values():total+=transfer.size
	var path:=Maps.Paths.folder("maps")+hash+".%d.%d.upload"%[peer,Time.get_ticks_usec()]
	var row:={"hash":hash,"size":size,"offset":0,"written":0,"path":path,"accepting":false,"title":title.left(60),"mode":game.match_mode.kind,"time":Time.get_ticks_msec()}
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
	if not disk.submit(Jobs.map_file.bind(row.path,row.hash,row.title,Maps.Paths.folder("maps")),func(result):
		if not is_same(incoming.get(peer),row):return
		disk.discard(row.path);incoming.erase(peer)
		if result.has("error"):rejected.rpc_id(peer,result.error);return
		var id: String=result.id
		var known:=false
		for entry in game.map_catalog:
			if entry.sha256==row.hash:known=true;break
		if not known:game.map_catalog.append(result)
		# The receiving mode is captured at offer time, even if a vote changes mode.
		var mode: String=row.mode
		if not game.mode_maplists.has(mode):game.mode_maplists[mode]=[]
		if game.mode_maplists[mode].is_empty() and mode==game.match_mode.kind:game.mode_maplists[mode].append(game.current_map)
		if not id in game.mode_maplists[mode] and game.mode_maplists[mode].size()<32:game.mode_maplists[mode].append(id)
		if mode==game.match_mode.kind:game.map_rotation=game.mode_maplists[mode].duplicate()
		disk.submit(IO.text_file.bind(Maps.Paths.folder("maps")+mode+"_maplist.txt","\n".join(game.mode_maplists[mode])+"\n"))
		for client in multiplayer.get_peers():game.votes.offer(client)
		stored.rpc_id(peer,row.hash,id)):
		drop(peer);rejected.rpc_id(peer,"Server disk queue is full.")
@rpc("authority","call_remote","reliable",5)
func ack(hash: String,offset: int) -> void:
	if outgoing.get("hash","")!=hash or offset<outgoing.ack or offset>outgoing.sent:return
	outgoing.ack=offset;outgoing.time=Time.get_ticks_msec()
	if offset==outgoing.size:outgoing={}
@rpc("authority","call_remote","reliable",5)
func stored(hash: String,id: String) -> void:
	if offered.get("sha256","")!=hash:return
	outgoing={};offered.clear();game.status("Map stored on server · vote for "+id)
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
