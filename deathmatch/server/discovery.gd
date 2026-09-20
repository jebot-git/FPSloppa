extends Node
## Stateless UDP cookies; asynchronous master heartbeats never gate simulation.
const Protocol=preload("res://deathmatch/server/discovery_protocol.gd")
var game
var socket:=PacketPeerUDP.new()
var crypto:=Crypto.new()
var secret:=PackedByteArray()
var attempts: Dictionary={}
var window:=0
var total:=0
var query_port:=0
var game_port:=0
var master_url:=""
var token:=""
var http: HTTPRequest
var next_heartbeat:=0
var retry_seconds:=5
var busy:=false
var last_error:=""

func setup(arena: Node, settings: Dictionary, port: int, registration_token: String="") -> bool:
	game=arena;game_port=port;query_port=int(settings.sv_query_port)
	if query_port==0:set_process(false);return true
	if query_port==game_port:last_error="sv_query_port must differ from the gameplay UDP port.";return false
	var error:=socket.bind(query_port,game.bind_address)
	if error!=OK:last_error="Cannot bind discovery UDP port: "+error_string(error);return false
	secret=crypto.generate_random_bytes(32)
	game.server_log.record("discovery_started",{"query_port":query_port,"public":settings.sv_public==1})
	if settings.sv_public==1:
		token=registration_token if not registration_token.is_empty() else OS.get_environment("FPSLOPPA_MASTER_TOKEN")
		if token.length()<32 or token.length()>256 or not token.is_valid_hex_number(false):
			last_error="Public listing requires FPSLOPPA_MASTER_TOKEN (32–256 hex characters).";return false
		master_url=str(settings.sv_master_url).trim_suffix("/")
		http=HTTPRequest.new();add_child(http)
		http.timeout=5;http.body_size_limit=4096;http.max_redirects=0;http.use_threads=true
		http.request_completed.connect(_heartbeat_complete)
	return true

func snapshot() -> Dictionary:
	var humans:=0;var spectators:=0;var bots:=0
	for id in game.players:
		if id<0:bots+=1
		elif game.players[id].get("spectator",false):spectators+=1
		else:humans+=1
	var seats: int=game.bot_population.human_slots()
	return {"name":Protocol.public_text(str(game.server_name)),"map":Protocol.public_text(str(game.current_map)),"map_title":Protocol.public_text(str(game.map_title)),"mode":game.match_mode.kind,"weapon_rules":game.armory.effective(),"protocol":game.PROTOCOL,"version":str(ProjectSettings.get_setting("application/config/version","unknown")).left(40),"game_port":game_port,"capacity":game.max_clients,"humans":humans,"spectators":spectators,"bots":bots,"reserved":maxi(0,seats-humans-spectators),"open_slots":maxi(0,game.max_clients-seats),"state":"loading" if game.map_loading else "lobby" if game.lobby.active() else "intermission" if game.intermission>0 else "match"}

func cookie(ip: String, port: int, nonce: String, bucket: int) -> String:
	return crypto.hmac_digest(HashingContext.HASH_SHA256,secret,(ip+"|"+str(port)+"|"+nonce+"|"+str(bucket)).to_utf8_buffer()).hex_encode()

func _process(_delta: float) -> void:
	if not game.active:return
	var now:=Time.get_ticks_msec()
	if now-window>=1000:window=now;total=0;attempts.clear()
	for index in 32:
		if socket.get_available_packet_count()==0:break
		var bytes:=socket.get_packet();var ip:=socket.get_packet_ip();var port:=socket.get_packet_port()
		if total>=128 or int(attempts.get(ip,0))>=16:continue
		total+=1;attempts[ip]=int(attempts.get(ip,0))+1
		var request:=Protocol.decode(bytes)
		var nonce: String=request.get("nonce","") if request.get("nonce") is String else ""
		if nonce.length()!=32 or not nonce.is_valid_hex_number(false):continue
		var bucket:=int(now/10000)
		var response: Dictionary={"wire":Protocol.WIRE,"nonce":nonce}
		if request.get("kind")=="hello":
			response.kind="challenge";response.cookie=cookie(ip,port,nonce,bucket)
		elif request.get("kind")=="status":
			var supplied: String=request.get("cookie","") if request.get("cookie") is String else ""
			if supplied.length()!=64 or not supplied.is_valid_hex_number(false):continue
			if not crypto.constant_time_compare(supplied.hex_decode(),cookie(ip,port,nonce,bucket).hex_decode()) and not crypto.constant_time_compare(supplied.hex_decode(),cookie(ip,port,nonce,bucket-1).hex_decode()):continue
			response.kind="status";response.status=snapshot()
		else:continue
		var output:=JSON.stringify(response).to_utf8_buffer()
		if output.size()>Protocol.MAX_PACKET or (request.kind=="hello" and output.size()>bytes.size()):continue
		if socket.set_dest_address(ip,port)==OK:socket.put_packet(output)
	if http and not busy and now>=next_heartbeat:
		busy=true
		var body:=JSON.stringify({"query_port":query_port,"game_port":game_port})
		var error:=http.request(master_url+"/v1/heartbeat",["Content-Type: application/json","Authorization: Bearer "+token],HTTPClient.METHOD_POST,body)
		if error!=OK:_heartbeat_complete(HTTPRequest.RESULT_CANT_CONNECT,0,PackedStringArray(),PackedByteArray())

func _heartbeat_complete(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	busy=false
	var success:=result==HTTPRequest.RESULT_SUCCESS and code==200
	if success:retry_seconds=5
	next_heartbeat=Time.get_ticks_msec()+(30000+randi_range(0,2000) if success else retry_seconds*1000)
	if not success:retry_seconds=mini(60,retry_seconds*2)
	game.server_log.record("master_heartbeat",{"ok":success,"http_status":code,"result":result})

func _exit_tree() -> void:
	socket.close()
	if http:http.cancel_request()
	token=""
