extends Node
## Bounded JSONL diagnostics. Gameplay commands, voice samples and tracker poses are never serialized.
var game
var level:=0
var file: FileAccess
var path:=""
var max_bytes:=8*1024*1024
var backups:=3
var next_health:=0.0
var next_flush:=0.0
var next_errors:=0
var serial:=0
var counters: Dictionary={}
var last_error:=""
var engine_errors=preload("res://deathmatch/server/engine_errors.gd").new()
var join_stages: Dictionary={}
var redactions: Array=[]
func _enter_tree() -> void:OS.add_logger(engine_errors)
func phase(peer: int,stage: String,data: Dictionary={}) -> void:
	var now:=Time.get_ticks_msec()
	var previous: Dictionary=join_stages.get(peer,{"at":now,"stage":"transport"})
	var row:=data.duplicate();row.merge({"peer":peer,"stage":stage,"previous_stage":previous.stage,"elapsed_ms":now-int(previous.at)},true)
	join_stages[peer]={"stage":stage,"at":now};record("join_stage",row)
func transport(peer: int) -> Dictionary:
	if not game or not game.multiplayer.multiplayer_peer is ENetMultiplayerPeer:return {}
	if not peer in game.multiplayer.get_peers():return {}
	var packet=game.multiplayer.multiplayer_peer.get_peer(peer)
	return {"address":packet.get_remote_address(),"port":packet.get_remote_port(),"rtt_ms":packet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"loss_percent":packet.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)*100.0/ENetPacketPeer.PACKET_LOSS_SCALE}
func setup(arena: Node,settings: Dictionary) -> bool:
	redactions=[str(settings.get("rcon_password",""))]
	game=arena;level={"off":0,"normal":1,"verbose":2}.get(settings.get("sv_log_level","normal"),1)
	path=settings.get("sv_log_file","");max_bytes=int(settings.get("sv_log_max_mb",8))*1024*1024;backups=int(settings.get("sv_log_backups",3))
	if file:file.close();file=null
	if level==0 or path.is_empty():return true
	path=ProjectSettings.globalize_path(path)
	var err:=DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err!=OK:last_error="Cannot create server log directory: "+error_string(err);return false
	return open_file()
func open_file() -> bool:
	file=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
	if not file:last_error="Cannot open server log: "+error_string(FileAccess.get_open_error());return false
	file.seek_end();return true
func record(event: String,data: Dictionary={},detail: int=1) -> void:
	if level<detail or not game or not game.dedicated:return
	serial+=1
	var entry: Dictionary={"utc":Time.get_datetime_string_from_system(true)+"Z","uptime_ms":Time.get_ticks_msec(),"seq":serial,"event":event,"map":game.current_map,"epoch":game.map_epoch,"mode":game.match_mode.kind,"data":data}
	var line:=JSON.stringify(entry)
	for secret in redactions:
		if not secret.is_empty():line=line.replace(secret,"[REDACTED]")
	if line.to_utf8_buffer().size()>16384:line=JSON.stringify({"event":event,"seq":serial,"truncated":true})
	print("SERVER_LOG ",line)
	if not file:return
	if file.get_position()+line.to_utf8_buffer().size()+1>max_bytes:
		if not rotate():push_warning(last_error);return
	file.store_line(line)
	if detail==1:file.flush()
func rotate() -> bool:
	if file:file.close();file=null
	for i in range(backups,0,-1):
		var source: String=path if i==1 else path+"."+str(i-1)
		var dest:=path+"."+str(i)
		if not FileAccess.file_exists(source):continue
		if FileAccess.file_exists(dest):
			var remove_err:=DirAccess.remove_absolute(dest)
			if remove_err!=OK:last_error="Cannot rotate server log: "+error_string(remove_err);return false
		var err:=DirAccess.rename_absolute(source,dest)
		if err!=OK:last_error="Cannot rotate server log: "+error_string(err);return false
	return open_file()
func count(key: String) -> void:
	if level>=2:counters[key]=int(counters.get(key,0))+1
func _process(_delta: float) -> void:
	if not game or not game.dedicated:return
	if Time.get_ticks_msec()>=next_errors:
		for entry in engine_errors.drain():record("engine_diagnostic",entry)
		next_errors=Time.get_ticks_msec()+1000
	if level==0:return
	if file and game.clock>=next_flush:file.flush();next_flush=game.clock+1
	if level<2 or game.clock<next_health:return
	next_health=game.clock+5
	var clients: Array=[]
	for id in game.players:
		var s: Dictionary=game.players[id]
		clients.append({"peer":id,"team":s.team,"spectator":s.spectator,"ping_ms":s.ping,"input_age_ms":roundi(maxf(0,game.clock-s.last_input)*1000),"last_input_seq":s.last_seq,"hp":s.hp,"armor":s.armor,"frags":s.kills,"deaths":s.deaths,"vr":s.vr_device})
	record("health",{"active":game.active,"map_loading":game.map_loading,"round_seconds":snappedf(game.round_left,.01),"intermission":snappedf(game.intermission,.01),"players":clients,"pending_joins":game.pending_joins.size(),"projectiles":game.projectiles.size(),"counters":counters.duplicate(),"voice_relayed":game.voice.relayed_packets,"voice_rejected":game.voice.rejected_packets,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"transport_peers":game.multiplayer.get_peers().size(),"replication":game.replication.stats.duplicate(),"bandwidth":{"asset_bytes":game.bandwidth.asset_bytes,"realtime_bytes":game.bandwidth.realtime_bytes,"throttled":game.bandwidth.throttled},"joins":join_stages.duplicate(true)},2)
	counters.clear()
func _exit_tree() -> void:
	OS.remove_logger(engine_errors)
	if file:file.flush();file.close();file=null
