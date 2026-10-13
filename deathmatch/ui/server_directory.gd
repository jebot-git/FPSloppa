extends Node
## Browser data and bounded UDP probes, independent of the gameplay ENet peer.
const Protocol=preload("res://deathmatch/server/discovery_protocol.gd")
const Profile=preload("res://deathmatch/profile.gd")
signal changed
signal notice(value: String)
var rows: Dictionary={}
var favorites: Dictionary={}
var master_url:=""
var http: HTTPRequest
var queue: Array=[]
var probes: Array=[]
var crypto:=Crypto.new()
var fetching:=false
var next_refresh:=0

func _ready() -> void:
	http=HTTPRequest.new();add_child(http)
	http.timeout=5;http.body_size_limit=1048576;http.max_redirects=0;http.use_threads=true
	http.request_completed.connect(_listed)
	var config:=ConfigFile.new()
	if config.load(Profile.config_path())==OK:
		var url=str(config.get_value("browser","master_url",""))
		if Protocol.valid_url(url):master_url=url.trim_suffix("/")
		var saved=config.get_value("browser","favorites",[])
		if saved is Array:
			for value in saved.slice(0,128):
				if Protocol.valid_endpoint(value):
					var entry: Dictionary={"address":value.address,"game_port":int(value.game_port),"query_port":int(value.query_port)}
					var key:=Protocol.endpoint_key(entry)
					favorites[key]=entry;rows[key]=entry.duplicate()

func save() -> bool:
	var config:=ConfigFile.new()
	var error:=config.load(Profile.config_path())
	if error!=OK and error!=ERR_FILE_NOT_FOUND:notice.emit("Could not read browser preferences.");return false
	config.set_value("browser","master_url",master_url)
	config.set_value("browser","favorites",favorites.values())
	if config.save(Profile.config_path())!=OK:notice.emit("Could not save browser preferences.");return false
	return true

func set_master(url: String) -> bool:
	url=url.strip_edges().trim_suffix("/")
	if not url.is_empty() and not Protocol.valid_url(url):notice.emit("Enter an HTTPS master URL. Local testing also accepts http://127.0.0.1:PORT.");return false
	if url!=master_url:
		cancel();master_url=url;rows.clear()
		for key in favorites:rows[key]=favorites[key].duplicate()
	return save()

func add_favorite(address: String, game_port: int, query_port: int) -> String:
	var entry: Dictionary={"address":address.strip_edges(),"game_port":game_port,"query_port":query_port}
	if not Protocol.valid_endpoint(entry):notice.emit("Use an IPv4 or IPv6 address and different game/query ports (1024–65535).");return ""
	var key:=Protocol.endpoint_key(entry)
	if favorites.size()>=128 and not favorites.has(key):notice.emit("Favorites are limited to 128 servers.");return ""
	favorites[key]=entry
	if not rows.has(key):rows[key]=entry.duplicate()
	save();changed.emit();return key

func toggle_favorite(key: String) -> void:
	if not rows.has(key):return
	if favorites.has(key):favorites.erase(key);save();changed.emit()
	else:add_favorite(rows[key].address,int(rows[key].game_port),int(rows[key].query_port))

func refresh() -> void:
	if Time.get_ticks_msec()<next_refresh:notice.emit("Wait a moment before refreshing again.");return
	next_refresh=Time.get_ticks_msec()+3000
	cancel();_probe_known()
	if master_url.is_empty():notice.emit("Add favorites or configure a master URL to discover public servers.");return
	fetching=true;notice.emit("Fetching public servers…")
	if http.request(master_url+"/v1/servers")!=OK:
		fetching=false;notice.emit("Directory unavailable. Checking known servers and favorites.")

func _listed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	fetching=false
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		notice.emit("Directory unavailable. Checking known servers and favorites.");return
	var parser:=JSON.new()
	if parser.parse(body.get_string_from_utf8())!=OK:notice.emit("Directory returned invalid JSON.");return
	var value=parser.data
	if not value is Dictionary or value.get("schema")!=1 or not value.get("servers") is Array or value.servers.size()>Protocol.MAX_SERVERS:
		notice.emit("Directory returned an unsupported or oversized list.");return
	var incoming: Dictionary={}
	for entry in value.servers:
		if not Protocol.valid_endpoint(entry) or not Protocol.valid_status(entry):
			notice.emit("Directory returned an invalid server entry.");return
		var key:=Protocol.endpoint_key(entry)
		incoming[key]=entry.duplicate();incoming[key].online=false
	# A successful listing removes expired public rows but preserves favorites.
	for key in favorites:
		if not incoming.has(key):incoming[key]=favorites[key].duplicate()
	for probe in probes:probe.peer.close()
	probes.clear();rows=incoming;_probe_known();changed.emit()
	notice.emit("%d public servers. Checking status; gameplay reachability is confirmed when joining."%value.servers.size())

func _probe_known() -> void:
	queue.clear()
	for key in rows:
		rows[key].online=false;rows[key].erase("ping_ms");queue.append(key)
	changed.emit()

func cancel() -> void:
	if http:http.cancel_request()
	fetching=false;queue.clear()
	for probe in probes:probe.peer.close()
	probes.clear()

func _process(_delta: float) -> void:
	var now:=Time.get_ticks_msec()
	while probes.size()<8 and not queue.is_empty():
		var key: String=queue.pop_front()
		if not rows.has(key):continue
		var row: Dictionary=rows[key]
		var peer:=PacketPeerUDP.new()
		if peer.connect_to_host(row.address,int(row.query_port))!=OK:continue
		var nonce:=crypto.generate_random_bytes(16).hex_encode()
		var bytes:=Protocol.packet("hello",nonce)
		peer.put_packet(bytes)
		probes.append({"key":key,"peer":peer,"nonce":nonce,"stage":"challenge","packet":bytes,"sent":now,"retry":now+700,"expires":now+1600})
	var dirty:=false
	for probe in probes.duplicate():
		# A rendered frame can stall during shader compilation. Consume replies
		# already queued by the OS before declaring their request timed out.
		if now>=probe.expires and probe.peer.get_available_packet_count()==0:
			probe.peer.close();probes.erase(probe);dirty=true;continue
		if now>=probe.retry and now<probe.expires:
			probe.peer.put_packet(probe.packet);probe.retry=probe.expires
		for index in 4:
			if probe.peer.get_available_packet_count()==0:break
			var reply:=Protocol.decode(probe.peer.get_packet())
			if reply.get("nonce")!=probe.nonce or reply.get("kind")!=probe.stage:continue
			if probe.stage=="challenge":
				var cookie=reply.get("cookie")
				if not cookie is String or cookie.length()!=64 or not cookie.is_valid_hex_number(false):continue
				probe.stage="status";probe.sent=now;probe.retry=now+700;probe.expires=now+1600
				probe.packet=Protocol.packet("status",probe.nonce,cookie);probe.peer.put_packet(probe.packet)
			elif Protocol.valid_status(reply.get("status")) and rows.has(probe.key) and int(reply.status.game_port)==int(rows[probe.key].game_port):
				var row: Dictionary=rows[probe.key]
				# Keep only the validated fields; never replace the selected endpoint.
				for field in ["name","map","map_title","mode","weapon_rules","protocol","version","capacity","humans","spectators","bots","reserved","open_slots","state"]:row[field]=reply.status[field]
				row.online=true;row.ping_ms=maxi(1,now-int(probe.sent))
				probe.peer.close();probes.erase(probe);dirty=true;break
		if probes.has(probe) and now>=probe.expires:
			probe.peer.close();probes.erase(probe);dirty=true
	if dirty:changed.emit()

func _exit_tree() -> void:cancel()
