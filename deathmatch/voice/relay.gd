extends Node
## Shared authenticated packet routing; dedicated servers never load a codec or player.
var game
var sequence:=0
var guard: Dictionary={}
var relayed_packets:=0
var rejected_packets:=0
var volume:=.8
var mode:=1
var mic: Node
var transmitting:=false
func setup(arena: Node) -> void:
	game=arena
	multiplayer.peer_disconnected.connect(remove_peer)
func team_channel() -> bool:return false
func set_mode(value: int,_persist: bool=false) -> void:mode=clampi(value,0,2)
func remove_peer(id: int) -> void:guard.erase(id)
func reset() -> void:guard.clear();sequence=0;game.voice_enabled=true
func mouth_pose(_id: int) -> PackedFloat32Array:return PackedFloat32Array([0,0,0,0,0])

func team_available(id: int=0) -> bool:
	if id==0:id=multiplayer.get_unique_id()
	return game.active and game.match_mode.team_game() and game.players.has(id) and not game.players[id].get("spectator",false) and game.players[id].get("team",-1) in [0,1]

func recipients(id: int,team_only: bool) -> Array:
	var result: Array=[]
	if team_only and not team_available(id):return result
	for peer in game.players:
		if peer!=id and (not team_only or team_available(peer) and game.match_mode.same_team(id,peer)):result.append(peer)
	return result

static func valid_packet(data: PackedByteArray) -> bool:
	# Fixed 48 kHz mono, 20 ms Opus frames. The prefix is replaced by the relay sequence.
	return data.size()>=3 and data.size()<=400 and (data[2]>>3) in [1,5,9,13,15,19,23,27,31] and (data[2]&7)==0

func send_packet(data: PackedByteArray) -> void:
	sequence+=1
	if multiplayer.is_server():relay(multiplayer.get_unique_id(),sequence,data,team_channel())
	else:submit.rpc_id(1,sequence,data,team_channel())

@rpc("any_peer","call_remote","unreliable",6)
func submit(serial: int,data: PackedByteArray,team_only: bool=false) -> void:
	if multiplayer.is_server():relay(multiplayer.get_remote_sender_id(),serial,data,team_only)

func accept_sender(id: int,serial: int,data: PackedByteArray) -> bool:
	if not game.active or not game.voice_enabled or not game.players.has(id) or id<1 or not valid_packet(data) or serial<0 or serial>2147483647:
		rejected_packets+=1;return false
	var state: Dictionary=guard.get(id,{"last":-1,"seen":{},"tokens":12.0,"time":game.clock})
	state.tokens=minf(12,state.tokens+maxf(0,game.clock-state.time)*55);state.time=game.clock;guard[id]=state
	if serial<state.last-32 or state.seen.has(serial) or state.tokens<1:
		rejected_packets+=1;return false
	state.last=maxi(state.last,serial);state.seen[serial]=true;state.tokens-=1
	for old in state.seen.keys():
		if old<state.last-32:state.seen.erase(old)
	return true

func relay(id: int,serial: int,data: PackedByteArray,team_only: bool=false) -> void:
	if not accept_sender(id,serial,data):return
	for peer in recipients(id,team_only):
		game.bandwidth.reserve(data.size()+48,game.clock)
		if peer>1:receive.rpc_id(peer,id,serial,data,team_only)
		elif not game.dedicated:receive(id,serial,data,team_only)
	relayed_packets+=1

@rpc("authority","call_remote","unreliable",6)
func receive(id: int,serial: int,data: PackedByteArray,team_only: bool=false) -> void:
	_receive_audio(id,serial,data,team_only)
func _receive_audio(_id: int,_serial: int,_data: PackedByteArray,_team_only: bool=false) -> void:pass

@rpc("authority","call_remote","reliable",0)
func policy(allowed: bool,host_name: String,backend: String="builtin",external_url: String="") -> void:
	game.voice_backend=backend if backend in ["builtin","mumble"] else "builtin"
	game.mumble_url=external_url if preload("res://deathmatch/voice/external.gd").valid_url(external_url) else ""
	game.voice_enabled=allowed and game.voice_backend=="builtin"
	game.server_name=host_name
	_policy_changed(allowed)
func _policy_changed(_allowed: bool) -> void:pass
