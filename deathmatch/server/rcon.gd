extends Node
## One bounded, authenticated command per TCP connection. No shell or script eval.
var game
var listener:=TCPServer.new()
var crypto:=Crypto.new()
var password:=PackedByteArray()
var clients: Array=[]
var attempts: Dictionary={}
var last_error:=""
func setup(arena: Node,settings: Dictionary) -> bool:
	game=arena;password=str(settings.get("rcon_password","")).to_utf8_buffer()
	if password.is_empty():set_process(false);return true
	var bind: String=settings.get("rcon_bind","127.0.0.1")
	var port: int=settings.get("rcon_port",7778)
	var error:=listener.listen(port,bind)
	if error!=OK:last_error="Cannot bind RCON TCP port: "+error_string(error);return false
	game.server_log.record("rcon_started",{"bind":bind,"port":port})
	return true
func mac(message: String) -> PackedByteArray:
	return crypto.hmac_digest(HashingContext.HASH_SHA256,password,message.to_utf8_buffer())
func reply(row: Dictionary,result: Dictionary) -> void:
	var payload:=JSON.stringify(result)
	row.output=(JSON.stringify({"result":payload,"mac":mac(row.nonce+"\nresponse\n"+payload).hex_encode()})+"\n").to_utf8_buffer()
	row.sent=0;row.done=true;row.expires=Time.get_ticks_msec()+2000
func _process(_delta: float) -> void:
	var now:=Time.get_ticks_msec()
	for ip in attempts.keys():
		if now-attempts[ip].at>60000:attempts.erase(ip)
	for accept_index in 4:
		if not listener.is_connection_available():break
		var peer:=listener.take_connection();var ip:=peer.get_connected_host()
		var limit: Dictionary=attempts.get(ip,{"at":now,"count":0})
		if clients.size()>=8 or limit.count>=12 or attempts.size()>=256:
			peer.disconnect_from_host();continue
		limit.count+=1;attempts[ip]=limit
		var nonce:=crypto.generate_random_bytes(32).hex_encode()
		clients.append({"peer":peer,"ip":ip,"nonce":nonce,"input":PackedByteArray(),"output":(JSON.stringify({"nonce":nonce,"protocol":"fpsloppa-rcon-1"})+"\n").to_utf8_buffer(),"sent":0,"expires":now+5000,"done":false})
	for row in clients.duplicate():
		var peer: StreamPeerTCP=row.peer;peer.poll()
		if now>row.expires or peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host();clients.erase(row);continue
		if row.sent<row.output.size():
			var sent:=peer.put_partial_data(row.output.slice(row.sent))
			if sent[0]!=OK:peer.disconnect_from_host();clients.erase(row);continue
			row.sent+=sent[1]
			if row.sent<row.output.size():continue
			if row.done:row.expires=now+200;continue
		if row.done:continue
		var available:=peer.get_available_bytes()
		if available<=0:continue
		if row.input.size()+available>4096:peer.disconnect_from_host();clients.erase(row);continue
		var received:=peer.get_partial_data(available)
		if received[0]!=OK:continue
		row.input.append_array(received[1])
		var end: int=row.input.find(10)
		if end<0:continue
		var request=JSON.parse_string(row.input.slice(0,end).get_string_from_utf8())
		if not request is Dictionary or not request.get("command") is String or not request.get("mac") is String:
			reply(row,{"error":"Malformed request"});continue
		var command: String=request.command
		if command.length()>1024 or request.mac.length()!=64 or not request.mac.is_valid_hex_number(false) or not crypto.constant_time_compare(mac(row.nonce+"\n"+command),request.mac.hex_decode()):
			game.server_log.record("rcon_auth_failed",{"address":row.ip})
			reply(row,{"error":"Authentication failed"});continue
		# Never record the command arguments or password.
		game.server_log.record("rcon_command",{"address":row.ip,"verb":command.get_slice(" ",0).left(32)})
		reply(row,execute(command))
func execute(command: String) -> Dictionary:
	var parsed:=preload("res://deathmatch/server/config.gd").tokens(command)
	if parsed.has("error"):return {"error":parsed.error}
	var words: Array=parsed.words
	if words.is_empty():return {"error":"Empty command"}
	if game.cq_profile and words[0] in ["match","map","mode"]:return {"error":"CQ sessions cannot change mode, map or loadout; use restart."}
	match words[0]:
		"help":return {"commands":["status","bots <count>","map <configured-map>","mode <allowed-mode>","match <allowed-mode> <configured-map> <doom|quake|ut99>","kick <peer-id>","say <message>","restart","loglevel <off|normal|verbose>"]}
		"status":
			var players: Array=[]
			for id in game.players:
				var s: Dictionary=game.players[id];players.append({"id":id,"name":s.name,"spectator":s.spectator,"ping_ms":s.ping,"bot":id<0,"team":s.team,"class":s.tf_class})
			return {"version":ProjectSettings.get_setting("application/config/version"),"protocol":game.connection_protocol(),"map":game.current_map,"mode":game.match_mode.kind,"capacity":game.max_clients,"bot_fill":game.bot_population.target,"bot_count":game.bot_population.count_target,"tb_heavy_ordnance":game.match_mode.fortress.walkers.heavy_ordnance_only,"players":players,"pending":game.pending_joins.size(),"rotation":game.map_rotation,"allowed_modes":game.votes.allowed_modes,"time_remaining":game.round_left,"intermission":game.intermission,"result":game.round_message,"weapon_rules":game.armory.effective(),"lobby":game.lobby.active()}
		"bots":
			if words.size()!=2 or not str(words[1]).is_valid_int():return {"error":"Expected bots <count> (0 disables bots)"}
			var amount:=int(words[1])
			if amount<0 or amount>game.max_clients:return {"error":"Bot count must be between 0 and "+str(game.max_clients)}
			game.bot_population.count_target=amount
			game.bot_population.maintain()
			game.server_log.record("bot_count_changed",{"target":amount})
			return {"ok":true,"bot_count":amount}
		"match":
			if words.size()!=4 or not words[3] in game.armory.IDS:return {"error":"Expected mode, configured map and doom, quake or ut99"}
			if not game.votes.match_choices().any(func(row):return row.mode==words[1] and row.map==words[2]):return {"error":"Match must be in the enabled mode maplists"}
			if game.armory.for_mode(words[1],words[3])!=words[3]:return {"error":words[1].to_upper()+" requires "+game.armory.for_mode(words[1],words[3])+" weapons"}
			change_match.call_deferred(words[1],words[2],words[3])
		"map":
			if words.size()!=2 or not game.votes.choices().any(func(row):return row.id==words[1]):return {"error":"Map must be in the current mode maplist"}
			game.votes.change_map.call_deferred(words[1])
		"mode":
			if words.size()!=2 or not game.votes.allowed_modes.has(words[1]):return {"error":"Mode is not enabled"}
			game.votes.change_mode.call_deferred(words[1])
		"kick":
			if words.size()!=2 or not str(words[1]).is_valid_int() or not game.players.has(int(words[1])):return {"error":"Unknown peer ID"}
			if int(words[1])<0:game._peer_left(int(words[1]))
			else:game.multiplayer.multiplayer_peer.disconnect_peer(int(words[1]))
		"say":
			if words.size()<2:return {"error":"Message required"}
			game._announcement.rpc("ADMIN: "+" ".join(words.slice(1)).left(140))
		"restart":
			if words.size()!=1:return {"error":"Unexpected arguments"}
			game._restart_round.call_deferred()
		"loglevel":
			if words.size()!=2 or not words[1] in ["off","normal","verbose"]:return {"error":"Expected off, normal or verbose"}
			game.server_log.level={"off":0,"normal":1,"verbose":2}[words[1]]
		_:return {"error":"Unknown command; use help"}
	return {"ok":true}
func change_match(mode: String,map_id: String,rules: String) -> void:
	if not game.active:return
	# Pickup entity remapping depends on the ruleset, even on the same BSP.
	if rules!=game.armory.kind:game.current_map=""
	game.armory.select(rules)
	game.votes.change_match(mode+"|"+map_id)
	game.server_log.record("admin_match",{"mode":mode,"map":map_id,"weapon_rules":game.armory.effective()})

func _exit_tree() -> void:
	listener.stop()
	for row in clients:row.peer.disconnect_from_host()
	clients.clear();password.fill(0)
