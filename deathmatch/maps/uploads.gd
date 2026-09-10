extends Node
## Authenticated raw-BSP uploads; no scenes/scripts or client filenames are accepted.
const Maps=preload("res://deathmatch/maps/loader.gd")
const Hash=preload("res://deathmatch/avatars/library.gd")
const CHUNK:=32768
const MAX_BYTES:=128_000_000
const DISK_BUDGET:=2_000_000_000
var game
var incoming: Dictionary={}
var outgoing: Dictionary={}
var offered: Dictionary={}
var cooldowns: Dictionary={}
var budget:=0.0
func setup(arena: Node) -> void:game=arena
func upload(row: Dictionary) -> void:
	if not game.active or multiplayer.is_server() or not outgoing.is_empty():return
	var file:=FileAccess.open(row.path,FileAccess.READ)
	if not file:return
	var size:=file.get_length();file.close()
	offered=row.duplicate();offered.time=Time.get_ticks_msec();offer.rpc_id(1,row.sha256,size,row.title)
@rpc("any_peer","call_remote","reliable",5)
func offer(hash: String,size: int,title: String) -> void:
	if not multiplayer.is_server():return
	var peer:=multiplayer.get_remote_sender_id()
	if game.players.has(peer) and not game.map_uploads:rejected.rpc_id(peer,"Server map uploads are disabled.");return
	if not game.players.has(peer) or game.players[peer].spectator or not Hash.valid_hash(hash) or size<124 or size>MAX_BYTES:return
	for row in game.map_catalog:
		if row.sha256==hash:stored.rpc_id(peer,hash,row.id);return
	if incoming.has(peer) or incoming.size()>=2 or Time.get_ticks_msec()<cooldowns.get(peer,0):return
	cooldowns[peer]=Time.get_ticks_msec()+30000
	var total:=size
	for transfer in incoming.values():total+=transfer.size
	for file in DirAccess.get_files_at(Maps.Paths.folder("maps")):
		if file.ends_with(".bsp"):
			var source:=FileAccess.open(Maps.Paths.folder("maps")+file,FileAccess.READ)
			if source:total+=source.get_length()
	if total>DISK_BUDGET:rejected.rpc_id(peer,"Server map folder has reached its 2 GB limit.");return
	var path:=Maps.Paths.folder("maps")+hash+".%d.upload"%peer
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if not file:return
	incoming[peer]={"hash":hash,"size":size,"offset":0,"path":path,"file":file,"title":title.left(60),"time":Time.get_ticks_msec()}
	ready.rpc_id(peer,hash)
@rpc("authority","call_remote","reliable",5)
func ready(hash: String) -> void:
	if offered.get("sha256","")!=hash:return
	var file:=FileAccess.open(offered.path,FileAccess.READ)
	if not file:return
	outgoing={"hash":hash,"file":file,"size":file.get_length(),"sent":0,"ack":0,"time":Time.get_ticks_msec()}
@rpc("any_peer","call_remote","reliable",5)
func chunk(hash: String,offset: int,bytes: PackedByteArray) -> void:
	if not multiplayer.is_server():return
	var peer:=multiplayer.get_remote_sender_id()
	if not incoming.has(peer):return
	var row: Dictionary=incoming[peer]
	if row.hash!=hash or offset!=row.offset or bytes.is_empty() or bytes.size()>CHUNK or offset+bytes.size()>row.size:drop(peer);return
	row.file.store_buffer(bytes);row.offset+=bytes.size();row.time=Time.get_ticks_msec();ack.rpc_id(peer,hash,row.offset)
	if row.offset!=row.size:return
	row.file.close();incoming.erase(peer)
	if FileAccess.get_sha256(row.path)!=hash or not Maps.validate(row.path).is_empty():DirAccess.remove_absolute(row.path);return
	var source:=FileAccess.open(row.path,FileAccess.READ);source.seek(4);var start:=source.get_32();var length:=source.get_32();source.seek(start);var entities:=source.get_buffer(length).get_string_from_utf8();source.close()
	if entities.count('"info_player_deathmatch"')<2:DirAccess.remove_absolute(row.path);return
	var id:="custom_"+hash;var path:=Maps.Paths.folder("maps")+id+".bsp"
	if DirAccess.rename_absolute(row.path,path)!=OK:DirAccess.remove_absolute(row.path);return
	game.map_catalog=Maps.catalog()
	# Persist only in the receiving mode's list. Other modes keep their own rotation.
	if not game.mode_maplists.has(game.match_mode.kind):game.mode_maplists[game.match_mode.kind]=game.map_rotation.duplicate()
	if game.mode_maplists[game.match_mode.kind].is_empty():game.mode_maplists[game.match_mode.kind].append(game.current_map)
	if not id in game.mode_maplists[game.match_mode.kind] and game.mode_maplists[game.match_mode.kind].size()<32:game.mode_maplists[game.match_mode.kind].append(id)
	game.map_rotation=game.mode_maplists[game.match_mode.kind].duplicate()
	var list_file:=FileAccess.open(Maps.Paths.folder("maps")+game.match_mode.kind+"_maplist.txt",FileAccess.WRITE)
	if list_file:list_file.store_string("\n".join(game.map_rotation)+"\n")
	for client in multiplayer.get_peers():game.votes.offer(client)
	stored.rpc_id(peer,hash,id)
@rpc("authority","call_remote","reliable",5)
func ack(hash: String,offset: int) -> void:
	if outgoing.get("hash","")!=hash or offset<outgoing.ack or offset>outgoing.sent:return
	outgoing.ack=offset;outgoing.time=Time.get_ticks_msec()
	if offset==outgoing.size:outgoing.clear()
@rpc("authority","call_remote","reliable",5)
func stored(hash: String,id: String) -> void:
	if offered.get("sha256","")!=hash:return
	outgoing.clear();offered.clear();game.status("Map stored on server · vote for "+id)
@rpc("authority","call_remote","reliable",5)
func rejected(reason: String) -> void:
	outgoing.clear();offered.clear();game.status(reason.left(160))
func drop(peer: int) -> void:
	if not incoming.has(peer):return
	incoming[peer].file.close();DirAccess.remove_absolute(incoming[peer].path);incoming.erase(peer)
func reset() -> void:
	for peer in incoming.keys():drop(peer)
	outgoing.clear();offered.clear();cooldowns.clear()
func _process(delta: float) -> void:
	for peer in incoming.keys():
		if not game.players.has(peer) or Time.get_ticks_msec()-incoming[peer].time>30000:drop(peer)
	if not offered.is_empty() and Time.get_ticks_msec()-offered.time>120000:rejected("Map upload timed out or was rejected.")
	if outgoing.is_empty():return
	if not game.active or Time.get_ticks_msec()-outgoing.time>30000:outgoing.clear();return
	budget=minf(budget+delta*2_097_152,262144)
	while outgoing.sent-outgoing.ack<262144 and outgoing.sent<outgoing.size and budget>=CHUNK:
		var bytes: PackedByteArray=outgoing.file.get_buffer(mini(CHUNK,outgoing.size-outgoing.sent))
		if bytes.is_empty():outgoing.clear();return
		chunk.rpc_id(1,outgoing.hash,outgoing.sent,bytes);outgoing.sent+=bytes.size();budget-=bytes.size()
