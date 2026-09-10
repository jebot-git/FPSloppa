extends Node3D
const RoomScale=preload("res://deathmatch/vr/room_scale.gd")
const W = preload("res://deathmatch/weapons.gd")
const Art = preload("res://deathmatch/art.gd")
const Fighter = preload("res://deathmatch/fighter.gd")
const Interface = preload("res://deathmatch/interface.gd")
const Profile = preload("res://deathmatch/profile.gd")
const HitDetection = preload("res://deathmatch/hit_detection.gd")
const PROTOCOL := "fpsloppa-17-lag-compensation"
const Melee=preload("res://deathmatch/melee.gd")
const MAX_PLAYERS := 8 # In-game hosts include the playing host.
const SERVER_MAX_PLAYERS := preload("res://deathmatch/server/config.gd").MAX_CLIENTS
const VRPoses=preload("res://deathmatch/vr/poses.gd")
const Maps = preload("res://deathmatch/maps/loader.gd")
var map_catalog: Array = Maps.catalog()
var selected_map := "lqdm1"
var current_map := ""
var map_rotation: Array=[]
var mode_maplists: Dictionary={}
var map_objectives: Dictionary={}
var tf_capture: Dictionary={}
var tf_resupply: Array=[[],[]]
var ctf_spawns: Array=[[],[]]
var map_uploads:=true
var uploads: Node
var rotation_index:=0
var map_epoch:=0
var map_loading:=false
var map_title := ""
var map_sha := ""
var spawn_points: Array = []
var spawn_yaws: Array = []
var fall_limit := -8.0
var pending_names: Dictionary = {}
var map_network: Node
var xr_rig
var effects
var avatars: Node
const COLORS = [Color("6dd5ed"),Color("f07866"),Color("b9da70"),Color("c79deb"),Color("ecc76a"),Color("f28fbd"),Color("8eb3ed"),Color("e7e4cf")]
var players: Dictionary = {}
var fighters: Dictionary = {}
var pickups: Array = []
var projectiles: Dictionary = {}
var projectile_id := 0
var gates: Array = []
var lifts: Array = []
var clock := 0.0
var snapshot_accumulator := 0.0
var input_accumulator := 0.0
var ping_accumulator := 0.0
var sequence := 0
var active := false
var dedicated := false
var server_name := "FPSloppa"
var bind_address := "*"
var max_clients := MAX_PLAYERS
var voice_backend:="builtin"
var mumble_url:=""
var voice_enabled := true
var voice
var permissions
var practice := false
var bots
var round_left := 600.0
var frag_limit := 20
var time_limit := 600.0
var intermission := 0.0
var round_message := ""
var nickname := "Marine"
var local_yaw := 0.0
var local_pitch := 0.0
var desired_weapon := 2
var fire_down := false
var camera_eye_height:=1.48
var camera: Camera3D
var viewmodel: Node3D
var model_weapon := -1
var recoil := 0.0
var visual_cooldown := 0.0
var offhand_visual_cooldown := 0.0
var offhand_recoil := 0.0
var offhand_viewmodel: Node3D
var predicted_offhand_shot_clock := -10.0
var melee_animation := 0.0
var hurt_flash := 0.0
var hit_flash := 0.0
var last_local_hp := 100
var hud
var menu_open := true
var feed: Array = []
var spatial
var sounds: Array = []
const LagCompensation=preload("res://deathmatch/lag_compensation.gd")
var history: Array = []
var remote_view_time:=-1.0
var snapshot_view_time:=-1.0
var projectile_watermark:=-1
var snapshot_projectiles: Array=[]
var ended_projectiles: Dictionary={}
var pending_joins: Dictionary = {}
var pending_spectators: Dictionary={}
var pending_teams: Dictionary={}
var server_log
var votes
var match_mode=preload("res://deathmatch/modes/match.gd").new()
var joining_as_spectator:=false
var presentation: Dictionary={}
var music: Node
const Presentation=preload("res://deathmatch/settings/preferences.gd")
var connect_deadline := 0.0
var local_ping := 0
var last_event := ""
var headless := false
var predicted_shot_clock := -10.0

var lobby
var demos
var bindings=preload("res://deathmatch/settings/bindings.gd").new()
func _ready() -> void:
	preload("res://deathmatch/assets/paths.gd").migrate_preferences()
	bindings.load_settings()
	demos=preload("res://deathmatch/demos/session.gd").new();demos.name="DemoSession";add_child(demos);demos.setup(self)
	lobby=preload("res://deathmatch/modes/lobby.gd").new();lobby.name="WaitingLobby";add_child(lobby);lobby.setup(self)
	headless = DisplayServer.get_name() == "headless"
	server_log=preload("res://deathmatch/server/log.gd").new();add_child(server_log)
	match_mode.setup(self)
	votes=preload("res://deathmatch/modes/votes.gd").new();votes.name="PlayerVotes";add_child(votes);votes.setup(self)
	nickname = Profile.load_name()
	presentation=Presentation.read_settings()
	permissions=preload("res://deathmatch/vr/permissions.gd").new()
	add_child(permissions)
	spatial=preload("res://deathmatch/audio/spatial.gd").new()
	add_child(spatial)
	spatial.setup(self)
	get_tree().root.gui_embed_subwindows = true
	# The server owns every RPC path; clients never need peer-to-peer relaying.
	(multiplayer as SceneMultiplayer).server_relay = false

	if not headless: get_viewport().msaa_3d = Viewport.MSAA_2X if OS.has_feature("android") else Viewport.MSAA_4X
	avatars = preload("res://deathmatch/avatars/network.gd").new()
	avatars.name = "AvatarNetwork"
	add_child(avatars)
	avatars.setup(self)
	map_network=preload("res://deathmatch/maps/network.gd").new()
	map_network.name="MapNetwork"
	add_child(map_network)
	map_network.setup(self)
	uploads=preload("res://deathmatch/maps/uploads.gd").new();uploads.name="MapUploads";add_child(uploads);uploads.setup(self)
	effects=preload("res://deathmatch/effects/combat.gd").new()
	effects.name="CombatEffects"
	add_child(effects)
	effects.setup(self)
	voice=preload("res://deathmatch/voice/chat.gd").new()
	voice.name="VoiceChat"
	add_child(voice)
	voice.setup(self)
	_load_map(selected_map)
	music=preload("res://deathmatch/audio/music/player.gd").new();add_child(music);music.setup(self)
	if not headless:
		for i in range(9): sounds.append(Art.sound(i))
		hud = Interface.new()
		add_child(hud)
		hud.setup(self)
		$Overview.make_current()
		xr_rig=load("res://deathmatch/vr/rig.gd").new()
		xr_rig.name="VRRig"
		add_child(xr_rig)
		xr_rig.setup(self,OS.get_cmdline_user_args().has("--vr-test"))
	Presentation.apply(self,presentation)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): disconnect_game("Connection failed. Check address and UDP port."))
	multiplayer.server_disconnected.connect(func(): disconnect_game("The host disconnected."))
	var args := OS.get_cmdline_user_args()
	if args.has("--frame-stats") and not headless: add_child(preload("res://deathmatch/performance/frame_stats.gd").new())
	selected_map = _arg_value(args,"--map",selected_map)
	if args.has("--import-map"):
		var imported: Dictionary=Maps.import_custom(_arg_value(args,"--import-map",""))
		print("MAP_IMPORT_RESULT ",JSON.stringify(imported))
		get_tree().quit(1 if imported.has("error") else 0)
		return
	if args.has("--check-assets"):
		var result: int=await preload("res://deathmatch/diagnostics.gd").check_assets(self)
		get_tree().quit(result)
		return
	if args.has("--demo"):
		demos.viewpoint=_arg_value(args,"--demo-view","first");demos.selected_player=_arg_int(args,"--demo-player",0)
		demos.exit_at_end=args.has("--demo-exit");demos.stop_at=float(_arg_value(args,"--demo-end","0")) if args.has("--demo-end") else INF
		if not demos.open_demo(_arg_value(args,"--demo","")):push_error(demos.message);get_tree().quit(2)
		else:demos.seek(float(_arg_value(args,"--demo-start","0")))
		return
	if args.has("--server") or OS.has_feature("dedicated_server"):
		_start_dedicated(args)
	elif args.has("--practice"):
		start_host(nickname,0,20,10,true,_arg_value(args,"--mode","dm"))
	elif args.has("--connect"):
		start_join(nickname,_arg_value(args,"--connect","127.0.0.1"),_arg_int(args,"--port",7777),args.has("--spectate"))

	if args.has("--record-demo"):
		demos.auto_path=_arg_value(args,"--record-demo","");demos.auto_record=true
		if active:demos.start_record(demos.auto_path)

func _start_dedicated(args: PackedStringArray) -> void:
	dedicated=true
	var config_path:=_arg_value(args,"--config",_arg_value(args,"+exec",""))
	if config_path.is_empty():
		config_path=OS.get_executable_path().get_base_dir().path_join("server.cfg") if OS.has_feature("dedicated_server") else "res://server.cfg"
	var result=preload("res://deathmatch/server/config.gd").read_config(config_path)
	if result.has("error"):
		push_error(result.error)
		get_tree().quit(2)
		return
	var settings: Dictionary=result.values
	lobby.enabled=settings.sv_lobby==1;lobby.seconds=settings.sv_lobby_seconds
	if not server_log.setup(self,settings):push_error(server_log.last_error);get_tree().quit(2);return
	server_name=settings.sv_hostname
	bind_address=settings.net_ip
	max_clients=settings.sv_maxclients
	if max_clients>16:push_warning(preload("res://deathmatch/server/config.gd").CAPACITY_WARNING)
	voice_backend=settings.sv_voice_backend if settings.sv_voice==1 else "builtin";mumble_url=settings.sv_mumble_url if settings.sv_voice==1 else ""
	voice_enabled=settings.sv_voice==1 and voice_backend=="builtin"
	map_uploads=settings.sv_map_uploads==1
	match_mode.configure(settings)
	votes.enabled=settings.sv_votes==1;votes.allowed_modes=settings.gametypes
	mode_maplists=settings.mode_maps.duplicate(true)
	for kind in match_mode.NAMES:
		var list_path: String=Maps.Paths.folder("maps")+kind+"_maplist.txt"
		if mode_maplists[kind].is_empty() and FileAccess.file_exists(list_path):
			for line in FileAccess.get_file_as_string(list_path).split("\n"):
				for name in line.split("#")[0].replace("\t"," ").strip_edges().split(" ",false):
					mode_maplists[kind].append(name)
		if mode_maplists[kind].is_empty():mode_maplists[kind]=settings.maps.duplicate()
		if mode_maplists[kind].size()>32:push_error(kind+" maplist exceeds 32 maps");get_tree().quit(2);return
		if kind in votes.allowed_modes:
			for map_id in mode_maplists[kind]:
				if not map_catalog.any(func(row):return row.id==map_id):push_error("Unknown map in "+kind+"_maplist: "+str(map_id));get_tree().quit(2);return
	map_rotation=mode_maplists[match_mode.kind].duplicate()
	if args.has("--map"): map_rotation=[_arg_value(args,"--map",settings.map)]
	for map_id in map_rotation:
		if not map_catalog.any(func(row): return row.id==map_id and FileAccess.file_exists(row.path)):
			push_error("Unknown or unavailable map in rotation: "+str(map_id));get_tree().quit(2);return
	rotation_index=0
	selected_map=map_rotation[0]
	start_host("Server",_arg_int(args,"--port",settings.net_port),_arg_int(args,"--frags",settings.fraglimit),_arg_int(args,"--minutes",settings.timelimit),false)
	if not active:
		get_tree().quit(2)
		return
	server_log.record("server_started",{"hostname":server_name,"bind":bind_address,"max_clients":max_clients,"protocol":PROTOCOL,"version":ProjectSettings.get_setting("application/config/version"),"rotation":map_rotation,"allowed_modes":votes.allowed_modes,"voice_backend":voice_backend,"friendly_fire":match_mode.friendly_fire,"score_limit":match_mode.limit()})
	print("SERVER_CONFIG name=",server_name," bind=",bind_address," maxclients=",max_clients," voice=",voice_enabled," map=",current_map," rotation=",map_rotation," gametype=",match_mode.kind," limit=",match_mode.limit()," friendlyfire=",match_mode.friendly_fire)

func _arg_value(args: PackedStringArray,key: String,fallback: String) -> String:
	var i := args.find(key)
	return args[i+1] if i>=0 and i+1<args.size() else fallback

func _arg_int(args: PackedStringArray,key: String,fallback: int) -> int:
	return int(_arg_value(args,key,str(fallback)))

func _pickup_art(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = p.position
	$Map.add_child(root)
	var color: Color = W.COLORS[p.item] if p.kind=="weapon" else Color("6fc7ec")
	if p.kind=="health": color = Color("52eff5") if p.item==100 else Color("f0746a")
	if p.kind=="armor": color = Color("f5c76b") if p.item==2 else Color("89db74")
	var base := Art.barrel(root,Vector3(0,.04,0),.46,.07,Art.material(Color("24343b"),.7))
	base.rotation = Vector3.ZERO
	var ring := TorusMesh.new()
	ring.inner_radius = .39
	ring.outer_radius = .44
	var glow := MeshInstance3D.new()
	glow.mesh = ring
	glow.material_override = Art.material(color,0,1.5)
	glow.position.y = .08
	root.add_child(glow)
	if powerful_pickup(p.kind,p.item):
		var halo:=MeshInstance3D.new();halo.name="PowerHalo";halo.mesh=ring
		halo.material_override=Art.material(color,0,1.2);halo.position.y=.40
		halo.scale=Vector3(.85,.4,.85);root.add_child(halo)
	var model: Node3D
	if p.kind=="weapon": model = Art.weapon(p.item)
	else: model=preload("res://deathmatch/pickups/models.gd").create(p.kind,p.item)
	root.add_child(model)
	model.name = "Display"
	model.position.y = .58
	var label := Label3D.new()
	label.text = W.DATA[p.item].name if p.kind=="weapon" else (W.AMMO_NAMES[p.item] if p.kind=="ammo" else p.kind.to_upper())
	if p.kind=="health" and p.item==100:label.text="MEGA HEALTH"
	if p.kind=="armor" and p.item==2:label.text="MEGA ARMOUR"
	label.position.y = 1.05
	label.font_size = 24
	label.pixel_size = .004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	root.add_child(label)
	return root

func start_host(player_name: String,port: int,frags: int,minutes: int,training: bool, mode: String="dm") -> void:
	if active: return
	if not dedicated: match_mode.configure({"sv_gametype":mode if match_mode.NAMES.has(mode) else "dm","capturelimit":clampi(frags,1,100),"hilllimit":clampi(frags,1,100)});votes.enabled=true;votes.allowed_modes=match_mode.NAMES.keys();voice_backend="builtin";mumble_url="";voice_enabled=true
	max_clients=clampi(max_clients,1,SERVER_MAX_PLAYERS) if dedicated else MAX_PLAYERS
	if not _load_map(selected_map):
		status("Could not load the selected map.")
		return
	match_mode.reset()
	nickname = clean_name(player_name)
	if training:
		multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	else:
		var peer:=ENetMultiplayerPeer.new()
		peer.set_bind_ip(bind_address)
		var err:=peer.create_server(clampi(port,1024,65535),max_clients)
		if err!=OK:
			status("Cannot host: UDP port is unavailable (%s)." % error_string(err))
			return
		multiplayer.multiplayer_peer=peer
	practice = training
	frag_limit = clampi(frags,1,100)
	time_limit = clampi(minutes,1,60)*60.0
	round_left = time_limit
	round_message = ""
	history.clear()
	remote_view_time=-1.0;snapshot_view_time=-1.0;projectile_watermark=-1;snapshot_projectiles.clear();ended_projectiles.clear()
	for pickup in pickups:
		pickup.available = not match_mode.kind in ["ig","cc"]
		pickup.respawn = 0
	for gate in gates:
		gate.open = false
		gate.node.position = gate.base_position if gate.has("base_position") else Vector3(gate.node.position.x,gate.base,gate.node.position.z)
	active = true
	if not dedicated: _add_player(1,nickname)
	if training:
		for id in [-1,-2,-3]: _add_player(id,"Bot "+str(-id))
		bots=preload("res://deathmatch/bots.gd").new()
		add_child(bots)
		bots.setup(self)
	menu_open = dedicated
	if hud: hud.show_menu(menu_open)
	if not dedicated and not headless: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("DM_HOST_READY port=",port," practice=",practice)

func start_join(player_name: String,address: String,port: int,spectator: bool=false) -> void:
	if active: return
	nickname = clean_name(player_name)
	joining_as_spectator=spectator
	if address.strip_edges().is_empty():
		status("Enter the host's IP address or hostname.")
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(),clampi(port,1024,65535))
	if err != OK:
		status("Could not create connection: "+error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	connect_deadline = clock+10
	status("Connecting to %s:%d…" % [address,port])

func clean_name(value: String) -> String:
	return Profile.clean(value)

func _connected() -> void:
	_hello.rpc_id(1,nickname,PROTOCOL,joining_as_spectator)

func _peer_connected(id: int) -> void:
	if multiplayer.is_server():
		pending_joins[id] = clock+8
		server_log.record("peer_connected",{"peer":id})

@rpc("any_peer","call_remote","reliable",0)
func _hello(player_name: String,version: String,spectator: bool=false) -> void:
	if not multiplayer.is_server() or not active: return
	var id := multiplayer.get_remote_sender_id()
	if id<=1 or players.has(id) or not pending_joins.has(id): return
	if version != PROTOCOL or players.size()>=max_clients or practice:
		server_log.record("join_rejected",{"peer":id,"reason":"protocol/private/full","client_protocol":version.left(80)})
		_rejected.rpc_id(id,"Version mismatch, private practice session, or server full.")
		return
	pending_names[id] = clean_name(player_name)
	pending_spectators[id]=spectator
	pending_joins[id] = clock+240
	map_network.offer(id)

@rpc("any_peer","call_remote","reliable",0)
func _map_ready(checksum: String) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not pending_names.has(id) or checksum!=map_sha: return
	if players.size()>=max_clients:
		_rejected.rpc_id(id,"Server filled while downloading map.")
		return
	var player_name: String = pending_names[id]
	pending_names.erase(id)
	pending_joins.erase(id)
	var spectator: bool=pending_spectators.get(id,false)
	pending_spectators.erase(id)
	_add_player(id,player_name,spectator)
	server_log.record("player_joined",{"peer":id,"name":player_name,"spectator":spectator,"team":players[id].team})
	avatars.sync_peer(id)
	voice.policy.rpc_id(id,voice_enabled,server_name,voice_backend,mumble_url)
	votes.offer(id)
	if dedicated and max_clients>16:_announcement.rpc_id(id,preload("res://deathmatch/server/config.gd").CAPACITY_WARNING)
	_announcement.rpc(player_name+(" joined as spectator." if spectator else " joined the arena."))

@rpc("authority","call_remote","reliable",0)
func _rejected(reason: String) -> void:
	disconnect_game(reason)

func _new_state(player_name: String,id: int) -> Dictionary:
	return {"name":clean_name(player_name),"spectator":false,"team":-1,"fly":0.0,"color":posmod(id,8),"hp":100,"armor":0,"tier":1,"ammo":[50,0,0,0],"owned":[2],"weapon":2,"kills":0,"deaths":0,"ping":0,"dead":false,"serial":0,"cooldown":0.0,"offhand_cooldown":0.0,"offhand_held":false,"offhand_fire":false,"charge":0.0,"invulnerable":0.0,"respawn_at":0.0,"last_input":clock,"last_seq":-1,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"held":false,"slow":false,"chat_at":0.0,"use_at":0.0,"want_respawn":false,"jump":false,"shots":0,"melee":false,"melee_state":{},"melee_seq":-1,"offhand_melee_state":{},"offhand_melee_seq":-1,"xr":{},"vr_device":false,"room":Vector3.ZERO}

func _create_fighter(id: int) -> void:
	var actor = Fighter.new()
	var team: int=players[id].team
	actor.setup(id,("["+match_mode.TEAMS[team]+"] " if team>=0 else "")+players[id].name,match_mode.COLORS[team] if team>=0 else COLORS[players[id].color])
	actor.quake_movement = true
	actor.spectator=players[id].spectator
	add_child(actor)
	fighters[id] = actor

func _add_player(id: int,player_name: String,spectator: bool=false) -> void:
	players[id] = _new_state(player_name,id)
	players[id].spectator=spectator
	var previous_team: int=pending_teams.get(id,-1)
	players[id].team=previous_team if previous_team>=0 and match_mode.team_game() and not spectator else match_mode.assign_team(spectator)
	pending_teams.erase(id)
	_create_fighter(id)
	_spawn(id)
	var defaults: Array = avatars.library.entries.keys()
	if not defaults.is_empty():
		var hash: String = defaults[posmod(id,mini(3,defaults.size()))]
		avatars.choices[id] = {"hash":hash,"size":avatars.library.entries[hash].size}
	_broadcast_roster()

func _broadcast_roster() -> void:
	var data: Array = []
	for id in players: data.append([id,players[id].name,players[id].color,fighters[id].position,players[id].yaw,players[id].spectator,players[id].team])
	_roster.rpc(data)

@rpc("authority","call_local","reliable",0)
func _roster(data: Array) -> void:
	if map_loading and not multiplayer.is_server(): return
	var keep: Array = []
	for row in data:
		var id: int = row[0]
		keep.append(id)
		if not players.has(id):
			players[id] = _new_state(row[1],id)
			players[id].color = row[2]
			players[id].spectator=row[5]
			players[id].dead=row[5]
			players[id].team=row[6] if row.size()>6 else -1
			_create_fighter(id)
			fighters[id].position = row[3]
			players[id].yaw = row[4]
			if id==multiplayer.get_unique_id(): local_yaw = row[4]
		if row.size()>6:
			players[id].team=row[6]
			var team: int=row[6]
			if fighters[id].label:
				fighters[id].label.text=("["+match_mode.TEAMS[team]+"] " if team>=0 else "")+players[id].name
				fighters[id].label.modulate=match_mode.COLORS[team].lightened(.2) if team>=0 else COLORS[players[id].color].lightened(.4)
	for id in players.keys():
		if not keep.has(id):
			fighters[id].queue_free()
			fighters.erase(id)
			players.erase(id)
	var mine := multiplayer.get_unique_id()
	if players.has(mine) and not camera and not headless and not is_vr():
		camera = Camera3D.new()
		camera.position.y = 1.48
		camera.near = .04
		camera.fov = presentation.fov
		fighters[mine].add_child(camera)
		camera.make_current()
		menu_open = false
		if hud: hud.show_menu(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if players.has(mine):
		if is_vr():
			camera=xr_rig.head
			camera.make_current()
			menu_open=false
			hud.show_menu(false)
		active = true
		connect_deadline = 0
		if headless: menu_open = false
	for id in fighters:
		fighters[id].show_alive(not players[id].dead,id==mine and not dedicated)
		if avatars.choices.has(id): avatars.queue_avatar(id)

func _peer_left(id: int) -> void:
	match_mode.fortress.departed(id)
	server_log.record("peer_disconnected",{"peer":id})
	avatars.remove_peer(id)
	pending_joins.erase(id)
	pending_names.erase(id)
	pending_spectators.erase(id)
	pending_teams.erase(id)
	if not multiplayer.is_server() or not players.has(id): return
	var player_name: String = players[id].name
	match_mode.drop(id)
	fighters[id].queue_free()
	fighters.erase(id)
	players.erase(id)
	_finish_departure.call_deferred(player_name)

func _finish_departure(player_name: String) -> void:
	if not active or not multiplayer.is_server(): return
	_broadcast_roster()
	_announcement.rpc(player_name+" left the arena.")

func disconnect_game(reason: String = "Disconnected.") -> void:
	if demos.recording:demos.stop_record()
	if demos.playing:demos.stop_playback()
	server_log.record("session_closed",{"reason":reason.left(256)})
	active = false
	voice_backend="builtin";mumble_url=""
	votes.reset();votes.cooldown=0
	avatars.reset()
	voice.reset()
	map_network.reset()
	if uploads:uploads.reset()
	map_epoch=0;map_loading=false;map_rotation.clear();mode_maplists.clear();rotation_index=0
	effects.clear()
	connect_deadline = 0
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for actor in fighters.values(): actor.queue_free()
	fighters.clear()
	players.clear()
	for projectile in projectiles.values():
		if is_instance_valid(projectile.node): projectile.node.queue_free()
	projectiles.clear();history.clear()
	remote_view_time=-1.0;snapshot_view_time=-1.0;projectile_watermark=-1;snapshot_projectiles.clear();ended_projectiles.clear()
	pending_joins.clear()
	pending_names.clear()
	pending_spectators.clear();pending_teams.clear();joining_as_spectator=false
	match_mode.configure({});match_mode.reset()
	camera = null
	viewmodel = null
	model_weapon = -1
	if is_instance_valid(bots): bots.free()
	bots=null
	practice = false
	menu_open = true
	intermission = 0
	hurt_flash=0
	camera_eye_height=1.48
	feed.clear()
	if not headless:
		if is_vr():
			camera=xr_rig.head
			camera.make_current()
		else: $Overview.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if hud: hud.show_menu(true)
	status(reason)

func status(message: String) -> void:
	last_event = message
	if hud: hud.status.text = message
	print(message)

func _spawn(id: int) -> void:
	var state: Dictionary = players[id]
	if state.spectator:
		state.dead=true;state.hp=0;state.ammo=[0,0,0,0];state.owned=[2];state.move=Vector2.ZERO;state.fly=0.0
		state.fire=false;state.offhand_fire=false;state.melee=false;state.want_respawn=false
		fighters[id].position=spawn_points[0]+Vector3.UP*2
		fighters[id].velocity=Vector3.ZERO;fighters[id].blast_velocity=Vector2.ZERO;fighters[id].reset_view();fighters[id].show_alive(false,id==multiplayer.get_unique_id())
		state.serial+=1
		return
	var best: Vector3 = spawn_points[0]
	var best_score := -1.0
	for point in match_mode.spawns(state.team):
		var distance := 100.0
		for other in fighters:
			if other != id and not players[other].dead: distance = minf(distance,point.distance_to(fighters[other].position))
		var score := distance+randf()*2
		if score>best_score:
			best = point
			best_score = score
	fighters[id].position = best
	fighters[id].velocity = Vector3.ZERO
	fighters[id].blast_velocity=Vector2.ZERO
	fighters[id].reset_view()
	fighters[id].gibbed=false
	state.merge({"hp":100,"armor":0,"tier":1,"ammo":[50,0,0,0],"owned":[2],"weapon":2,"dead":false,"melee":false,"melee_state":{},"melee_seq":-1,"offhand_melee_state":{},"offhand_melee_seq":-1,"cooldown":.3,"offhand_cooldown":.3,"offhand_held":false,"offhand_fire":false,"charge":0.0,"invulnerable":clock+1.5,"move":Vector2.ZERO,"fire":false,"held":false,"yaw":0.0,"pitch":0.0,"want_respawn":false},true)
	match_mode.special.spawn(id);match_mode.fortress.spawn(id)
	if not spawn_yaws.is_empty(): state.yaw = spawn_yaws[spawn_points.find(best)]
	if id==multiplayer.get_unique_id():
		desired_weapon=state.weapon
		local_yaw = state.yaw
		local_pitch = 0.0
	state.xr={}
	state.room=Vector3.ZERO
	if id==multiplayer.get_unique_id() and is_vr(): xr_rig.on_spawn()
	state.serial += 1
	server_log.record("spawn",{"peer":id,"team":state.team,"serial":state.serial},2)

func _unhandled_input(event: InputEvent) -> void:
	if demos.playing:return
	if is_vr(): return
	if not active or dedicated: return
	if event is InputEventMouseMotion and not menu_open and not (hud and hud.chat.has_focus()):
		local_yaw = wrapf(local_yaw-event.relative.x*.0022,-PI,PI)
		local_pitch = clampf(local_pitch-event.relative.y*.0022,-1.45,1.45)
	if not menu_open and not (hud and hud.chat.has_focus()):
		var owned: Array=local_state().get("owned",[2])
		if bindings.matches("next_weapon",event):desired_weapon=W.next_owned(desired_weapon,1,owned)
		if bindings.matches("previous_weapon",event):desired_weapon=W.next_owned(desired_weapon,-1,owned)
		if bindings.matches("use",event):
			if multiplayer.is_server():_use_for(1)
			else:_use_request.rpc_id(1)
		if bindings.matches("chat",event) and hud:hud.open_chat()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: fire_down = event.pressed and not menu_open
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			menu_open = not menu_open
			fire_down = false
			if hud: hud.show_menu(menu_open)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
		elif not menu_open:
			var owned: Array = local_state().get("owned",[2])
			var slots = {KEY_1:[0,1],KEY_2:[2],KEY_3:[3,4],KEY_4:[5],KEY_5:[6],KEY_6:[7],KEY_7:[8]}
			if slots.has(event.physical_keycode):
				var options: Array = slots[event.physical_keycode].filter(func(w): return owned.has(w))
				if not options.is_empty(): desired_weapon = options[(options.find(desired_weapon)+1)%options.size()]

func local_state() -> Dictionary:
	if demos and demos.playing:return players.get(demos.selected_player,{})
	return players.get(multiplayer.get_unique_id(),{}) if active else {}

func _local_command() -> Dictionary:
	if is_vr(): return xr_rig.command(sequence)
	var blocked: bool = menu_open or (hud != null and hud.chat.has_focus())
	var move := Vector2.ZERO if blocked else Vector2(float(bindings.pressed("right"))-float(bindings.pressed("left")),float(bindings.pressed("back"))-float(bindings.pressed("forward"))).limit_length(1)
	return {"seq":sequence,"move":move,"fly":0.0 if blocked else float(bindings.pressed("jump"))-float(bindings.pressed("down")),"yaw":local_yaw,"pitch":local_pitch,"fire":bindings.pressed("fire") and not blocked,"offhand_fire":not blocked and bindings.pressed("offhand_fire") and desired_weapon==2,"melee":not blocked and bindings.pressed("melee"),"weapon":desired_weapon,"slow":bindings.pressed("slow"),"jump":not blocked and bindings.pressed("jump"),"respawn":not blocked and (bindings.pressed("fire") or bindings.pressed("jump"))}

@rpc("any_peer","call_remote","unreliable_ordered",2)
func _input_command(command: Dictionary) -> void:
	if multiplayer.is_server() and command.get("map_epoch",-1)==map_epoch: _accept_input(multiplayer.get_remote_sender_id(),command)

func _accept_input(id: int,command: Dictionary) -> void:
	server_log.count("input_received")
	if not players.has(id) or not active: return
	for field in ["seq","move","yaw","pitch","fire","weapon","slow","respawn"]:
		if not command.has(field): return
	if not command.move is Vector2 or not command.move.is_finite(): return
	if not (command.yaw is float or command.yaw is int) or not is_finite(float(command.yaw)): return
	if not (command.pitch is float or command.pitch is int) or not is_finite(float(command.pitch)): return
	if not command.seq is int or not command.weapon is int: return
	if not command.fire is bool or not command.slow is bool or not command.respawn is bool: return
	var s: Dictionary = players[id]
	if command.seq<=s.last_seq: return
	server_log.count("input_accepted")
	s.last_seq = command.seq
	s.last_input = clock
	var view=command.get("view_time",-1.0)
	s.view_time=float(view) if (view is float or view is int) and is_finite(float(view)) else -1.0
	if match_mode.special.blocked(id):
		s.move=Vector2.ZERO;s.room=Vector3.ZERO;s.fire=false;s.offhand_fire=false;s.melee=false;s.jump=false
		return
	s.move = command.move.limit_length(1.0)
	s.fly=preload("res://deathmatch/vr/preferences.gd").bounded(command.get("fly",0.0),-1,1,0)
	s.yaw = wrapf(command.yaw,-PI,PI)
	s.pitch = clampf(command.pitch,-1.45,1.45)
	s.fire = command.fire
	s.offhand_fire = command.get("offhand_fire",false)==true
	s.melee = command.get("melee",false)==true
	s.slow = command.slow
	s.want_respawn = command.respawn
	s.jump = command.get("jump",false)==true
	s.vr_device=command.has("xr")
	s.xr=VRPoses.validate(command.get("xr",{}))
	s.room=RoomScale.validate(command.get("room"),s.xr)
	if command.has("xr") and s.xr.is_empty(): s.fire=false;s.melee=false
	if s.spectator:s.fire=false;s.offhand_fire=false;s.melee=false;s.want_respawn=false
	if s.vr_device and not s.xr.has("offhand_weapon"): s.offhand_fire=false
	if s.owned.has(command.weapon) and command.weapon!=s.weapon and s.charge<=0:
		s.weapon = command.weapon
		s.cooldown = maxf(s.cooldown,.28)
		s.offhand_cooldown=maxf(s.offhand_cooldown,.28)
		s.offhand_held=false
		s.held = false

func _physics_process(delta: float) -> void:
	if demos.playing:demos.tick(delta);return
	clock += delta
	if connect_deadline>0 and clock>connect_deadline: disconnect_game("Connection timed out. Check host, firewall and UDP port forwarding.")
	if not active: return
	var mine := multiplayer.get_unique_id()
	if players.has(mine) and not dedicated:
		sequence += 1
		var command := _local_command()
		command.map_epoch=map_epoch
		command.view_time=remote_view_time
		if multiplayer.is_server(): _accept_input(mine,command)
		else:
			input_accumulator += delta
			if input_accumulator>=1.0/30:
				input_accumulator = 0
				_input_command.rpc_id(1,command)
			if players[mine].spectator and intermission<=0:
				_move_spectator(mine,command.move,command.fly,command.yaw,command.slow,delta)
			if not players[mine].dead and not match_mode.special.blocked(mine) and intermission<=0:
				var room:=RoomScale.validate(command.get("room"),command.get("xr",{}))
				var speed: float=(5.2 if command.slow else 9.4)*(1.0 if lobby.active() else match_mode.fortress.speed(mine))
				fighters[mine].speed_multiplier=1.0 if lobby.active() else match_mode.fortress.speed(mine)
				fighters[mine].simulate(command.move*(1.0-minf(room.length()*30/speed,1.0)),local_yaw,command.slow,delta,command.get("jump",false))
				if is_vr():
					var actual:=RoomScale.move_capsule(fighters[mine],room,local_yaw,delta)
					xr_rig.compensate_room_move(actual)
			var predicted_bullets: int=players[mine].ammo[0]
			for offhand in [false,true]:
				var pressed: bool=command.get("offhand_fire",false) if offhand else command.fire
				var weapon: int=players[mine].weapon
				var ready: bool=(offhand_visual_cooldown if offhand else visual_cooldown)<=0
				if headless or not pressed or players[mine].dead or match_mode.special.blocked(mine) or intermission>0 or lobby.active() or not ready or not match_mode.fortress.can_fire(mine,weapon): continue
				if offhand and weapon!=2: continue
				if weapon==2 and predicted_bullets<=0: continue
				if offhand: predicted_offhand_shot_clock=clock
				else: predicted_shot_clock=clock
				_play_shot_fx(mine,weapon,offhand)
				if weapon==2: predicted_bullets-=1

	if multiplayer.is_server():
		_server_tick(delta)
		_record_history()
		snapshot_accumulator += delta
		if snapshot_accumulator>=.05:
			snapshot_accumulator = 0
			_send_snapshot()
	else:
		_interpolate_remote_players(delta)
	ping_accumulator += delta
	if ping_accumulator>1 and not multiplayer.is_server():
		ping_accumulator = 0
		_ping.rpc_id(1,Time.get_ticks_msec())
	for lift in lifts:
		var phase := fmod(time_limit-round_left,10.0)
		lift.node.position.y = lift.base + clampf((phase-2)/2,0,1)*float(lift.get("travel",1.65)) if phase<6 else lift.base+clampf((10-phase)/2,0,1)*float(lift.get("travel",1.65))

func _interpolate_remote_players(delta: float) -> void:
	var mine:=multiplayer.get_unique_id()
	if snapshot_view_time>=0:remote_view_time=lerpf(remote_view_time,snapshot_view_time,minf(delta*16,1)) if remote_view_time>=0 else snapshot_view_time
	for id in fighters:
		if id==mine: continue
		fighters[id].position = fighters[id].position.lerp(fighters[id].target,minf(delta*16,1))
		fighters[id].rotation.y = lerp_angle(fighters[id].rotation.y,fighters[id].target_yaw,minf(delta*16,1))

func _move_spectator(id: int,move: Vector2,vertical: float,yaw: float,slow: bool,delta: float) -> void:
	var direction: Vector3=(Basis(Vector3.UP,yaw)*Vector3(move.x,0,move.y)+Vector3.UP*vertical).limit_length(1)
	fighters[id].position+=direction*(3.0 if slow else 7.0)*delta
	fighters[id].velocity=Vector3.ZERO

func _server_tick(delta: float) -> void:
	votes.tick()
	for id in pending_joins.keys():
		if clock>pending_joins[id]:
			server_log.record("join_timeout",{"peer":id})
			multiplayer.multiplayer_peer.disconnect_peer(id)
			pending_joins.erase(id)
			pending_names.erase(id)
			pending_spectators.erase(id)
			map_network.outgoing.erase(id)
	if map_loading:
		if not pending_names.is_empty(): return
		map_loading=false
		_announcement.rpc("New map · "+map_title)
	if lobby.active():
		lobby.tick(delta)
		return
	if intermission>0:
		intermission -= delta
		if intermission<=0:
			if lobby.enabled and not practice:lobby.begin()
			else:_restart_round()
		return
	round_left = maxf(0,round_left-delta)
	if round_left<=0:
		_end_round()
		return
	if practice and is_instance_valid(bots): bots.tick(delta)
	var movement_start: Dictionary = {}
	for id in fighters:
		movement_start[id]={"position":fighters[id].position,"serial":players[id].serial}
	for id in players:
		var s: Dictionary = players[id]
		if s.spectator:
			if clock-s.last_input>.35:s.move=Vector2.ZERO;s.fly=0.0
			_move_spectator(id,s.move,s.fly,s.yaw,s.slow,delta)
			continue
		if match_mode.special.blocked(id):continue
		if s.dead:
			if clock>=s.respawn_at and (s.want_respawn or clock>s.respawn_at+3 or id<0): _spawn(id)
			continue
		if clock-s.last_input>.35:
			s.move = Vector2.ZERO
			s.room=Vector3.ZERO
			s.fire = false
			s.offhand_fire=false
			s.melee = false
		fighters[id].speed_multiplier=match_mode.fortress.speed(id)
		fighters[id].simulate(s.move*(1.0-minf(s.room.length()*30/((5.2 if s.slow else 9.4)*fighters[id].speed_multiplier),1.0)),s.yaw,s.slow,delta,s.jump)
		if not s.xr.is_empty():
			var shift:=RoomScale.move_capsule(fighters[id],s.room,s.yaw,delta)
			s.room-=shift
			RoomScale.rebase_pose(s.xr,shift)
			if id==multiplayer.get_unique_id() and is_vr(): xr_rig.compensate_room_move(shift)
		if fighters[id].position.y < fall_limit:
			_damage(id,id,1000,"fell out of the arena",true)
			continue
		s.cooldown = maxf(0,s.cooldown-delta)
		s.offhand_cooldown=maxf(0,s.offhand_cooldown-delta)
		if s.charge>0:
			s.charge -= delta
			if s.charge<=0: _launch(id,8)
		_update_melee(id)
		if s.fire and s.cooldown<=0: _fire(id)
		if s.weapon==2 and s.offhand_fire and s.offhand_cooldown<=0: _fire(id,true)
		if not s.offhand_fire: s.offhand_held=false
		if not s.fire: s.held = false
		_collect(id)
	_update_projectiles(delta,movement_start)
	match_mode.tick(delta)
	_respawn_pickups()
	for gate in gates:
		if gate.open and clock>gate.until:
			var clear := true
			for actor in fighters.values():
				if actor.spectator:continue
				var offset: Vector3 = actor.position-gate.get("center",gate.node.position)
				offset.y = 0
				if offset.length()<1.3: clear = false
			if clear:
				gate.open = false
				_gate_state.rpc(gates.find(gate),false)

func _collect(id: int) -> void:
	if lobby.active():return
	if match_mode.kind in ["ig","cc"] or match_mode.special.blocked(id):return
	var s: Dictionary = players[id]
	if s.spectator:return
	for p in pickups:
		if not p.available or fighters[id].position.distance_to(p.position) > .85: continue
		if match_mode.kind=="tf" and p.kind=="weapon":continue
		var took := false
		match p.kind:
			"weapon":
				var ammo_type: int = W.DATA[p.item].ammo
				if not s.owned.has(p.item):
					s.owned.append(p.item)
					s.weapon = p.item
					s.cooldown = maxf(s.cooldown,.25)
					s.offhand_cooldown=maxf(s.offhand_cooldown,.25)
					took = true
				if ammo_type>=0 and s.ammo[ammo_type]<W.MAX_AMMO[ammo_type]:
					s.ammo[ammo_type] = mini(W.MAX_AMMO[ammo_type],s.ammo[ammo_type]+[20,8,2,40][ammo_type])
					took = true
			"ammo":
				if s.ammo[p.item]<W.MAX_AMMO[p.item]:
					s.ammo[p.item] = mini(W.MAX_AMMO[p.item],s.ammo[p.item]+[50,20,5,100][p.item])
					took = true
			"health":
				var maximum: int=match_mode.fortress.max_health(id) if match_mode.kind=="tf" else 200 if p.item==100 else 100
				if s.hp<maximum:
					s.hp = mini(maximum,s.hp+p.item)
					took = true
			"bonus":
				if s.hp<(match_mode.fortress.max_health(id) if match_mode.kind=="tf" else 200):
					s.hp += 1
					took = true
			"armor":
				if s.armor < p.item*100:
					s.armor = p.item*100
					s.tier = p.item
					took = true
		if took:
			p.available = false
			p.respawn = clock+(60 if p.kind=="weapon" and p.item==8 else 30)
			server_log.record("pickup",{"peer":id,"kind":p.kind,"item":p.item},2)
			_pickup_event.rpc(id,p.kind,p.item,s.weapon)

func _respawn_pickups() -> void:
	if match_mode.kind in ["ig","cc"]:return
	if not multiplayer.is_server():return
	for pickup in pickups:
		if not pickup.available and clock>=pickup.respawn:
			pickup.available = not match_mode.kind in ["ig","cc"]
			if powerful_pickup(pickup.kind,pickup.item):_power_spawn.rpc(pickup.position)

static func powerful_pickup(kind: String,item: int) -> bool:
	return (kind=="health" and item==100) or (kind=="armor" and item==2) or (kind=="weapon" and item==8)

static func pickup_sound(kind: String,item: int) -> String:
	if powerful_pickup(kind,item):return "pickup_mega"
	return "pickup_"+kind if kind in ["health","armor","ammo","weapon"] else "pickup_health"

@rpc("authority","call_local","reliable",0)
func _power_spawn(where: Vector3) -> void:
	if not headless:effects.play("power_spawn",where,-5)

@rpc("authority","call_local","reliable",0)
func _pickup_event(id: int,kind: String,item: int,weapon: int) -> void:
	if fighters.has(id): effects.play(pickup_sound(kind,item),fighters[id].position,-8)
	if id==multiplayer.get_unique_id():
		desired_weapon = weapon
		last_event = (W.DATA[item].name if kind=="weapon" else kind.to_upper())+" acquired"
		if hud: hud.toast(last_event)

func _update_melee(id: int) -> void:
	if lobby.active():return
	if match_mode.kind in ["ig","cc"] or match_mode.special.blocked(id):return
	_update_melee_hand(id,false)
	_update_melee_hand(id,true)

func _update_melee_hand(id: int,offhand: bool) -> void:
	if match_mode.kind in ["ig","cc"] or match_mode.special.blocked(id):return
	var s: Dictionary=players[id]
	var state: Dictionary=s.offhand_melee_state if offhand else s.melee_state
	var other: Dictionary=s.melee_state if offhand else s.offhand_melee_state
	if other.has("ready_at"): state.ready_at=maxf(state.get("ready_at",0.0),other.ready_at)
	if offhand and (not s.vr_device or s.weapon!=2 or not s.xr.has("offhand_weapon")):
		Melee.reset_motion(state);return
	if not multiplayer.is_server() or not s.melee or s.dead or intermission>0 or clock-s.last_input>.35 or s.charge>0:
		Melee.reset_motion(state)
		return
	var segments: Array=[]
	var started:=false
	var frame:=Transform3D.IDENTITY
	if s.vr_device:
		if s.xr.is_empty(): Melee.reset_motion(state);return
		var seq_key:="offhand_melee_seq" if offhand else "melee_seq"
		if s[seq_key]==s.last_seq: return
		s[seq_key]=s.last_seq
		var pose: Dictionary=s.xr.duplicate()
		if offhand: pose.weapon=pose.offhand_weapon;pose.left_handed=not pose.left_handed
		var swing:=Melee.sample(state,pose,clock,s.weapon)
		if swing.is_empty(): return
		started=swing.started;segments=swing.segments
		frame=Transform3D(Basis(Vector3.UP,s.yaw),fighters[id].position)*Transform3D(Basis.IDENTITY,s.xr.head.origin)
	else:
		if clock<state.get("ready_at",0.0): return
		state.ready_at=clock+Melee.COOLDOWN;state.hit=false;started=true
		var weapon:=_weapon_transform(id)
		segments.append([weapon.origin,weapon*Vector3(0,0,-Melee.DESKTOP_REACH)])
	if started:
		match_mode.fortress.revealed(id)
		other.swing_until=0.0
		s.invulnerable=0
		s.cooldown=maxf(s.cooldown,.3)
		s.offhand_cooldown=maxf(s.offhand_cooldown,.3)
		_melee_fx.rpc(id,offhand)
	var body: Vector3=fighters[id].position+Vector3.UP*1.25
	for segment in segments:
		var start: Vector3=frame*segment[0]
		var end: Vector3=frame*segment[1]
		if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body,start,1)).is_empty(): continue
		var hit:=_trace(start,end,id,0,Melee.RADIUS)
		if hit.id==0: continue
		if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body,hit.position,1)).is_empty(): continue
		state.hit=true
		_damage(hit.id,id,Melee.DAMAGE,"WEAPON WHIP",false,hit.position,(end-start).normalized())
		return

func _fire(id: int, offhand: bool=false) -> void:
	if lobby.active():return
	if match_mode.special.blocked(id):return
	if not multiplayer.is_server() or not players.has(id) or players[id].dead or intermission>0: return
	if offhand and (players[id].weapon!=2 or (players[id].vr_device and not players[id].xr.has("offhand_weapon"))): return
	if _weapon_blocked(id,offhand): return
	var s: Dictionary = players[id]
	var w: int = s.weapon
	if (s.offhand_cooldown if offhand else s.cooldown)>0: return
	if not match_mode.fortress.can_fire(id,w):
		for choice in [7,4,5,3,2,1,0]:
			if s.owned.has(choice) and W.can_fire(choice,s.ammo):
				s.weapon = choice
				_pickup_event.rpc(id,"weapon",choice,choice)
				break
		return
	var d: Dictionary = match_mode.fortress.weapon_data(id,w)
	if d.ammo>=0: s.ammo[d.ammo] -= d.cost
	if offhand: s.offhand_cooldown=d.cycle
	else: s.cooldown = d.cycle
	match_mode.fortress.revealed(id)
	s.invulnerable = 0
	s.shots += 1
	_shot_fx.rpc(id,w,offhand)
	if w==8:
		s.charge = d.charge
	elif w>=6 and w<=8 and not (match_mode.kind=="tf" and s.get("tf_class","")=="pyro" and w==7):
		_launch(id,w)
	else:
		var start: Vector3 = _shot_origin(id,offhand)
		var endpoints := PackedVector3Array()
		if w==9:
			var end: Vector3=start-_weapon_transform(id).basis.z*d.range
			var wall:=HitDetection.world_fraction(get_world_3d().direct_space_state,start,end,0.0)
			end=start.lerp(end,minf(1.0,wall))
			var rewound:=_rewound_positions(_shot_rewind(id))
			for target in players:
				if target==id or players[target].dead or players[target].spectator:continue
				var target_pos: Vector3=rewound.get(target,fighters[target].position)
				var fraction:=HitDetection.capsule_fraction(start-target_pos,end-target_pos,HitDetection.PLAYER_RADIUS)
				if fraction<=1.0:
					var impact:=start.lerp(end,fraction)
					var axis:=target_pos+Vector3.UP*clampf(impact.y-target_pos.y,HitDetection.PLAYER_BOTTOM,HitDetection.PLAYER_TOP)
					if get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(impact,axis,1)).is_empty():
						_damage(target,id,d.damage,"RAILGUN",false,impact,(end-start).normalized())
			var structure: Dictionary=match_mode.fortress.trace(start,end,1.0)
			if not structure.is_empty():match_mode.fortress.damage_building(structure.key,id,d.damage)
			_impacts.rpc(start,PackedVector3Array([end]),w)
			s.held=true
			return
		for pellet in range(d.pellets):
			var spread: float = 0.0 if (w==2 or w==5) and not (s.offhand_held if offhand else s.held) else d.spread
			var yaw: float = s.yaw+deg_to_rad((randf()-randf())*spread)
			var pitch: float = s.pitch+deg_to_rad((randf()-randf())*d.vertical)
			var direction := W.direction(yaw,pitch)
			if not s.xr.is_empty():
				direction=_weapon_transform(id,offhand).basis*W.direction(yaw-s.yaw,pitch-s.pitch)
			var hit := _trace(start,start+direction*d.range,id,_shot_rewind(id))
			endpoints.append(hit.position)
			var amount: int=d.damage*randi_range(1,d.dice)
			if hit.id!=0:
				_damage(hit.id,id,amount,d.name,false,hit.position,direction)
				if d.name=="FLAMETHROWER":match_mode.fortress.ignite(hit.id,id)
			if hit.has("building"):match_mode.fortress.damage_building(hit.building,id,amount)
		_impacts.rpc(start,endpoints,w)
	if offhand: s.offhand_held=true
	else: s.held = true

func _trace(start: Vector3,end: Vector3,exclude: int,rewind: float = 0.0,radius: float = 0.0,movement_start: Dictionary = {}) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var wall_fraction := HitDetection.world_fraction(space,start,end,radius)
	var nearest := wall_fraction
	var point := start.lerp(end,minf(1.0,nearest))
	var target := 0
	var old:=_rewound_positions(rewind)
	for id in players:
		if id==exclude or players[id].dead or players[id].spectator: continue
		var position: Vector3 = old.get(id,fighters[id].position)
		var previous: Vector3 = position
		if movement_start.has(id) and movement_start[id].serial==players[id].serial:
			previous=movement_start[id].position
		# Relative motion catches targets crossing the projectile between ticks.
		var fraction := HitDetection.capsule_fraction(start-previous,end-position,HitDetection.PLAYER_RADIUS+radius)
		if fraction<nearest:
			var impact := start.lerp(end,fraction)
			var target_at := previous.lerp(position,fraction)
			var axis := target_at+Vector3.UP*clampf(impact.y-target_at.y,HitDetection.PLAYER_BOTTOM,HitDetection.PLAYER_TOP)
			# Expanded damage volumes must not reach through thin walls/corners.
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(impact,axis,1)).is_empty(): continue
			nearest=fraction
			point=impact
			target=id
	var structure: Dictionary=match_mode.fortress.trace(start,end,nearest,radius)
	if not structure.is_empty():return {"id":0,"building":structure.key,"position":start.lerp(end,structure.fraction),"hit":true}
	return {"id":target,"position":point,"hit":target!=0 or is_finite(wall_fraction)}

func _launch(id: int,weapon: int) -> void:
	if not players.has(id) or players[id].dead: return
	if _weapon_blocked(id) or (players[id].vr_device and players[id].xr.is_empty()): return
	var s: Dictionary = players[id]
	var start: Vector3 = _shot_origin(id)
	var direction := -_weapon_transform(id).basis.z
	var shot_yaw:=atan2(-direction.x,-direction.z)
	var shot_pitch:=asin(clampf(direction.y,-1,1))
	projectile_id += 1
	_projectile_spawn.rpc(projectile_id,id,weapon,start,direction,shot_yaw,shot_pitch)

@rpc("authority","call_local","reliable",0)
func _projectile_spawn(id: int,owner_id: int,weapon: int,pos: Vector3,direction: Vector3,yaw: float,pitch: float) -> void:
	if projectiles.has(id):return
	if not multiplayer.is_server() and (ended_projectiles.has(id) or (id<=projectile_watermark and not id in snapshot_projectiles)):return
	var node: Node3D = null
	if not headless:
		node = Node3D.new()
		add_child(node)
		node.position = pos
		var ball := SphereMesh.new()
		ball.radius = W.DATA[weapon].radius
		ball.height = ball.radius*2
		var mesh := MeshInstance3D.new()
		mesh.mesh = ball
		mesh.material_override = Art.material(W.COLORS[weapon],0,3)
		node.add_child(mesh)
	projectiles[id] = {"owner":owner_id,"weapon":weapon,"position":pos,"direction":direction,"life":4.0,"node":node,"yaw":yaw,"pitch":pitch,"fresh":true,"visual_error":Vector3.ZERO,"visual_age":0.0}

func _update_projectiles(delta: float,movement_start: Dictionary = {}) -> void:
	for id in projectiles.keys():
		var p: Dictionary = projectiles[id]
		p.life -= delta
		var end: Vector3 = p.position+p.direction*W.DATA[p.weapon].speed*delta
		# New shots originate after this tick's movement: do not hit a past crossing.
		var hit := _trace(p.position,end,p.owner,0.0,W.DATA[p.weapon].radius,{} if p.fresh else movement_start)
		p.fresh=false
		if hit.hit or p.life<=0:
			var d: Dictionary = W.DATA[p.weapon]
			if hit.id!=0: _damage(hit.id,p.owner,d.damage*randi_range(1,d.dice),d.name,false,hit.position,p.direction)
			if hit.has("building"):match_mode.fortress.damage_building(hit.building,p.owner,d.damage*randi_range(1,d.dice))
			if p.weapon==6: _blast(hit.position,p.owner,128,5.76)
			if p.weapon==8 and players.has(p.owner):
				var origin: Vector3 = fighters[p.owner].position+Vector3.UP*1.45
				for ray in range(40):
					var dir := W.direction(p.yaw+deg_to_rad(-45+90.0*ray/39),p.pitch)
					var target := _trace(origin,origin+dir*46,p.owner)
					if target.id!=0:
						var damage := 0
						for die in range(15): damage += randi_range(1,8)
						_damage(target.id,p.owner,damage,"BFG 9000")
			_projectile_end.rpc(id,hit.position,p.weapon)
		else: p.position = end

func _blast(pos: Vector3,owner_id: int,damage: int,radius: float) -> void:
	if lobby.active():return
	if not multiplayer.is_server() or intermission>0:return
	match_mode.fortress.blast(pos,owner_id,damage,radius)
	for id in players:
		if players[id].dead or players[id].spectator or players[id].invulnerable>clock: continue
		if id!=owner_id and match_mode.same_team(id,owner_id) and not match_mode.friendly_fire:continue
		var target: Vector3 = fighters[id].position+Vector3.UP*.85
		var distance := maxf(0,pos.distance_to(target)-.3)
		if distance>=radius: continue
		var query := PhysicsRayQueryParameters3D.create(pos+(target-pos).normalized()*.06,target,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var falloff:=1.0-distance/radius
		var push:Vector3=(target-pos).normalized()
		if push.length_squared()<.01:push=Vector3.UP
		fighters[id].apply_blast(push*15.0*falloff)
		# Self splash costs health but permits a healthy player to rocket jump.
		_damage(id,owner_id,maxi(1,int(damage*falloff*(.5 if id==owner_id else 1.0))),"ROCKET LAUNCHER",false,target,push)

func _damage(victim: int,attacker: int,amount: int,weapon_name: String,bypass: bool = false,impact: Vector3=Vector3.INF,direction: Vector3=Vector3.ZERO) -> void:
	if lobby.active():return
	if not multiplayer.is_server() or not players.has(victim): return
	var s: Dictionary = players[victim]
	if s.spectator or s.dead or match_mode.special.blocked(victim) or intermission>0 or (s.invulnerable>clock and not bypass): return
	if attacker!=victim and match_mode.same_team(victim,attacker) and not match_mode.friendly_fire: return
	amount=match_mode.fortress.outgoing_damage(attacker,victim,amount,weapon_name)
	amount=match_mode.fortress.incoming_damage(victim,amount,weapon_name,bypass)
	var damage := Vector2i(amount,s.armor) if match_mode.kind=="ig" or weapon_name=="CIRCUS HUNGER" else W.armor_damage(amount,s.armor,s.tier)
	var old_hp: int=s.hp
	s.hp = maxi(0,s.hp-damage.x)
	s.armor = damage.y
	match_mode.special.heal(attacker,victim,old_hp-s.hp,weapon_name)
	if s.hp==0 and match_mode.kind=="ft" and not bypass:
		if attacker!=victim and players.has(attacker):_hit_confirm.rpc(attacker)
		_hurt_fx.rpc(victim,fighters[victim].position+Vector3.UP,direction,damage.x,false,false,randi())
		match_mode.special.freeze(victim,attacker)
		return
	if attacker!=victim and players.has(attacker): _hit_confirm.rpc(attacker)
	if not impact.is_finite(): impact=fighters[victim].position+Vector3.UP
	if direction.length()<.1 and fighters.has(attacker): direction=(fighters[victim].position-fighters[attacker].position).normalized()
	server_log.record("damage",{"victim":victim,"attacker":attacker,"damage":damage.x,"remaining_hp":s.hp,"remaining_armor":s.armor,"weapon":weapon_name,"fatal":s.hp==0},2)
	var gibbed: bool=s.hp==0 and (damage.x-old_hp>=25 or weapon_name in ["ROCKET LAUNCHER","BFG 9000"])
	_hurt_fx.rpc(victim,impact,direction,damage.x,s.hp==0,gibbed,randi())
	if s.hp>0: return
	s.dead = true
	s.deaths += 1
	s.fire = false
	s.charge = 0
	s.respawn_at = clock+2
	var killer: String = s.name
	if players.has(attacker):
		killer = players[attacker].name
	match_mode.killed(victim,attacker)
	_announcement.rpc("%s  →  %s   ·   %s" % [killer,s.name,weapon_name])

func _end_round() -> void:
	if intermission>0:return
	intermission = 10
	var winner := "No winner"
	var score := -999
	for s in players.values():
		if s.spectator:continue
		if s.kills>score:
			score = s.kills
			winner = s.name
	round_message = "%s wins · %d frags" % [winner,score] if score>-999 else "Round ended · no active players"
	if match_mode.team_game():round_message=match_mode.result()
	server_log.record("round_ended",{"result":round_message,"team_scores":match_mode.scores})
	_announcement.rpc(round_message)

func _restart_round() -> void:
	intermission=0
	if map_rotation.size()>1:
		var next_index: int=(rotation_index+1)%map_rotation.size()
		if map_rotation[next_index]!=current_map:
			if _rotate_map(map_rotation[next_index]): rotation_index=next_index;return
		else: rotation_index=next_index
	match_mode.reset()
	round_left = time_limit
	round_message = ""
	for id in players:
		players[id].kills = 0
		players[id].deaths = 0
		_spawn(id)
	for p in pickups: p.available = not match_mode.kind in ["ig","cc"]
	for id in projectiles.keys(): _projectile_end.rpc(id,projectiles[id].position,7)
	history.clear()
	remote_view_time=-1.0;snapshot_view_time=-1.0;projectile_watermark=-1;snapshot_projectiles.clear();ended_projectiles.clear()
	_announcement.rpc("New round · "+match_mode.status())

func _history_positions() -> Dictionary:
	var positions: Dictionary={}
	for id in players:positions[id]={"position":fighters[id].position,"serial":players[id].serial}
	return positions
func _record_history() -> void:
	history.append({"time":clock,"positions":_history_positions()})
	while history.size()>2 and history[1].time<clock-LagCompensation.MAX_REWIND-.05:history.pop_front()
func _rewound_positions(rewind: float) -> Dictionary:
	return LagCompensation.positions(history,clock,rewind,_history_positions())
func _shot_rewind(id: int) -> float:
	if id<=1:return 0.0 # Local host and bots see the authoritative world.
	var s: Dictionary=players[id]
	return LagCompensation.delay(clock,s.ping,s.get("view_time",-1.0),s.last_input)

func _send_snapshot() -> void:
	var data: Array = []
	for id in players:
		var s: Dictionary = players[id]
		data.append([id,fighters[id].position,fighters[id].velocity,s.yaw,s.pitch,s.hp,s.armor,s.dead,s.weapon,s.ammo,s.owned,s.kills,s.deaths,s.ping,s.serial,maxf(0,s.respawn_at-clock),s.invulnerable>clock,s.cooldown,s.xr,s.offhand_cooldown,s.spectator,fighters[id].blast_velocity])
	var items := PackedByteArray()
	for p in pickups: items.append(1 if p.available else 0)
	var shots: Array = []
	for id in projectiles:
		var p: Dictionary = projectiles[id]
		shots.append([id,p.position,p.owner,p.weapon,p.direction,p.yaw,p.pitch])
	var gate_states: Array = []
	for gate in gates: gate_states.append(gate.open)
	var mode_state: Dictionary=match_mode.snapshot();mode_state["lobby"]={"seconds":maxi(0,ceili(lobby.until-clock))} if lobby.active() else {}
	var state: Array=[data,items,round_left,intermission,round_message,frag_limit,time_limit,shots,gate_states,map_epoch,mode_state,votes.snapshot(),clock,projectile_id]
	callv("_snapshot",state)
	if not multiplayer.get_peers().is_empty():
		var raw:=var_to_bytes(state)
		_snapshot_packet.rpc(raw.compress(FileAccess.COMPRESSION_FASTLZ),raw.size())

@rpc("authority","call_remote","unreliable_ordered",1)
func _snapshot_packet(bytes: PackedByteArray,size: int) -> void:
	if size<1 or size>262144 or bytes.size()>262144:return
	var raw:=bytes.decompress(size,FileAccess.COMPRESSION_FASTLZ)
	if raw.size()!=size:return
	var state=bytes_to_var(raw)
	if state is Array and state.size()==14:callv("_snapshot",state)

@rpc("authority","call_local","unreliable_ordered",1)
func _snapshot(data: Array,items: PackedByteArray,remaining: float,pause: float,message: String,limit: int,duration: float,shots: Array,gate_states: Array,epoch: int=0,mode_state: Dictionary={},vote_state: Dictionary={},server_time: float=-1.0,shot_watermark: int=-1) -> void:
	if epoch!=map_epoch or (not multiplayer.is_server() and (map_loading or not active)): return
	if not multiplayer.is_server():
		snapshot_view_time=server_time
		if remote_view_time<0:remote_view_time=server_time
		projectile_watermark=maxi(projectile_watermark,shot_watermark)
		snapshot_projectiles=shots.map(func(shot):return shot[0])
	if not lobby.active():lobby.view.clear()
	elif mode_state.has("lobby"):lobby.view.merge(mode_state.lobby,true)
	demos.capture([data,items,remaining,pause,message,limit,duration,shots,gate_states,epoch,mode_state,vote_state])
	if not multiplayer.is_server():match_mode.receive(mode_state);votes.view=vote_state
	round_left = remaining
	intermission = pause
	round_message = message
	frag_limit = limit
	time_limit = duration
	var mine := multiplayer.get_unique_id()
	for row in data:
		var id: int = row[0]
		if not fighters.has(id): continue
		var s: Dictionary = players[id]
		var actor = fighters[id]
		if not multiplayer.is_server():
			s.merge({"yaw":row[3],"pitch":row[4],"hp":row[5],"armor":row[6],"dead":row[7],"weapon":row[8],"ammo":row[9],"owned":row[10],"kills":row[11],"deaths":row[12],"ping":row[13],"serial":row[14],"cooldown":row[17],"offhand_cooldown":row[19],"spectator":row[20]},true)
			var old_blast:Vector2=actor.blast_velocity
			actor.blast_velocity=row[21] if row.size()>21 else Vector2.ZERO
			actor.velocity.x+=actor.blast_velocity.x-old_blast.x;actor.velocity.z+=actor.blast_velocity.y-old_blast.y
			s.respawn_at = clock+row[15]
			s.invulnerable = clock+1 if row[16] else 0
			actor.target = row[1]
			actor.target_yaw = row[3]
			if id==mine and actor.spawn_serial==row[14]:
				var error: Vector3 = row[1]-actor.position
				if error.length()>2.5: actor.position = row[1]
				elif error.length()>.12: actor.position += error*.18
				actor.velocity.y = row[2].y
		if actor.spawn_serial!=row[14]:
			actor.spawn_serial = row[14]
			actor.reset_view()
			actor.gibbed=false
			if not headless and not s.spectator: effects.play("spawn",row[1],-6)
			actor.position = row[1]
			actor.velocity = row[2]
			if id==mine:
				local_yaw = row[3]
				local_pitch = 0
				desired_weapon = row[8]
				if is_vr(): xr_rig.on_spawn()
		actor.xr_pose=row[18] if row.size()>18 else {}
		if not multiplayer.is_server(): s.xr=actor.xr_pose
		actor.visual_velocity = row[2]
		actor.visual_pitch = row[4]
		actor.visual_weapon = row[8]
		actor.spectator=s.spectator
		actor.show_alive(not s.dead,id==mine and not dedicated)
		if id==mine:
			last_local_hp = s.hp
	for i in range(mini(items.size(),pickups.size())):
		if not multiplayer.is_server(): pickups[i].available = items[i]==1
		if is_instance_valid(pickups[i].node): pickups[i].node.visible = items[i]==1 and not match_mode.kind in ["ig","cc"]
	for shot in shots:
		if multiplayer.is_server(): continue
		if not projectiles.has(shot[0]): _projectile_spawn(shot[0],shot[2],shot[3],shot[1],shot[4],shot[5],shot[6])
		if projectiles.has(shot[0]):
			var p: Dictionary=projectiles[shot[0]]
			var error: Vector3=p.position+p.visual_error-shot[1]
			p.visual_error=error if error.length()<2.0 else Vector3.ZERO
			p.position=shot[1];p.visual_age=0.0
	if not multiplayer.is_server():
		var live_shots: Array = shots.map(func(shot): return shot[0])
		for id in projectiles.keys():
			if not live_shots.has(id) and (shot_watermark<0 or id<=shot_watermark):
				if is_instance_valid(projectiles[id].node): projectiles[id].node.queue_free()
				projectiles.erase(id)
		for i in range(mini(gate_states.size(),gates.size())):
			if gates[i].open!=gate_states[i]: _gate_state(i,gate_states[i])

@rpc("any_peer","call_remote","unreliable",3)
func _ping(stamp: int) -> void:
	if multiplayer.is_server() and players.has(multiplayer.get_remote_sender_id()):
		var id := multiplayer.get_remote_sender_id()
		var peer := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id)
		if peer: players[id].ping = clampi(int(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)),0,400)
		_pong.rpc_id(id,stamp)

@rpc("authority","call_remote","unreliable",3)
func _pong(stamp: int) -> void:
	local_ping = clampi(Time.get_ticks_msec()-stamp,0,2000)

@rpc("any_peer","call_remote","reliable",0)
func _use_request() -> void:
	if multiplayer.is_server(): _use_for(multiplayer.get_remote_sender_id())

func _use_for(id: int) -> void:
	if lobby.active():return
	if match_mode.special.blocked(id):return
	if not players.has(id) or players[id].dead or clock<players[id].use_at: return
	players[id].use_at = clock+.5
	match_mode.fortress.action(id)
	for i in range(gates.size()):
		var offset: Vector3 = fighters[id].position-gates[i].get("center",gates[i].node.position)
		offset.y = 0
		if offset.length()<2.5:
			gates[i].open = true
			gates[i].until = clock+4
			_gate_state.rpc(i,true)

@rpc("authority","call_local","reliable",0)
func _gate_state(index: int,opened: bool) -> void:
	if index>=gates.size(): return
	var gate: Dictionary = gates[index]
	gate.open = opened
	if gate.has("base_position"):
		create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(gate.node,"position",gate.base_position+(gate.travel if opened else Vector3.ZERO),.6)
	else:
		create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(gate.node,"position:y",gate.base+(3.5 if opened else 0),.6)

func chat_send(message: String) -> void:
	if multiplayer.is_server(): _chat_for(1,message)
	else: _chat_request.rpc_id(1,message)

@rpc("any_peer","call_remote","reliable",0)
func _chat_request(message: String) -> void:
	if multiplayer.is_server(): _chat_for(multiplayer.get_remote_sender_id(),message)

func _chat_for(id: int,message: String) -> void:
	if not players.has(id) or clock<players[id].chat_at: return
	players[id].chat_at = clock+.8
	var cleaned := message.left(256).replace("\n"," ").replace("\r"," ").strip_edges().left(140)
	if not cleaned.is_empty(): _announcement.rpc(players[id].name+": "+cleaned,true)

@rpc("authority","call_local","reliable",0)
func _announcement(message: String,is_chat: bool=false) -> void:
	if is_chat:server_log.record("chat_activity",{"characters":message.length()},2)
	else:server_log.record("match_event",{"message":message.left(512)})
	feed.append({"text":message,"until":clock+8})
	while feed.size()>5: feed.pop_front()
	last_event = message
	print("DM_EVENT ","[chat activity]" if is_chat and dedicated else message)

@rpc("authority","call_local","unreliable",3)
func _hit_confirm(id: int) -> void:
	if id==multiplayer.get_unique_id(): hit_flash = .14

@rpc("authority","call_local","unreliable",3)
func _melee_fx(id: int,offhand: bool=false) -> void:
	demos.event("_melee_fx",[id,offhand])
	if fighters.has(id): fighters[id].animate_fire(offhand)
	if headless: return
	if id==multiplayer.get_unique_id():
		melee_animation=.3
		if is_vr(): xr_rig.feedback(.2,.08,offhand)

@rpc("authority","call_local","unreliable",3)
func _shot_fx(id: int,weapon: int,offhand: bool=false) -> void:
	demos.event("_shot_fx",[id,weapon,offhand])
	var predicted:=predicted_offhand_shot_clock if offhand else predicted_shot_clock
	if id==multiplayer.get_unique_id() and not multiplayer.is_server() and clock-predicted<.5: return
	_play_shot_fx(id,weapon,offhand)

func _play_shot_fx(id: int,weapon: int,offhand: bool=false) -> void:
	if fighters.has(id): fighters[id].animate_fire(offhand)
	if headless: return
	if id==multiplayer.get_unique_id():
		if offhand:
			offhand_recoil=1;offhand_visual_cooldown=match_mode.fortress.weapon_data(id,weapon).cycle
		else:
			recoil=1;visual_cooldown=match_mode.fortress.weapon_data(id,weapon).cycle
		if is_vr(): xr_rig.feedback(.25 if weapon<3 else .65,.08,offhand)
		if camera and weapon>=2 and weapon!=8:
			var flash := OmniLight3D.new()
			flash.light_color = W.COLORS[weapon]
			flash.light_energy = 2.4
			flash.omni_range = 2.7
			camera.add_child(flash)
			var model: Node3D=offhand_viewmodel if offhand else viewmodel
			if is_vr(): model=xr_rig.offhand_gun if offhand else xr_rig.gun
			flash.position=Vector3(-.18 if offhand else .18,-.18,-.8)
			if is_instance_valid(model): flash.global_position=model.to_global(model.get_meta("muzzle",Vector3(0,0,-.6)))
			var spark := Art.box(flash,Vector3.ZERO,Vector3(.08,.07,.10),Art.material(W.COLORS[weapon],0,5))
			spark.rotation.z = randf()*PI
			get_tree().create_timer(.055).timeout.connect(flash.queue_free)
	if fighters.has(id):
		spatial.play("weapon_"+str(weapon),_weapon_transform(id,offhand).origin,-4)

@rpc("authority","call_local","unreliable",3)
func _impacts(start: Vector3,ends: PackedVector3Array,weapon: int) -> void:
	demos.event("_impacts",[start,ends,weapon])
	if headless or weapon<2: return
	var impact_budget:=2
	for end in ends:
		if impact_budget>0:
			var direction: Vector3=(end-start).normalized()
			var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(end-direction*.08,end+direction*.08,1))
			if not hit.is_empty():
				spatial.play("impact",hit.position+hit.normal*.02,-17)
				impact_budget-=1
		var length := start.distance_to(end)
		if length<.02: continue
		var tracer := Art.box(self,(start+end)/2,Vector3(.035 if weapon==9 else .013,.035 if weapon==9 else .013,length),Art.material(W.COLORS[weapon],0,1))
		tracer.look_at(end)
		get_tree().create_timer(.3 if weapon==9 else .055).timeout.connect(tracer.queue_free)

@rpc("authority","call_local","reliable",0)
func _projectile_end(id: int,pos: Vector3,weapon: int) -> void:
	if not multiplayer.is_server():
		if ended_projectiles.has(id):return
		ended_projectiles[id]=true
		while ended_projectiles.size()>2048:ended_projectiles.erase(ended_projectiles.keys()[0])
	demos.event("_projectile_end",[id,pos,weapon])
	if projectiles.has(id):
		if is_instance_valid(projectiles[id].node): projectiles[id].node.queue_free()
		projectiles.erase(id)
	if headless: return
	if weapon==6 or weapon==8: effects.play("explosion",pos,-3)
	var burst := Art.box(self,pos,Vector3.ONE*.12,Art.material(W.COLORS[weapon],0,3))
	var tween := create_tween()
	tween.tween_property(burst,"scale",Vector3.ONE*(14 if weapon==6 or weapon==8 else 3),.18)
	tween.tween_callback(burst.queue_free)

func _process(delta: float) -> void:
	if demos.playing:return
	if active and not lobby.active():match_mode.draw_objectives()
	if headless: return
	melee_animation=maxf(0,melee_animation-delta)
	hurt_flash = maxf(0,hurt_flash-delta)
	hit_flash = maxf(0,hit_flash-delta)
	recoil = move_toward(recoil,0,delta*7)
	offhand_recoil=move_toward(offhand_recoil,0,delta*7)
	offhand_visual_cooldown=maxf(0,offhand_visual_cooldown-delta)
	visual_cooldown = maxf(0,visual_cooldown-delta)
	for p in pickups:
		if p.available and is_instance_valid(p.node):
			var display := p.node.get_node("Display") as Node3D
			display.rotation.y += delta*.8
			display.position.y = .58+sin(clock*2)*.05
			var halo:=p.node.get_node_or_null("PowerHalo") as Node3D
			if halo:halo.position.y=.42+sin(clock*2.5)*.12
	_update_projectile_visuals(delta)
	if is_vr(): return
	if not camera or not active: return
	var s := local_state()
	if s.is_empty(): return
	if s.weapon!=model_weapon:
		if is_instance_valid(viewmodel): viewmodel.queue_free()
		if is_instance_valid(offhand_viewmodel): offhand_viewmodel.queue_free()
		offhand_viewmodel=null
		if s.weapon==2:
			offhand_viewmodel=Art.weapon(2);offhand_viewmodel.scale=Vector3.ONE*.72;camera.add_child(offhand_viewmodel)
		viewmodel = Art.weapon(s.weapon)
		viewmodel.scale = Vector3.ONE*.72
		camera.add_child(viewmodel)
		model_weapon = s.weapon
	camera.rotation.x = local_pitch
	camera_eye_height = lerpf(camera_eye_height,.35 if s.dead and not s.spectator else 1.48,minf(1,delta*8))
	camera.position.y = camera_eye_height+fighters[multiplayer.get_unique_id()].view_offset
	fighters[multiplayer.get_unique_id()].rotation.y = local_yaw
	viewmodel.visible = not s.dead and not menu_open and not lobby.active()
	var speed: float = fighters[multiplayer.get_unique_id()].velocity.length()
	viewmodel.position = Vector3(.18+sin(clock*10)*minf(speed*.003,.025),-.24+absf(cos(clock*10))*minf(speed*.003,.025)-recoil*.035,-.48+recoil*.075)
	viewmodel.rotation = Vector3(recoil*.10,.10,0)
	if melee_animation>0:
		var swing:=sin((1.0-melee_animation/.3)*PI)
		viewmodel.position+=Vector3(-.2,-.02,-.22)*swing
		viewmodel.rotation+=Vector3(-.3,-.7,.45)*swing
	if is_instance_valid(offhand_viewmodel):
		offhand_viewmodel.visible=viewmodel.visible
		offhand_viewmodel.position=Vector3(-.18+sin(clock*10)*minf(speed*.003,.025),-.24+absf(cos(clock*10))*minf(speed*.003,.025)-offhand_recoil*.035,-.48+offhand_recoil*.075)
		offhand_viewmodel.rotation=Vector3(offhand_recoil*.10,-.10,0)
	if s.weapon==3 and visual_cooldown>.25 and visual_cooldown<.8: viewmodel.rotation.x -= sin((visual_cooldown-.25)/.55*PI)*.22
	if s.weapon==4 and visual_cooldown>.3 and visual_cooldown<1.3: viewmodel.rotation.x -= sin((visual_cooldown-.3)*PI)*.38

func _load_map(map_id: String) -> bool:
	if map_id==lobby.ID:return lobby.build()
	if current_map==map_id and $Map.get_child_count()>0: return true
	var info: Dictionary = {}
	for row in map_catalog:
		if row.id==map_id: info=row; break
	if info.is_empty(): return false
	var scene: PackedScene=Maps.scene(info)
	if not scene: return false
	match_mode.clear_visuals()
	for child in $Map.get_children(): child.free()
	pickups.clear()
	gates.clear()
	lifts.clear()
	spawn_points.clear()
	spawn_yaws.clear()
	map_objectives.clear();ctf_spawns=[[],[]];tf_resupply=[[],[]];tf_capture.clear()
	var level := scene.instantiate()
	$Map.add_child(level)
	current_map=map_id
	map_title=info.title
	map_sha=info.sha256
	var runtime := preload("res://deathmatch/maps/runtime.gd").new()
	runtime.name = "MapRuntime"
	$Map.add_child(runtime)
	runtime.configure(self,level)
	if spawn_points.is_empty(): return false
	if not headless:
		$Overview.projection=Camera3D.PROJECTION_PERSPECTIVE
		$Overview.position=spawn_points[0]+Vector3(0,1.48,0)
		$Overview.rotation=Vector3(0,spawn_yaws[0],0)
		$Overview.fov=85
		$DuskSun.light_energy=.25
	print("MAP_READY ",current_map," spawns=",spawn_points.size()," pickups=",pickups.size())
	return true

func _update_projectile_visuals(delta: float) -> void:
	for p in projectiles.values():
		if not multiplayer.is_server() and intermission<=0:
			var step:=minf(delta,maxf(0,.10-p.visual_age))
			var end: Vector3=p.position+p.direction*W.DATA[p.weapon].speed*step
			var wall:=HitDetection.world_fraction(get_world_3d().direct_space_state,p.position,end,W.DATA[p.weapon].radius) if step>0 else INF
			p.position=p.position.lerp(end,minf(1.0,wall));p.visual_age+=delta
			p.visual_error*=exp(-20*delta)
		if is_instance_valid(p.node): p.node.position = p.position+p.visual_error

func is_vr() -> bool:
	return is_instance_valid(xr_rig) and xr_rig.enabled
func _weapon_transform(id: int, offhand: bool=false) -> Transform3D:
	var s: Dictionary=players[id]
	if not s.xr.is_empty(): return Transform3D(Basis(Vector3.UP,s.yaw),fighters[id].position)*s.xr.get("offhand_weapon" if offhand else "weapon",Transform3D.IDENTITY)
	var aim:=Basis(Vector3.UP,s.yaw)*Basis(Vector3.RIGHT,s.pitch)
	var offset:=Vector3(-.18 if offhand else .18,0,0) if s.weapon==2 else Vector3.ZERO
	return Transform3D(aim,fighters[id].position+Vector3.UP*1.45+aim*offset)
func _shot_origin(id: int, offhand: bool=false) -> Vector3:
	var transform_here:=_weapon_transform(id,offhand)
	if players[id].xr.is_empty(): return transform_here.origin
	var weapon: int=players[id].weapon
	return Art.held_transform(transform_here,weapon)*Art.muzzle(weapon)
func _weapon_blocked(id: int, offhand: bool=false) -> bool:
	if not players.has(id): return true
	if players[id].xr.is_empty() and players[id].weapon!=2: return false
	var from: Vector3=fighters[id].position+Vector3.UP*1.25
	var query:=PhysicsRayQueryParameters3D.create(from,_shot_origin(id,offhand),1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

@rpc("authority","call_local","reliable",0)
func _hurt_fx(id: int,pos: Vector3,direction: Vector3,amount: int,dead: bool,gibbed: bool,seed_value: int) -> void:
	demos.event("_hurt_fx",[id,pos,direction,amount,dead,gibbed,seed_value])
	effects.hit(id,pos,direction,amount,dead,gibbed,seed_value)
	if id==multiplayer.get_unique_id() and not dedicated and not headless:
		hurt_flash=maxf(hurt_flash,clampf(.18+amount*.006,.18,.42))
		effects.local_hit()

@rpc("authority","call_local","unreliable",3)
func _teleport_fx(pos: Vector3) -> void:
	demos.event("_teleport_fx",[pos])
	effects.play("teleport",pos)

func _clear_map_players() -> void:
	votes.reset()
	# Preserve the ENet connection; every peer goes through map readiness again.
	active=false
	for actor in fighters.values(): actor.free()
	fighters.clear();players.clear()
	for shot in projectiles.values():
		if is_instance_valid(shot.node): shot.node.free()
	projectiles.clear();history.clear()
	remote_view_time=-1.0;snapshot_view_time=-1.0;projectile_watermark=-1;snapshot_projectiles.clear();ended_projectiles.clear()
	avatars.reset();effects.clear()
	camera=xr_rig.head if is_vr() else null
	viewmodel=null;model_weapon=-1;camera_eye_height=1.48
	hurt_flash=0;hit_flash=0;recoil=0;visual_cooldown=0;offhand_visual_cooldown=0;offhand_recoil=0;melee_animation=0
	if not headless and not is_vr(): $Overview.make_current()

func _prepare_client_map(epoch: int) -> void:
	map_network.reset()
	if uploads:uploads.reset()
	_clear_map_players()
	map_epoch=epoch;map_loading=true
	connect_deadline=clock+240
	menu_open=true
	if hud: hud.show_menu(true)

func _rotate_map(map_id: String) -> bool:
	if not multiplayer.is_server(): return false
	if not _load_map(map_id):
		status("Could not load rotation map: "+map_id)
		return false
	match_mode.reset()
	if lobby.active():match_mode.clear_visuals()
	var names: Dictionary=pending_names.duplicate()
	var spectators: Dictionary=pending_spectators.duplicate()
	for id in players:
		if id>1: names[id]=players[id].name;spectators[id]=players[id].spectator;pending_teams[id]=players[id].team
	map_network.reset()
	if uploads:uploads.reset()
	_clear_map_players()
	pending_names=names
	pending_spectators=spectators
	map_epoch+=1;map_loading=not names.is_empty()
	selected_map=map_id
	round_left=time_limit;round_message="";intermission=0
	active=true
	# Send the new map on the same reliable channel as its download messages.
	for id in names:
		pending_joins[id]=clock+240
		map_network.offer(id)
	if not dedicated: _add_player(1,nickname)
	server_log.record("map_rotated",{"map":current_map,"waiting_peers":pending_names.size()})
	print("MAP_ROTATED ",current_map," epoch=",map_epoch)
	return true
