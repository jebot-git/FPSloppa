extends Node
## Server-mediated avatar sharing. Only announced SHA-256 assets can be requested.
const Library = preload("res://deathmatch/avatars/library.gd")
const CHUNK := 32_768
const WINDOW := CHUNK*8
var library
var game
var choices: Dictionary = {}
var pending: Dictionary = {}
var incoming: Dictionary = {}
var outgoing: Dictionary = {}
var expected: Dictionary = {}
var offered := ""
var next_offer := 0.0
var message := ""
var offer_times: Dictionary = {}
var load_queue: Array = []
var avatar_attempts: Dictionary={}
var transfer_budget := 0.0

func setup(arena: Node) -> void:
	game = arena
	name = "AvatarNetwork"
	library = Library.new()
	library.name = "Library"
	add_child(library)

func reset() -> void:
	for key in incoming.keys(): drop_incoming(key)
	incoming.clear()
	outgoing.clear()
	expected.clear()
	pending.clear()
	choices.clear()
	offer_times.clear()
	offered = ""
	next_offer = 0
	load_queue.clear();avatar_attempts.clear()

func remove_peer(id: int) -> void:
	choices.erase(id);avatar_attempts.erase(id)
	pending.erase(id)
	offer_times.erase(id)
	outgoing.erase(id)
	for hash in incoming.keys():
		if incoming[hash].peer==id: drop_incoming(hash)
	for hash in expected.keys():
		if expected[hash].peer==id: expected.erase(hash)

func _process(delta: float) -> void:
	if not game: return
	if game.active:
		var mine := multiplayer.get_unique_id()
		if game.players.has(mine) and offered!=library.selected and game.clock>=next_offer:
			next_offer = game.clock+3.2
			offered = library.selected
			if library.entries.has(offered):
				if multiplayer.is_server(): accept_offer(mine,offered,library.entries[offered].size)
				else: _offer.rpc_id(1,offered,library.entries[offered].size)
	# Limit aggregate upload to 2 MiB/s and eight unacknowledged chunks per peer.
	transfer_budget = minf(transfer_budget+delta*2_097_152,WINDOW)
	for peer in outgoing.keys():
		if not multiplayer.get_peers().has(peer): outgoing.erase(peer); continue
		var transfer: Dictionary = outgoing[peer]
		if Time.get_ticks_msec()-transfer.time>30000: outgoing.erase(peer); continue
		while transfer.sent-transfer.ack<WINDOW and transfer.sent<transfer.size and transfer_budget>=CHUNK:
			var data: PackedByteArray = transfer.file.get_buffer(mini(CHUNK,transfer.size-transfer.sent))
			if data.is_empty(): outgoing.erase(peer); break
			_chunk.rpc_id(peer,transfer.hash,transfer.sent,data)
			transfer.sent += data.size()
			transfer_budget -= data.size()
	for hash in incoming.keys():
		if Time.get_ticks_msec()-incoming[hash].time>30000:
			drop_incoming(hash)
			message = "Avatar transfer timed out; using fallback marine."
	for hash in expected.keys():
		if Time.get_ticks_msec()-expected[hash].time>30000:
			pending.erase(expected[hash].peer)
			expected.erase(hash)
	if not game.headless:
		for player_id in choices:queue_avatar(player_id)
	if not load_queue.is_empty() and not game.headless:
		var id: int = load_queue.pop_front()
		if game.fighters.has(id) and choices.has(id):
			var hash: String = game.match_mode.fortress.display_avatar(id,choices[id].hash)
			if library.entries.has(hash):
				avatar_attempts[id]=hash+":"+str(game.fighters[id].get_instance_id())
				var avatar: Node3D = library.create_avatar(hash)
				if avatar:
					game.fighters[id].set_avatar(avatar,hash)

@rpc("any_peer","call_remote","reliable",4)
func _offer(hash: String, size: int) -> void:
	if not multiplayer.is_server(): return
	accept_offer(multiplayer.get_remote_sender_id(),hash,size)

func accept_offer(id: int, hash: String, size: int) -> void:
	if not game.players.has(id) or not Library.valid_hash(hash) or size<=0 or size>Library.MAX_BYTES: return
	var now := Time.get_ticks_msec()
	if now-int(offer_times.get(id,-10000))<3000: return
	offer_times[id] = now
	if library.entries.has(hash):
		if library.entries[hash].size!=size: return
		choices[id] = {"hash":hash,"size":size}
		publish()
	else:
		if pending.has(id): return
		pending[id] = {"hash":hash,"size":size}
		if not expected.has(hash) and not incoming.has(hash):
			expected[hash] = {"peer":id,"size":size,"time":now}
			_request.rpc_id(id,hash)

func publish() -> void:
	_catalog(choices)
	for peer in multiplayer.get_peers():
		if game.players.has(peer): _catalog.rpc_id(peer,choices)

func sync_peer(id: int) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().has(id): _catalog.rpc_id(id,choices)

@rpc("authority","call_remote","reliable",4)
func _catalog(data: Dictionary) -> void:
	if data.size()>game.SERVER_MAX_PLAYERS: return
	choices = data.duplicate(true)
	library.pinned = choices.values().map(func(row): return row.hash)
	for id in choices:
		var hash: String = choices[id].hash
		var size: int = choices[id].size
		if not Library.valid_hash(hash) or size<=0 or size>Library.MAX_BYTES: continue
		if not library.entries.has(hash) and FileAccess.file_exists(Library.CACHE+hash+".vrm"):
			if FileAccess.get_sha256(Library.CACHE+hash+".vrm")==hash: library.register_file(Library.CACHE+hash+".vrm",false)
		if library.entries.has(hash): queue_avatar(id)
		elif not multiplayer.is_server() and not expected.has(hash) and not incoming.has(hash):
			expected[hash] = {"peer":1,"size":size,"time":Time.get_ticks_msec()}
			_request.rpc_id(1,hash)

func queue_avatar(id: int) -> void:
	if not game.fighters.has(id) or not choices.has(id):return
	var hash: String=game.match_mode.fortress.display_avatar(id,choices[id].hash)
	var attempt: String=hash+":"+str(game.fighters[id].get_instance_id())
	if library.entries.has(hash) and game.fighters[id].avatar_hash!=hash and avatar_attempts.get(id,"")!=attempt and not load_queue.has(id):
		load_queue.append(id)

@rpc("any_peer","call_remote","reliable",4)
func _request(hash: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not Library.valid_hash(hash) or not library.entries.has(hash): return
	if multiplayer.is_server():
		if not game.players.has(peer): return
		var allowed := false
		for row in choices.values():
			if row.hash==hash: allowed = true
		if not allowed: return
	else:
		if peer!=1 or hash!=offered: return
	if outgoing.has(peer):
		# One upload per destination. Receiver retries after current asset completes.
		_busy.rpc_id(peer,hash)
		return
	var entry: Dictionary = library.entries[hash]
	var file := FileAccess.open(entry.path,FileAccess.READ)
	if not file or file.get_length()!=entry.size or entry.size>Library.MAX_BYTES: return
	outgoing[peer] = {"hash":hash,"size":entry.size,"file":file,"sent":0,"ack":0,"time":Time.get_ticks_msec()}
	_begin.rpc_id(peer,hash,entry.size)

@rpc("any_peer","call_remote","reliable",4)
func _busy(hash: String) -> void:
	if not expected.has(hash) or expected[hash].peer!=multiplayer.get_remote_sender_id(): return
	await get_tree().create_timer(1.0).timeout
	if expected.has(hash) and game.active:
		expected[hash].time = Time.get_ticks_msec()
		_request.rpc_id(expected[hash].peer,hash)

@rpc("any_peer","call_remote","reliable",4)
func _begin(hash: String, size: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not expected.has(hash) or expected[hash].peer!=peer or expected[hash].size!=size or size>Library.MAX_BYTES or size<=0: return
	if incoming.has(hash): return
	var path: String = Library.CACHE+hash+".%d.part"%multiplayer.get_unique_id()
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not file: return
	incoming[hash] = {"peer":peer,"size":size,"offset":0,"file":file,"path":path,"time":Time.get_ticks_msec()}
	expected.erase(hash)

@rpc("any_peer","call_remote","reliable",4)
func _chunk(hash: String, offset: int, bytes: PackedByteArray) -> void:
	if not incoming.has(hash): return
	var transfer: Dictionary = incoming[hash]
	if transfer.peer!=multiplayer.get_remote_sender_id(): return
	if offset!=transfer.offset or bytes.is_empty() or bytes.size()>CHUNK or offset+bytes.size()>transfer.size:
		drop_incoming(hash)
		return
	transfer.file.store_buffer(bytes)
	transfer.offset += bytes.size()
	transfer.time = Time.get_ticks_msec()
	message = "Downloading avatar · %d%%" % int(100.0*transfer.offset/transfer.size)
	_ack.rpc_id(transfer.peer,hash,transfer.offset)
	if transfer.offset==transfer.size:
		transfer.file.close()
		var path: String = transfer.path
		incoming.erase(hash)
		if FileAccess.get_sha256(path)!=hash:
			DirAccess.remove_absolute(path)
			pending.erase(transfer.peer)
			message = "Avatar checksum failed; using fallback marine."
			return
		var result: String = library.register_file(path)
		DirAccess.remove_absolute(path)
		if result!=hash:
			pending.erase(transfer.peer)
			message = library.last_error
			return
		message = "Avatar downloaded and verified."
		if multiplayer.is_server():
			for id in pending.keys():
				if pending[id].hash==hash and game.players.has(id):
					choices[id] = pending[id]
					pending.erase(id)
			publish()
		else:
			for id in choices:
				if choices[id].hash==hash: queue_avatar(id)

@rpc("any_peer","call_remote","reliable",4)
func _ack(hash: String, offset: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not outgoing.has(peer): return
	var transfer: Dictionary = outgoing[peer]
	if transfer.hash!=hash or offset<transfer.ack or offset>transfer.sent: return
	transfer.ack = offset
	transfer.time = Time.get_ticks_msec()
	if offset==transfer.size: outgoing.erase(peer)

func drop_incoming(hash: String) -> void:
	if not incoming.has(hash): return
	pending.erase(incoming[hash].peer)
	incoming[hash].file.close()
	DirAccess.remove_absolute(incoming[hash].path)
	incoming.erase(hash)
