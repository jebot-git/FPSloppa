extends Node3D
const RoomScale=preload("res://deathmatch/vr/room_scale.gd")
const W = preload("res://deathmatch/weapons.gd")
var armory=preload("res://deathmatch/experimental/weapon_rules.gd").new()
var variant_visuals: Node3D
var variant_combat=preload("res://deathmatch/experimental/combat.gd").new()
const Art = preload("res://deathmatch/art.gd")
const Fighter = preload("res://deathmatch/fighter.gd")
const Profile = preload("res://deathmatch/profile.gd")
const HitDetection = preload("res://deathmatch/hit_detection.gd")
const ProjectileTargets=preload("res://deathmatch/projectile_targets.gd")
const PROTOCOL := "fpsloppa-39-rotating-koth"
const Melee=preload("res://deathmatch/melee.gd")
const MAX_PLAYERS := 8 # In-game hosts include the playing host.
const SERVER_MAX_PLAYERS := preload("res://deathmatch/server/config.gd").MAX_CLIENTS
const VRPoses=preload("res://deathmatch/vr/poses.gd")
const Maps = preload("res://deathmatch/maps/loader.gd")
var map_catalog: Array = Maps.catalog()
var selected_map := "qsrc_dm1"
var current_map := ""
var map_rotation: Array=[]
var mode_maplists: Dictionary={}
var map_assault: Array=[]
var map_objectives: Dictionary={}
var tf_capture: Dictionary={}
var tf_resupply: Array=[[],[]]
var ctf_spawns: Array=[[],[]]
var map_uploads:=true
var uploads: Node
var map_previews: Node
var rotation_index:=0
var map_epoch:=0
var map_loading:=false
var map_title := ""
var map_sha := ""
var spawn_points: Array = []
var spawn_yaws: Array = []
var fall_limit := -8.0
var pending_names: Dictionary = {}
var loading: Node
var map_network: Node
var xr_rig
var effects
var haptics: Node
var ability_effects: Node3D
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
var join_generation:=0
var input_accumulator := 0.0
var ping_accumulator := 0.0
var sequence := 0
var active := false
var dedicated := false
var server_name := "FPSloppa"
var bind_address := "*"
var district_gateway
var cq_maps=preload("res://deathmatch/conquest/district_maps.gd").new(self)
var cq_client=preload("res://deathmatch/conquest/client.gd").new(self)
var district_worker # Private experimental worker; never a public ENet endpoint.
var cq_profile:=false # Separate launcher/protocol, fixed for the process lifetime.
var max_clients := MAX_PLAYERS
var voice_backend:="builtin"
var mumble_url:=""
var voice_enabled := true
var announcer
var chainsaw=preload("res://deathmatch/chainsaw.gd").new()
var voice
var permissions
var practice := false
var bots
var bot_population=preload("res://deathmatch/server/bot_population.gd").new(self)
var round_left := 600.0
var frag_limit := 20
var normal_time_limit := 600.0
var time_limit := 600.0:
	set(value):
		if is_instance_valid(match_mode) and match_mode.kind=="tb":time_limit=match_mode.titanball.BASE_SECONDS
		else:time_limit=value;normal_time_limit=value
var round_clock: Node
var intermission := 0.0
var round_message := ""
var nickname := "Marine"
var local_yaw := 0.0
var local_pitch := 0.0
var desired_weapon := 2
var fire_down := false
var camera_eye_height:=1.48
var prone_toggle:=false
var camera: Camera3D
var viewmodel: Node3D
var model_weapon := -1
var model_art_rules:=""
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
var chat_feed: Array = []
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
const ConnectionLog=preload("res://deathmatch/network/diagnostics.gd")
var pending_spectators: Dictionary={}
var pending_teams: Dictionary={}
var rcon: Node
var server_log
var votes
var match_mode=preload("res://deathmatch/modes/match.gd").new()
var joining_as_spectator:=false
var presentation: Dictionary={}
var music: Node
var quitting:=false
const Presentation=preload("res://deathmatch/settings/preferences.gd")
var connect_deadline := 0.0
var connect_addresses: Array[String]=[]
var connect_address_index:=0
var connect_address_deadline:=0.0
var connect_port:=7777
var local_ping := 0
var last_event := ""
var headless := false
var pending_network_jump:=false
var network_flush_pending:=false
var input_paused_until:=0.0
var next_network_health:=0.0
var bandwidth = preload("res://deathmatch/network/bandwidth.gd").new()
var replication = preload("res://deathmatch/network/replication.gd").new()
var remote_interpolation = preload("res://deathmatch/network/interpolation.gd").new()
var input_delivery = preload("res://deathmatch/network/input_delivery.gd").new()
var fire_delivery = preload("res://deathmatch/network/fire_delivery.gd").new()
const NetCodec = preload("res://deathmatch/network/codec.gd")
var predicted_shot_clock := -10.0

var lobby
var demos
var bindings=preload("res://deathmatch/settings/bindings.gd").new()
func _ready() -> void:
	cq_profile=OS.get_cmdline_user_args().has("--experimental-cq")
	if cq_maps.enabled and not cq_profile:push_error("District maps require the experimental CQ profile.");get_tree().quit(2);return
	get_tree().auto_accept_quit=false
	if OS.has_feature("android") and FileAccess.file_exists("res://deathmatch/assets/offline-base.zip"):
		set_process(false);set_physics_process(false)
		var bootstrap=load("res://deathmatch/assets/bootstrap.gd").new();add_child(bootstrap)
		if not await bootstrap.install():return
		bootstrap.queue_free()
		map_catalog=Maps.catalog()
		set_process(true);set_physics_process(true)
	if not OS.has_feature("dedicated_server"):
		preload("res://deathmatch/assets/paths.gd").migrate_preferences()
		bindings.load_settings()
	demos=preload("res://deathmatch/demos/session.gd").new();demos.name="DemoSession";add_child(demos);demos.setup(self)
	lobby=preload("res://deathmatch/modes/lobby.gd").new();lobby.name="WaitingLobby";add_child(lobby);lobby.setup(self)
	headless = DisplayServer.get_name() == "headless"
	server_log=preload("res://deathmatch/server/log.gd").new();add_child(server_log)
	match_mode.setup(self)
	armory.setup(self);variant_combat.setup(self)
	if cq_profile:
		var cq_error: String=match_mode.conquest.install()
		if not cq_error.is_empty():push_error(cq_error);get_tree().quit(2);return
		match_mode.configure({"sv_gametype":"cq"})
	votes=preload("res://deathmatch/modes/votes.gd").new();votes.name="PlayerVotes";add_child(votes);votes.setup(self)
	if not OS.has_feature("dedicated_server"):
		nickname=Profile.load_name()
		presentation=Presentation.read_settings()
	announcer=preload("res://deathmatch/audio/announcer.gd").new();announcer.name="Announcer";add_child(announcer);announcer.setup(self)
	if not OS.has_feature("dedicated_server"):
		permissions=load("res://deathmatch/vr/permissions.gd").new()
		add_child(permissions)
		spatial=load("res://deathmatch/audio/spatial.gd").new()
		add_child(spatial)
		spatial.setup(self)
		round_clock=load("res://deathmatch/audio/round_clock.gd").new();add_child(round_clock);round_clock.setup(self)
	get_tree().root.gui_embed_subwindows = true
	# The server owns every RPC path; clients never need peer-to-peer relaying.
	(multiplayer as SceneMultiplayer).server_relay = false

	if not headless: get_viewport().msaa_3d = Viewport.MSAA_2X if OS.has_feature("android") else Viewport.MSAA_4X
	loading=preload("res://deathmatch/network/loading.gd").new();loading.name="Loading";add_child(loading);loading.setup(self)
	avatars = preload("res://deathmatch/avatars/network.gd").new()
	avatars.name = "AvatarNetwork"
	add_child(avatars)
	avatars.setup(self)
	map_network=preload("res://deathmatch/maps/network.gd").new()
	map_network.name="MapNetwork"
	add_child(map_network)
	map_network.setup(self)
	uploads=preload("res://deathmatch/maps/uploads.gd").new();uploads.name="MapUploads";add_child(uploads);uploads.setup(self)
	map_previews=preload("res://deathmatch/maps/previews.gd").new();map_previews.name="MapPreviews";add_child(map_previews);map_previews.setup(self)
	effects=preload("res://deathmatch/effects/combat.gd").new()
	effects.name="CombatEffects"
	add_child(effects)
	effects.setup(self)
	if not headless and not OS.has_feature("dedicated_server") and not OS.get_cmdline_user_args().has("--server"):
		haptics=load("res://deathmatch/haptics/service.gd").new();add_child(haptics);haptics.setup(self)
	voice=load("res://deathmatch/voice/relay.gd" if OS.has_feature("dedicated_server") else "res://deathmatch/voice/chat.gd").new()
	voice.name="VoiceChat"
	add_child(voice)
	voice.setup(self)
	if not OS.has_feature("dedicated_server"):_load_map(selected_map)
	if not OS.has_feature("dedicated_server"):
		music=load("res://deathmatch/audio/music/player.gd").new();add_child(music);music.setup(self)
	if not headless:
		for i in range(9): sounds.append(Art.sound(i))
		hud = load("res://deathmatch/interface.gd").new()
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
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(func(): disconnect_game("The host disconnected."))
	var args := OS.get_cmdline_user_args()
	if args.has("--quit-after-seconds"):
		get_tree().create_timer(maxf(.1,float(_arg_value(args,"--quit-after-seconds","10")))).timeout.connect(request_quit)
	if args.has("--cq-worker"):
		if not cq_profile or not headless:
			push_error("District workers require headless --experimental-cq.");get_tree().quit(2);return
		district_worker=preload("res://deathmatch/server/districts/worker.gd").new()
		add_child(district_worker);district_worker.setup(self,args);return
	if OS.has_feature("dedicated_server"):
		_start_dedicated(args)
		if args.has("--record-demo"):
			demos.auto_path=_arg_value(args,"--record-demo","");demos.auto_record=true
			if active:demos.start_record(demos.auto_path)
		return
	if args.has("--frame-stats") and not headless: add_child(load("res://deathmatch/performance/frame_stats.gd").new())
	selected_map = _arg_value(args,"--map",selected_map)
	if args.has("--import-map"):
		var imported: Dictionary=Maps.import_custom(_arg_value(args,"--import-map",""))
		print("MAP_IMPORT_RESULT ",JSON.stringify(imported))
		get_tree().quit(1 if imported.has("error") else 0)
		return
	if args.has("--check-assets"):
		var result: int=await load("res://deathmatch/diagnostics.gd").check_assets(self)
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
		start_host(nickname,0,20,10,true,_arg_value(args,"--mode","dm"),_arg_value(args,"--weapons","doom"))
	elif args.has("--connect"):
		start_join(nickname,_arg_value(args,"--connect","127.0.0.1"),_arg_int(args,"--port",7777),args.has("--spectate"))

	if args.has("--record-demo"):
		demos.auto_path=_arg_value(args,"--record-demo","");demos.auto_record=true
		if active:demos.start_record(demos.auto_path)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:request_quit()

func request_quit() -> void:
	if quitting:return
	quitting=true
	if is_instance_valid(district_gateway):district_gateway.stop()
	if haptics:haptics.shutdown()
	active=false
	if is_instance_valid(round_clock):round_clock.clear()
	if is_instance_valid(spatial):spatial.clear()
	if is_instance_valid(effects):
		if is_instance_valid(effects.local_pain):effects.local_pain.stop()
		if is_instance_valid(effects.local_pickup):effects.local_pickup.stop()
	if is_instance_valid(announcer):announcer.set_process(false);announcer.clear_audio()
	if is_instance_valid(music):music.stop()
	if is_instance_valid(voice):voice.set_mode(0)
	# Let the audio mixer release stopped playback before engine teardown.
	await get_tree().create_timer(.1).timeout
	get_tree().quit()

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
	if cq_maps.enabled and settings.sv_cq_backend!="districts":push_error("Independent district maps require the districts backend.");get_tree().quit(2);return
	if args.has("--cq-external-workers") and (not cq_profile or settings.sv_cq_backend!="districts"):
		push_error("External workers require CQ with sv_cq_backend districts.");get_tree().quit(2);return
	if (settings.sv_gametype=="cq")!=cq_profile:
		push_error("CQ requires its separate launch script and a CQ-only config.");get_tree().quit(2);return
	if not armory.select(_arg_value(args,"--weapons",settings.sv_weapon_rules)):push_error("Unknown weapon ruleset");get_tree().quit(2);return
	lobby.enabled=settings.sv_lobby==1;lobby.seconds=settings.sv_lobby_seconds
	if not server_log.setup(self,settings):push_error(server_log.last_error);get_tree().quit(2);return
	server_name=settings.sv_hostname
	bind_address=settings.net_ip
	max_clients=settings.sv_cq_maxclients if cq_profile else settings.sv_maxclients
	bot_population.target=settings.sv_cq_bot_fill if cq_profile else settings.sv_bot_fill;bot_population.count_target=-1
	if not cq_profile and max_clients>16:push_warning(preload("res://deathmatch/server/config.gd").CAPACITY_WARNING)
	voice_backend=settings.sv_voice_backend if settings.sv_voice==1 else "builtin";mumble_url=settings.sv_mumble_url if settings.sv_voice==1 else ""
	voice_enabled=settings.sv_voice==1 and voice_backend=="builtin"
	announcer.policy(settings.sv_announcer==1)
	map_uploads=settings.sv_map_uploads==1 and not cq_profile
	match_mode.configure(settings)
	votes.enabled=settings.sv_votes==1 and not cq_profile;votes.allowed_modes=settings.gametypes
	mode_maplists=settings.mode_maps.duplicate(true)
	if cq_profile:mode_maplists["cq"]=[match_mode.conquest.MAP_ID]
	for kind in match_mode.NAMES:
		var list_kind: String=match_mode.maplist_kind(kind)
		if kind=="if" and str(settings.if_maplist).is_empty():
			mode_maplists[kind]=[]
			if str(settings.sv_maplist).is_empty() and not FileAccess.file_exists(Maps.Paths.folder("maps")+"if_maplist.txt"):
				mode_maplists[kind]=mode_maplists.ig.duplicate()
		if mode_maplists[kind].is_empty() and not str(settings.sv_maplist).strip_edges().is_empty():
			mode_maplists[kind]=settings.maps.duplicate()
		var list_path: String=Maps.Paths.folder("maps")+list_kind+"_maplist.txt"
		if kind=="if" and not FileAccess.file_exists(list_path):list_path=Maps.Paths.folder("maps")+"ig_maplist.txt"
		if mode_maplists[kind].is_empty() and FileAccess.file_exists(list_path):
			for line in FileAccess.get_file_as_string(list_path).split("\n"):
				for name in line.split("#")[0].replace("\t"," ").strip_edges().split(" ",false):
					mode_maplists[kind].append(name)
		if mode_maplists[kind].is_empty():mode_maplists[kind]=settings.maps.duplicate()
		if kind=="if" and str(settings.if_maplist).is_empty() and str(settings.sv_maplist).is_empty() and not FileAccess.file_exists(Maps.Paths.folder("maps")+"if_maplist.txt"):
			mode_maplists[kind]=Maps.inherited_maplist(map_catalog,kind,mode_maplists[kind])
		if mode_maplists[kind].size()>32:push_error(kind+" maplist exceeds 32 maps");get_tree().quit(2);return
		if kind in votes.allowed_modes:
			for map_id in mode_maplists[kind]:
				if not map_catalog.any(func(row):return row.id==map_id):push_error("Unknown map in "+kind+"_maplist: "+str(map_id));get_tree().quit(2);return
	for row in map_catalog:
		if row.get("imported",false):uploads.register_map(row)
	map_rotation=mode_maplists[match_mode.kind].duplicate()
	if args.has("--map") and not cq_profile: map_rotation=[_arg_value(args,"--map",settings.map)]
	for map_id in map_rotation:
		if not map_catalog.any(func(row): return row.id==map_id and FileAccess.file_exists(row.path)):
			push_error("Unknown or unavailable map in rotation: "+str(map_id));get_tree().quit(2);return
	rotation_index=0
	if map_rotation.is_empty():push_error("No maps available for "+match_mode.kind);get_tree().quit(2);return
	selected_map=map_rotation[0]
	if cq_profile and settings.sv_cq_backend=="districts":
		district_gateway=preload("res://deathmatch/server/districts/gateway.gd").new();add_child(district_gateway);district_gateway.setup(self,settings.sv_cq_worker_limit)
		if district_gateway.closing:return
	start_host("Server",_arg_int(args,"--port",settings.net_port),_arg_int(args,"--frags",settings.fraglimit),_arg_int(args,"--minutes",settings.timelimit),false)
	if not active:
		get_tree().quit(2)
		return
	rcon=preload("res://deathmatch/server/rcon.gd").new();add_child(rcon)
	if not rcon.setup(self,settings):push_error(rcon.last_error);get_tree().quit(2);return
	server_log.record("server_started",{"hostname":server_name,"bind":bind_address,"max_clients":max_clients,"protocol":connection_protocol(),"weapon_rules":armory.kind,"version":ProjectSettings.get_setting("application/config/version"),"rotation":map_rotation,"allowed_modes":votes.allowed_modes,"voice_backend":voice_backend,"friendly_fire":match_mode.friendly_fire,"score_limit":match_mode.limit()})
	print("SERVER_CONFIG name=",server_name," bind=",bind_address," maxclients=",max_clients," voice=",voice_enabled," map=",current_map," rotation=",map_rotation," weapons=",armory.kind," gametype=",match_mode.kind," limit=",match_mode.limit()," friendlyfire=",match_mode.friendly_fire)

func network_player_limit() -> int:return 64 if cq_profile else SERVER_MAX_PLAYERS

func connection_protocol() -> String:return (match_mode.conquest.PROTOCOL+"-"+cq_maps.PROFILE if cq_maps.enabled else match_mode.conquest.PROTOCOL) if cq_profile else PROTOCOL

func _arg_value(args: PackedStringArray,key: String,fallback: String) -> String:
	var i := args.find(key)
	return args[i+1] if i>=0 and i+1<args.size() else fallback

func _arg_int(args: PackedStringArray,key: String,fallback: int) -> int:
	return int(_arg_value(args,key,str(fallback)))

func _pickup_art(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = p.position
	$Map.add_child(root)
	var color: Color = armory.color(p.item) if p.kind=="weapon" else Color("6fc7ec")
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
	if p.kind=="weapon": model = Art.weapon(p.item,int(presentation.get("texture_filter",2)),armory.effective())
	else: model=load("res://deathmatch/pickups/models.gd").create(p.kind,p.item)
	root.add_child(model)
	model.name = "Display"
	model.position.y = .58
	var label := Label3D.new()
	label.text = armory.pickup_title(p.item) if p.kind=="weapon" else (armory.ammo_names()[p.item] if p.kind=="ammo" else p.kind.to_upper())
	if p.kind=="health" and p.item==100:label.text="MEGA HEALTH"
	if p.kind=="armor" and p.item==2:label.text="MEGA ARMOUR"
	if p.has("title"):label.text=p.title
	label.position.y = 1.05
	label.font_size = 24
	label.pixel_size = .004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	root.add_child(label)
	return root

func start_host(player_name: String,port: int,frags: int,minutes: int,training: bool, mode: String="dm",weapon_rules: String="doom") -> void:
	if loading.blocking:return
	if cq_profile and (not dedicated or match_mode.kind!="cq"):status("CQ uses its dedicated experimental server launcher.");return
	if not cq_profile and mode=="cq":status("Use the separate CQ launcher.");return
	if active: return
	if not dedicated:
		var changed: bool=armory.kind!=weapon_rules
		if not armory.select(weapon_rules):status("Unknown weapon ruleset.");return
		if changed:current_map="";model_weapon=-1
	variant_combat.reset()
	announcer.reset()
	if not dedicated:announcer.policy(true)
	if not dedicated: match_mode.configure({"sv_gametype":mode if match_mode.NAMES.has(mode) else "dm","capturelimit":clampi(frags,1,100),"hilllimit":clampi(frags,1,100)});votes.enabled=true;votes.allowed_modes=match_mode.NAMES.keys().filter(func(value):return value!="cq");voice_backend="builtin";mumble_url="";voice_enabled=true
	if not dedicated and selected_map not in maps_for_mode(match_mode.kind):
		var hills: Array=maps_for_mode(match_mode.kind)
		if hills.is_empty():status("No compatible arenas installed.");return
		selected_map=hills[0]
	max_clients=clampi(max_clients,2,64) if cq_profile else clampi(max_clients,1,SERVER_MAX_PLAYERS) if dedicated else MAX_PLAYERS
	if not _load_map(selected_map):
		status("Could not load the selected map.")
		return
	if match_mode.kind=="as" and not match_mode.assault.supported():
		status("Experimental AS requires a map with two ordered AS objectives and team spawns.")
		return
	match_mode.reset()
	nickname = clean_name(player_name)
	if training:
		multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	else:
		var peer:=ENetMultiplayerPeer.new()
		peer.set_bind_ip(bind_address)
		var err:=peer.create_server(clampi(port,1024,65535),max_clients+8)
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
		pickup.available = not match_mode.fixed_loadout()
		pickup.respawn = 0
	for gate in gates:
		gate.open = false
		gate.node.position = gate.base_position if gate.has("base_position") else Vector3(gate.node.position.x,gate.base,gate.node.position.z)
	active = true
	if not dedicated: _add_player(1,nickname)
	if training and not is_instance_valid(district_worker):
		for id in [-1,-2,-3]: _add_player(id,"Bot "+str(-id))
		bots=preload("res://deathmatch/bots.gd").new()
		add_child(bots)
		bots.setup(self)
	if dedicated:bot_population.refresh_navigation()
	bot_population.maintain()
	menu_open = dedicated
	if hud: hud.show_menu(menu_open)
	if not dedicated and not headless: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("DM_HOST_READY port=",port," practice=",practice)

func start_join(player_name: String,address: String,port: int,spectator: bool=false) -> void:
	if active or loading.blocking: return
	announcer.reset();announcer.policy(false)
	local_ping=0
	nickname = clean_name(player_name)
	joining_as_spectator=spectator
	if address.strip_edges().is_empty():
		status("Enter the host's IP address or hostname.")
		return
	loading.begin();menu_open=true
	if hud:hud.show_menu(true)
	join_generation+=1
	var attempt:=join_generation
	var host:=address.strip_edges()
	connect_addresses.clear();connect_address_index=0;connect_address_deadline=0
	connect_port=clampi(port,1024,65535)
	connect_deadline=clock+15
	ConnectionLog.record("connect_start",{"address":host,"port":port,"protocol":connection_protocol()})
	status("Connecting to %s:%d…" % [address,port])
	if not host.is_valid_ip_address():
		# ENet resolves hostnames synchronously; use Godot's resolver worker first.
		var query:=IP.resolve_hostname_queue_item(host,IP.TYPE_ANY)
		if query==IP.RESOLVER_INVALID_ID:disconnect_game("Could not start hostname lookup.");return
		while IP.get_resolve_item_status(query) in [IP.RESOLVER_STATUS_WAITING,IP.RESOLVER_STATUS_NONE]:
			await get_tree().process_frame
			if attempt!=join_generation or not loading.blocking:
				IP.erase_resolve_item(query);return
		if IP.get_resolve_item_status(query)==IP.RESOLVER_STATUS_DONE:
			for candidate in IP.get_resolve_item_addresses(query):
				if candidate is String and candidate.is_valid_ip_address() and not candidate in connect_addresses:
					connect_addresses.append(candidate)
					if connect_addresses.size()>=4:break
		IP.erase_resolve_item(query)
		if connect_addresses.is_empty():disconnect_game("Could not resolve server hostname.");return
	else:connect_addresses.append(host)
	connect_deadline = clock+30
	_next_connect_address()

func _next_connect_address() -> void:
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	while connect_address_index<connect_addresses.size() and clock<connect_deadline:
		var address:=connect_addresses[connect_address_index];connect_address_index+=1
		var peer:=ENetMultiplayerPeer.new()
		var error:=peer.create_client(address,connect_port)
		ConnectionLog.record("transport_attempt",{"attempt":connect_address_index,"candidates":connect_addresses.size(),"family":"ipv6" if ":" in address else "ipv4","create_error":error})
		if error!=OK:continue
		multiplayer.multiplayer_peer=peer
		connect_address_deadline=minf(connect_deadline,clock+6) if connect_address_index<connect_addresses.size() else connect_deadline
		return
	disconnect_game("Connection failed for all resolved addresses. Check host, firewall and UDP port.")

func _connection_failed() -> void:
	if not connect_addresses.is_empty() and connect_address_index<connect_addresses.size():_next_connect_address()
	else:disconnect_game("Connection failed. Check address and UDP port.")

func clean_name(value: String) -> String:
	return Profile.clean(value)

func _connected() -> void:
	connect_addresses.clear();connect_address_deadline=0
	ConnectionLog.record("transport_connected",{"protocol":connection_protocol()})
	_hello.rpc_id(1,nickname,connection_protocol(),joining_as_spectator)

func _peer_connected(id: int) -> void:
	if multiplayer.is_server():
		pending_joins[id] = clock+30
		var connection: Dictionary=server_log.transport(id);connection["peer"]=id
		server_log.record("peer_connected",connection);server_log.phase(id,"waiting_hello")

@rpc("any_peer","call_remote","reliable",0)
func _hello(player_name: String,version: String,spectator: bool=false) -> void:
	if not multiplayer.is_server() or not active: return
	var id := multiplayer.get_remote_sender_id()
	if id<=1 or players.has(id) or pending_names.has(id) or not pending_joins.has(id): return
	var rejection:=""
	if version!=connection_protocol():rejection="CQ requires the separate CQ launcher; normal clients and servers cannot join CQ sessions." if cq_profile or version.begins_with("fpsloppa-cq-") else "Version mismatch: install matching clients and server."
	elif cq_profile and spectator:rejection="CQ reserves its 64 seats for two teams; spectators are disabled."
	elif practice:rejection="This is a private practice server."
	elif bot_population.human_slots()>=max_clients:rejection="Server full (%d/%d players)."%[players.size(),max_clients]
	if not rejection.is_empty():
		server_log.record("join_rejected",{"peer":id,"reason":rejection,"players":players.size(),"capacity":max_clients})
		_rejected.rpc_id(id,rejection)
		pending_joins[id]=clock+2
		return
	server_log.phase(id,"map_offer",{"client_protocol":version,"spectator":spectator,"players":players.size(),"capacity":max_clients})
	pending_names[id] = clean_name(player_name)
	pending_spectators[id]=spectator
	pending_joins[id] = clock+240
	map_network.offer(id)

@rpc("any_peer","call_remote","reliable",0)
func _map_ready(checksum: String) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not pending_names.has(id) or checksum!=map_sha: return
	server_log.phase(id,"models_offer")
	loading.offer(id)

func _finish_join(id: int) -> void:
	replication.cached.clear()
	if not pending_names.has(id):return
	if not bot_population.make_room(id):
		_rejected.rpc_id(id,"Server filled while downloading assets.")
		pending_names.erase(id);pending_spectators.erase(id);pending_teams.erase(id)
		pending_joins[id]=clock+2
		return
	server_log.phase(id,"ready")
	server_log.join_stages.erase(id)
	var player_name: String = pending_names[id]
	pending_names.erase(id)
	pending_joins.erase(id)
	var spectator: bool=pending_spectators.get(id,false)
	pending_spectators.erase(id)
	_add_player(id,player_name,spectator)
	bot_population.maintain()
	server_log.record("player_joined",{"peer":id,"name":player_name,"spectator":spectator,"team":players[id].team})
	avatars.sync_peer(id)
	voice.policy.rpc_id(id,voice_enabled,server_name,voice_backend,mumble_url)
	announcer.policy.rpc_id(id,announcer.allowed)
	votes.offer(id)
	if dedicated and not cq_profile and max_clients>16:_announcement.rpc_id(id,preload("res://deathmatch/server/config.gd").CAPACITY_WARNING)
	_announcement.rpc(player_name+(" joined as spectator." if spectator else " joined the arena."))

@rpc("authority","call_remote","reliable",0)
func _rejected(reason: String) -> void:
	disconnect_game(reason)

func _new_state(player_name: String,id: int) -> Dictionary:
	return {"tf_class":"soldier","tf_next":"soldier","tf_tool":"sentry","tf_disguise":{},"name":clean_name(player_name),"spectator":false,"team":-1,"fly":0.0,"color":posmod(id,8),"hp":100,"armor":0,"tier":1,"ammo":[50,0,0,0],"owned":[2],"weapon":2,"kills":0,"deaths":0,"ping":0,"dead":false,"serial":0,"cooldown":0.0,"offhand_cooldown":0.0,"offhand_held":false,"offhand_fire":false,"alt_fire":false,"input_blocked":false,"weapon_zoom":false,"charge":0.0,"invulnerable":0.0,"respawn_at":0.0,"last_input":clock,"last_seq":-1,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"held":false,"slow":false,"crouch":false,"prone":false,"leg_assist":false,"chat_at":0.0,"use_at":0.0,"want_respawn":false,"jump":false,"shots":0,"melee":false,"melee_state":{},"melee_seq":-1,"left_kick":{},"right_kick":{},"melee_ready_at":0.0,"offhand_melee_state":{},"offhand_melee_seq":-1,"xr":{},"vr_device":false,"room":Vector3.ZERO,"swim":Vector3.ZERO}

func _create_fighter(id: int) -> void:
	var actor = Fighter.new()
	var team: int=players[id].team
	actor.setup(id,players[id].name,match_mode.COLORS[team] if team>=0 else COLORS[players[id].color])
	actor.set_nametag(players[id].name,team,match_mode.COLORS[team] if team>=0 else COLORS[players[id].color])
	actor.movement_sound.connect(_fighter_movement_sound.bind(id))
	actor.quake_movement = true
	actor.spectator=players[id].spectator
	add_child(actor)
	if not headless:load("res://deathmatch/maps/filtering.gd").new().apply(actor,int(presentation.get("texture_filter",2)),false)
	fighters[id] = actor

func _add_player(id: int,player_name: String,spectator: bool=false,bot_class: String="soldier") -> void:
	players[id] = _new_state(player_name,id)
	if id<0:players[id].tf_class=bot_class;players[id].tf_next=bot_class
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
	if is_instance_valid(district_gateway):district_gateway.admit(id)

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
				fighters[id].set_nametag(players[id].name,team,match_mode.COLORS[team] if team>=0 else COLORS[players[id].color])
	for id in players.keys():
		if not keep.has(id):
			fighters[id].queue_free()
			fighters.erase(id)
			players.erase(id)
			remote_interpolation.tracks.erase(id)
	var mine := multiplayer.get_unique_id()
	if players.has(mine) and not camera and not headless and not is_vr():
		camera = Camera3D.new()
		camera.position.y = 1.48
		camera.near = .04
		camera.fov = presentation.fov
		fighters[mine].add_child(camera)
		camera.top_level=true
		camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.make_current()
		menu_open = false
		if hud: hud.show_menu(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if players.has(mine):
		loading.blocking=false
		if is_vr():
			camera=xr_rig.head
			camera.make_current()
			menu_open=false
			hud.show_menu(false)
		active = true
		_flush_network_state.call_deferred()
		connect_deadline = 0
		if headless: menu_open = false
	for id in fighters:
		fighters[id].show_alive(not players[id].dead,id==mine and not dedicated)
		if avatars.choices.has(id): avatars.queue_avatar(id)
	if not multiplayer.is_server() and cq_client.enabled:cq_client.membership(cq_client.visible.map(func(id):return [id]))

func _peer_left(id: int) -> void:
	if is_instance_valid(district_gateway):district_gateway.remove(id)
	lobby.remove_peer(id)
	if id<0 and is_instance_valid(bots):bots.brains.erase(id)
	replication.cached.clear()
	input_delivery.guards.erase(id); remote_interpolation.tracks.erase(id); bandwidth.peers.erase(id)
	server_log.record("peer_departure_stage",{"peer":id,"stage":server_log.join_stages.get(id,{}),"admitted":players.has(id)})
	server_log.join_stages.erase(id)
	chainsaw.contact_at.erase(id)
	announcer.forget(id)
	match_mode.fortress.departed(id)
	server_log.record("peer_disconnected",{"peer":id})
	avatars.remove_peer(id)
	loading.pending.erase(id)
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
	if is_instance_valid(district_gateway):district_gateway.stop();district_gateway.queue_free();district_gateway=null
	cq_client.reset();cq_maps.reset()
	lobby.reset_ballot()
	replication.reset(); input_delivery.reset(); fire_delivery.reset(); remote_interpolation.reset(); bandwidth.reset(); input_paused_until=0
	if haptics:haptics.stop()
	ConnectionLog.record("disconnected",{"message":reason,"phase":loading.phase if loading else ""})
	chainsaw.reset();variant_combat.reset()
	announcer.reset();announcer.policy(false)
	join_generation+=1
	if demos.recording:demos.stop_record()
	if demos.playing:demos.stop_playback()
	server_log.record("session_closed",{"reason":reason.left(256)})
	active = false
	voice_backend="builtin";mumble_url=""
	votes.reset();votes.cooldown=0
	avatars.reset()
	voice.reset()
	loading.reset()
	map_network.reset()
	if uploads:uploads.reset()
	map_epoch=0;map_loading=false;map_rotation.clear();mode_maplists.clear();rotation_index=0
	effects.clear()
	connect_deadline = 0
	connect_addresses.clear();connect_address_index=0;connect_address_deadline=0
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for actor in fighters.values(): actor.queue_free()
	fighters.clear()
	players.clear()
	for projectile in projectiles.values():
		if is_instance_valid(projectile.node): projectile.node.queue_free()
	projectiles.clear();history.clear()
	if is_instance_valid(variant_visuals):variant_visuals.queue_free();variant_visuals=null
	var weapon_pool=get_node_or_null("Map/MapRuntime/WeaponLighting")
	if weapon_pool:weapon_pool.clear()
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
	bot_population.target=0;bot_population.count_target=-1
	practice = false
	menu_open = true
	intermission = 0
	hurt_flash=0
	camera_eye_height=1.48
	feed.clear()
	chat_feed.clear()
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
	if is_instance_valid(district_worker) and players[id].dead and district_worker.request_respawn(id):return
	match_mode.fortress.walkers.departed(id)
	players[id].jump_received=0;players[id].jump_ack=0;players[id].jump_pending=false
	var state: Dictionary = players[id]
	if state.spectator:
		state.dead=true;state.hp=0;state.ammo=[0,0,0,0];state.owned=[2];state.move=Vector2.ZERO;state.fly=0.0
		state.fire=false;state.offhand_fire=false;state.melee=false;state.want_respawn=false
		fighters[id].position=spawn_points[0]+Vector3.UP*2
		fighters[id].velocity=Vector3.ZERO;fighters[id].blast_velocity=Vector2.ZERO;fighters[id].reset_view();fighters[id].show_alive(false,id==multiplayer.get_unique_id())
		state.serial+=1
		return
	state.suicide_respawn=false
	var candidates: Array=match_mode.conquest.spawn_points(id) if match_mode.kind=="cq" else match_mode.spawns(state.team)
	if candidates.is_empty():state.dead=true;state.hp=0;state.respawn_at=clock+1;return
	var best: Vector3 = candidates[0]
	var best_score := -1.0
	for point in candidates:
		var distance := 100.0
		for other in fighters:
			if other != id and not players[other].dead: distance = minf(distance,point.distance_to(fighters[other].position))
		var score := distance+randf()*2
		if score>best_score:
			best = point
			best_score = score
	var spawn_index:int=spawn_points.find(best)
	best=preload("res://deathmatch/movement/spawn_clearance.gd").position(self,id,best)
	fighters[id].position = best
	fighters[id].velocity = Vector3.ZERO
	fighters[id].blast_velocity=Vector2.ZERO
	fighters[id].reset_view()
	fighters[id].update_height(1.65,true)
	if id==multiplayer.get_unique_id():prone_toggle=false
	fighters[id].gibbed=false
	state.merge({"hp":100,"armor":0,"tier":1,"ammo":[50,0,0,0],"owned":[2],"weapon":2,"dead":false,"melee":false,"melee_state":{},"melee_seq":-1,"left_kick":{},"right_kick":{},"melee_ready_at":0.0,"offhand_melee_state":{},"offhand_melee_seq":-1,"cooldown":.3,"offhand_cooldown":.3,"offhand_held":false,"offhand_fire":false,"alt_fire":false,"input_blocked":false,"weapon_zoom":false,"charge":0.0,"invulnerable":clock+1.5,"swim":Vector3.ZERO,"move":Vector2.ZERO,"fire":false,"held":false,"yaw":0.0,"pitch":0.0,"want_respawn":false,"crouch":false,"prone":false},true)
	armory.spawn_loadout(state)
	variant_combat.cancel_player(id)
	if not lobby.active():match_mode.special.spawn(id);match_mode.fortress.spawn(id)
	if not spawn_yaws.is_empty(): state.yaw = spawn_yaws[spawn_index]
	if match_mode.kind=="as" and not lobby.active():state.yaw=0.0 if state.team==match_mode.assault.attacking else PI
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
		if bindings.matches("prone",event) and not local_state().get("dead",true) and not local_state().get("spectator",false):prone_toggle=not prone_toggle
		if bindings.matches("crouch",event):prone_toggle=false
		var owned: Array=[0] if match_mode.fortress.walkers.mounted(multiplayer.get_unique_id()) else local_state().get("owned",[2])
		if bindings.matches("next_weapon",event):desired_weapon=W.next_owned(desired_weapon,1,owned)
		if bindings.matches("previous_weapon",event):desired_weapon=W.next_owned(desired_weapon,-1,owned)
		if bindings.matches("use",event):
			if multiplayer.is_server():_use_for(1)
			else:_use_request.rpc_id(1)
		if bindings.matches("chat",event) and hud:hud.open_chat()
		if bindings.matches("team_chat",event) and hud and voice.team_available():hud.open_chat(true)
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: fire_down = event.pressed and not menu_open
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			menu_open = not menu_open
			fire_down = false
			if hud: hud.show_menu(menu_open)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
		elif not menu_open:
			var owned: Array = [0] if match_mode.fortress.walkers.mounted(multiplayer.get_unique_id()) else local_state().get("owned",[2])
			var slots = {KEY_1:[0,1],KEY_2:[2],KEY_3:[3,4],KEY_4:[5],KEY_5:[6],KEY_6:[7],KEY_7:[8],KEY_8:[9],KEY_9:[10],KEY_0:[11]}
			if slots.has(event.physical_keycode):
				var options: Array = slots[event.physical_keycode].filter(func(w): return owned.has(w))
				if not options.is_empty(): desired_weapon = options[(options.find(desired_weapon)+1)%options.size()]

func local_state() -> Dictionary:
	if demos and demos.playing:return players.get(demos.selected_player,{})
	return players.get(multiplayer.get_unique_id(),{}) if active else {}

func request_suicide() -> void:
	if not active or demos.playing:return
	if multiplayer.is_server():_suicide_for(multiplayer.get_unique_id())
	else:_suicide_request.rpc_id(1,map_epoch,int(local_state().get("serial",-1)))

@rpc("any_peer","call_remote","reliable",0)
func _suicide_request(epoch: int,life: int) -> void:
	var sender:=multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and epoch==map_epoch and players.has(sender) and players[sender].serial==life:
		_suicide_for(sender)

func _suicide_for(id: int) -> bool:
	if is_instance_valid(district_gateway):district_gateway.action(id,"suicide");return true
	if not multiplayer.is_server() or not active or intermission>0 or lobby.active() or not players.has(id):return false
	var state: Dictionary=players[id]
	# Frozen players must still be thawed by their team; this cannot bypass FT rules.
	if state.dead or state.spectator or match_mode.special.blocked(id):return false
	# Use the normal death/flag-drop/scoring path, including its -1 suicide frag.
	_damage(id,id,100000,"SUICIDE",true)
	if state.dead:
		state.want_respawn=true;state.suicide_respawn=true
		server_log.record("suicide",{"peer":id},1)
	return state.dead

func _local_command() -> Dictionary:
	if match_mode.fortress.walkers.mounted(multiplayer.get_unique_id()):desired_weapon=0
	if is_vr():
		var command: Dictionary=xr_rig.command(sequence)
		var walkers=match_mode.fortress.walkers
		if walkers.mounted(multiplayer.get_unique_id()):
			command.fire=false;command.alt_fire=false;command.offhand_fire=false;command.melee=false
			if is_instance_valid(walkers.cockpit):command["pilot_controls"]=walkers.cockpit.sample_controls()
		return command
	var blocked: bool = menu_open or (hud != null and hud.chat.has_focus())
	var move := Vector2.ZERO if blocked else Vector2(float(bindings.pressed("right"))-float(bindings.pressed("left")),float(bindings.pressed("back"))-float(bindings.pressed("forward"))).limit_length(1)
	return {"seq":sequence,"move":move,"fly":0.0 if blocked else float(bindings.pressed("jump"))-float(bindings.pressed("down")),"yaw":local_yaw,"pitch":local_pitch,"fire":bindings.pressed("fire") and not blocked,"input_blocked":blocked,"alt_fire":not blocked and bindings.pressed("alt_fire"),"offhand_fire":armory.dual() and not blocked and bindings.pressed("offhand_fire") and desired_weapon==2,"melee":not blocked and bindings.pressed("melee"),"weapon":desired_weapon,"slow":bindings.pressed("slow"),"crouch":not blocked and bindings.pressed("crouch"),"prone":prone_toggle,"leg_assist":bindings.tracked_leg_animation,"jump":not blocked and bindings.pressed("jump"),"respawn":not blocked and (bindings.pressed("fire") or bindings.pressed("jump"))}

@rpc("any_peer","call_remote","unreliable_ordered",2)
func _input_command(command: Dictionary) -> void:
	if var_to_bytes(command).size()>8192:return
	if multiplayer.is_server() and command.get("map_epoch",-1)==map_epoch and input_delivery.allow(multiplayer.get_remote_sender_id(),clock): _accept_input(multiplayer.get_remote_sender_id(),command)

@rpc("any_peer","call_remote","unreliable_ordered",2)
func _input_packet(bytes: PackedByteArray) -> void:
	if not multiplayer.is_server() or bytes.size()>1100: return
	var id:=multiplayer.get_remote_sender_id()
	if not players.has(id) or not input_delivery.allow(id,clock): return
	var command = NetCodec.unpack(bytes,8192)
	if command is Dictionary and command.get("map_epoch",-1)==map_epoch: _accept_input(id,command)

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
	# In-flight commands still contain the entrance yaw/movement. Keep the exit
	# transform until the owner has received the new teleport serial.
	if s.has("teleport_input_life"):
		if command.get("input_life",-1)!=s.serial:return
		s.erase("teleport_input_life")
	if command.seq<=s.last_seq or command.seq>2147483647: return
	if is_instance_valid(district_gateway):district_gateway.input(id,command);return
	server_log.count("input_accepted")
	s.last_seq = command.seq
	s.last_input = clock
	var view=command.get("view_time",-1.0)
	s.view_time=float(view) if (view is float or view is int) and is_finite(float(view)) else -1.0
	input_delivery.accept(s,command)
	if match_mode.special.blocked(id):
		s.jump_pending=false;s.jump_ack=s.get("jump_received",0)
		s.fire_pending=[];s.input_blocked=true;fire_delivery.accept(s,command,clock)
		s.move=Vector2.ZERO;s.room=Vector3.ZERO;s.fire=false;s.offhand_fire=false;s.melee=false;s.jump=false;s.swim=Vector3.ZERO
		return
	s.move = command.move.limit_length(1.0)
	s.fly=preload("res://deathmatch/vr/preferences.gd").bounded(command.get("fly",0.0),-1,1,0)
	s.yaw = wrapf(command.yaw,-PI,PI)
	s.pitch = clampf(command.pitch,-1.45,1.45)
	s.fire = command.fire
	s.offhand_fire = armory.dual() and command.get("offhand_fire",false)==true
	s.alt_fire=command.get("alt_fire",false)==true
	s.input_blocked=command.get("input_blocked",false)==true
	s.melee = command.get("melee",false)==true
	s.slow = command.slow
	s.want_respawn = command.respawn
	s.jump = command.get("jump",false)==true
	s.crouch=command.get("crouch",false)==true
	s.prone=command.get("prone",false)==true
	s.leg_assist=command.get("leg_assist",false)==true
	s.physical=command.get("physical",false)==true
	s.vr_device=command.has("xr")
	s.xr=VRPoses.validate(command.get("xr",{}))
	match_mode.fortress.walkers.accept_controls(id,command.get("pilot_controls",[]))
	s.room=RoomScale.validate(command.get("room"),s.xr)
	s.swim=Vector3.ZERO
	var swim=command.get("swim",Vector3.ZERO)
	if not s.xr.is_empty() and not s.spectator and swim is Vector3 and swim.is_finite():s.swim=swim.limit_length(1.0)
	if command.has("xr") and s.xr.is_empty(): s.fire=false;s.alt_fire=false;s.melee=false;s.input_blocked=true
	fire_delivery.accept(s,command,clock)
	if s.spectator:s.fire=false;s.offhand_fire=false;s.melee=false;s.want_respawn=false
	if s.vr_device and not s.xr.has("offhand_weapon"): s.offhand_fire=false
	if not match_mode.fortress.walkers.mounted(id) and armory.valid(command.weapon) and s.owned.has(command.weapon) and command.weapon!=s.weapon and s.charge<=0:
		s.weapon = command.weapon
		s.cooldown = maxf(s.cooldown,.28)
		s.offhand_cooldown=maxf(s.offhand_cooldown,.28)
		s.offhand_held=false
		s.held = false

	match_mode.fortress.physical.sample(id)

func _physics_process(delta: float) -> void:
	# Simulation uses the engine physics delta; _process interpolates to the current display frame.
	if demos.playing:clock+=delta;demos.tick(delta);return
	clock += delta
	if connect_address_deadline>0 and clock>connect_address_deadline and connect_address_index<connect_addresses.size():_next_connect_address()
	if connect_deadline>0 and clock>connect_deadline: disconnect_game("Connection timed out. Check host, firewall and UDP port forwarding.")
	if not active: return
	if cq_maps.enabled:cq_maps.pump()
	if not multiplayer.is_server() and cq_client.waiting():cq_client.waiting_room.tick(delta);return
	if not multiplayer.is_server() and (clock<input_paused_until or cq_client.frozen):return
	var mine := multiplayer.get_unique_id()
	if players.has(mine) and not dedicated:
		sequence += 1
		var command := _local_command()
		command.map_epoch=map_epoch
		if cq_client.enabled:command.cq_generation=cq_client.generation
		command.view_time=remote_view_time
		fire_delivery.sample(command,players[mine].serial,clock)
		if multiplayer.is_server():
			command.input_life=players[mine].serial
			fire_delivery.annotate(command,clock)
			_accept_input(mine,command)
			fire_delivery.acknowledge(players[mine].serial,int(players[mine].get("fire_ack",0)))
		else:
			input_delivery.sample(command,players[mine].serial,clock)
			input_accumulator += delta
			if input_accumulator>=1.0/30:
				input_accumulator = fmod(input_accumulator,1.0/30)
				var wire:=command.duplicate()
				input_delivery.annotate(wire,clock)
				fire_delivery.annotate(wire,clock)
				_input_packet.rpc_id(1,NetCodec.pack(wire))
			if players[mine].spectator and intermission<=0:
				_move_spectator(mine,command.move,command.fly,command.yaw,command.slow,delta)
			if match_mode.special.frozen.has(mine) and intermission<=0:
				fighters[mine].simulate_frozen(delta)
			elif not players[mine].dead and not match_mode.special.blocked(mine) and not match_mode.fortress.walkers.mounted(mine) and intermission<=0:
				var room:=RoomScale.validate(command.get("room"),command.get("xr",{}))
				var speed: float=(5.2 if command.slow else 9.4)*(1.0 if lobby.active() else match_mode.fortress.speed(mine))
				fighters[mine].speed_multiplier=1.0 if lobby.active() else match_mode.fortress.speed(mine)
				_update_crouch(mine,command.get("xr",{}),command)
				fighters[mine].simulate(command.move*(1.0-minf(room.length()*30/speed,1.0)),local_yaw,command.slow,delta,command.get("jump",false),command.get("swim",Vector3.ZERO))
				if is_vr():
					var actual:=RoomScale.move_capsule(fighters[mine],room,local_yaw,delta)
					xr_rig.compensate_room_move(actual)
			fighters[mine].prediction.remember(sequence,fighters[mine].position,fighters[mine].velocity,fighters[mine].collision_height)
			_predict_shots(mine,command)

	if multiplayer.is_server():
		_server_tick(delta)
		if not is_instance_valid(district_gateway):_record_history()
		snapshot_accumulator += delta
		if snapshot_accumulator>=.05:
			snapshot_accumulator = fmod(snapshot_accumulator,.05)
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

func _predict_shots(id: int,command: Dictionary) -> void:
	if match_mode.fortress.walkers.mounted(id):return
	if armory.experimental():variant_combat.predict(id,command);return
	# Match the authority before predicting audio, flash or recoil.
	var predicted_bullets: int=players[id].ammo[0]
	for offhand in [false,true]:
		var pressed: bool=command.get("offhand_fire",false) if offhand else command.fire
		var weapon: int=players[id].weapon
		if weapon==0 and command.has("xr"):continue
		var ready: bool=(offhand_visual_cooldown if offhand else visual_cooldown)<=0
		if headless or not pressed or players[id].dead or match_mode.special.blocked(id) or intermission>0 or lobby.active() or not ready or not match_mode.fortress.can_fire(id,weapon): continue
		if offhand and weapon!=2: continue
		if weapon==2 and predicted_bullets<=0: continue
		if weapon!=1 and _weapon_blocked(id,offhand):continue
		if offhand: predicted_offhand_shot_clock=clock
		else: predicted_shot_clock=clock
		_play_shot_fx(id,weapon,offhand)
		if weapon==2: predicted_bullets-=1

func _interpolate_remote_players(delta: float) -> void:
	var mine:=multiplayer.get_unique_id()
	var view: float=remote_interpolation.advance(clock)
	if view>=0:remote_view_time=view
	elif snapshot_view_time>=0:remote_view_time=snapshot_view_time
	for id in fighters:
		if id==mine: continue
		var sample: Dictionary=remote_interpolation.sample(id)
		if not sample.is_empty():
			fighters[id].position=sample.position; fighters[id].rotation.y=sample.yaw
		else:
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
			server_log.record("join_timeout",{"peer":id,"last_stage":server_log.join_stages.get(id,{}),"transport":server_log.transport(id),"players":players.size(),"capacity":max_clients})
			multiplayer.multiplayer_peer.disconnect_peer(id)
			pending_joins.erase(id)
			pending_names.erase(id)
			loading.pending.erase(id)
			pending_spectators.erase(id)
			map_network.outgoing.erase(id)
	if map_loading:
		# Admission is per peer. Once someone is ready, their client predicts
		# movement, so the authority must simulate it too. A slow asset transfer
		# must not freeze admitted players, lobby voting or the round timer.
		if players.is_empty() and not pending_names.is_empty(): return
		map_loading=false
		_announcement.rpc("New map · "+map_title)
	bot_population.maintain()
	if is_instance_valid(district_gateway):district_gateway.advance(delta);return
	# Keep the match fresh while the dedicated server has no ready clients.
	# Pending downloads and connection timeouts still run above this gate.
	if dedicated and players.is_empty():return
	if lobby.active():
		lobby.tick(delta)
		return
	if intermission>0:
		intermission -= delta
		if intermission<=0:
			if match_mode.kind=="as" and match_mode.assault.switching:match_mode.assault.next_leg()
			elif lobby.enabled and not practice:lobby.begin()
			elif not practice and not lobby.offered.is_empty():lobby.launch()
			else:_restart_round()
		return
	var match_delta: float=match_mode.titanball.advance_time(delta) if match_mode.kind=="tb" else delta
	round_left = maxf(0,round_left-match_delta)
	if round_left<=0:
		if match_mode.kind=="as":match_mode.assault.timeout()
		elif match_mode.kind=="tb":match_mode.titanball.timeout()
		else:_end_round()
		return
	if is_instance_valid(bots) and (not is_instance_valid(district_worker) or players.keys().any(func(id):return id<0)): bots.tick(delta)
	var movement_start: Dictionary = {}
	for id in fighters:
		movement_start[id]={"position":fighters[id].position,"serial":players[id].serial,"height":fighters[id].collision_height,"yaw":fighters[id].damage_yaw()}
	for id in players:
		var s: Dictionary = players[id]
		if is_instance_valid(district_worker) and s.get("cq_wait_input",false):continue
		if s.spectator:
			if clock-s.last_input>.35:s.move=Vector2.ZERO;s.fly=0.0
			_move_spectator(id,s.move,s.fly,s.yaw,s.slow,delta)
			continue
		if match_mode.special.blocked(id):
			if match_mode.special.frozen.has(id):match_mode.special.fall(id,delta)
			continue
		if s.dead:
			if clock>=s.respawn_at and (s.want_respawn or s.get("suicide_respawn",false) or clock>s.respawn_at+3 or id<0): _spawn(id)
			continue
		if clock-s.last_input>.35:
			s.move = Vector2.ZERO
			s.room=Vector3.ZERO;s.swim=Vector3.ZERO
			s.jump=false
			s.fire = false
			s.offhand_fire=false;s.alt_fire=false;s.input_blocked=true
			s.melee = false
		var jump: bool=input_delivery.consume(s,fighters[id])
		if match_mode.fortress.walkers.handle_player(id,jump):continue
		_update_crouch(id,s.xr)
		fighters[id].speed_multiplier=match_mode.fortress.speed(id)
		fighters[id].simulate(s.move*(1.0-minf(s.room.length()*30/((5.2 if s.slow else 9.4)*fighters[id].speed_multiplier),1.0)),s.yaw,s.slow,delta,jump,s.get("swim",Vector3.ZERO))
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
		var trigger_state: Array=fire_delivery.begin_attempt(s,clock,s.weapon==6 and armory.kind in ["doom","quake"])
		if armory.experimental():variant_combat.tick_input(id,delta)
		else:
			if s.fire and s.cooldown<=0: _fire(id)
			if s.weapon==2 and s.offhand_fire and s.offhand_cooldown<=0: _fire(id,true)
		if not s.offhand_fire: s.offhand_held=false
		if not s.fire: s.held = false
		fire_delivery.end_attempt(s,trigger_state)
		_collect(id)
	_update_projectiles(delta,movement_start)
	match_mode.tick(delta)
	_respawn_pickups()
	for gate in gates:
		if gate.open and clock>gate.until:
			var clear := true
			for actor in fighters.values():
				if gate.get("elevator",false) or gate.get("bsp",false):break # Authored movers return with passengers.
				if actor.spectator:continue
				var offset: Vector3 = actor.position-gate.get("center",gate.node.position)
				offset.y = 0
				if offset.length()<1.3: clear = false
			if clear:
				_gate_state.rpc(gates.find(gate),false)

func _collect(id: int) -> void:
	if lobby.active():return
	if match_mode.fixed_loadout() or match_mode.special.blocked(id):return
	var s: Dictionary = players[id]
	if s.spectator:return
	for p in pickups:
		if not p.available or fighters[id].position.distance_to(p.position) > 1.05: continue
		if match_mode.fortress.enabled() and p.kind=="weapon":continue
		if p.get("weapon_stay",false) and p.kind=="weapon" and s.owned.has(p.item):continue
		# Bots can deliberately leave a nearby supply for a needier teammate.
		# This short-lived courtesy never restricts a human or an opposing player.
		if id<0 and is_instance_valid(bots) and bots.get("teamplay")!=null and bots.teamplay.leaving_pickup(id,p):continue
		var took := false
		match p.kind:
			"weapon":
				var ammo_type: int = armory.data(p.item).ammo
				for bonus in armory.pickup_bundle(p.item):
					if not s.owned.has(bonus):s.owned.append(bonus);took=true
				if not s.owned.has(p.item):
					s.owned.append(p.item)
					s.weapon = p.item
					s.cooldown = maxf(s.cooldown,.25)
					s.offhand_cooldown=maxf(s.offhand_cooldown,.25)
					took = true
				if ammo_type>=0 and s.ammo[ammo_type]<armory.max_ammo()[ammo_type]:
					s.ammo[ammo_type] = mini(armory.max_ammo()[ammo_type],s.ammo[ammo_type]+int(p.get("amount",[20,8,2,40][ammo_type])))
					took = true
			"ammo":
				if s.ammo[p.item]<armory.max_ammo()[p.item]:
					s.ammo[p.item] = mini(armory.max_ammo()[p.item],s.ammo[p.item]+int(p.get("amount",[50,20,5,100][p.item])))
					took = true
			"health":
				var maximum: int=match_mode.fortress.max_health(id) if match_mode.fortress.enabled() else 200 if p.item==100 else 100
				if s.hp<maximum:
					s.hp = mini(maximum,s.hp+p.item)
					took = true
			"bonus":
				if s.hp<(match_mode.fortress.max_health(id) if match_mode.fortress.enabled() else 200):
					s.hp += 1
					took = true
			"armor":
				var armor_amount: int=p.get("amount",p.item*100)
				if s.armor < armor_amount:
					s.armor = armor_amount
					s.tier = p.item
					took = true
		if took:
			if p.kind!="weapon" or not p.get("weapon_stay",false):
				p.available = false
				p.respawn = clock+(60 if p.kind=="weapon" and p.item==8 else 30)
				if match_mode.kind=="as" and p.kind=="weapon":p.respawn=clock+(p.respawn-clock)*.5
			server_log.record("pickup",{"peer":id,"kind":p.kind,"item":p.item},2)
			_pickup_event.rpc(id,p.kind,p.item,s.weapon)

func _respawn_pickups() -> void:
	if match_mode.fixed_loadout():return
	if not multiplayer.is_server():return
	for pickup in pickups:
		if not pickup.available and clock>=pickup.respawn:
			pickup.available = not match_mode.fixed_loadout()
			if powerful_pickup(pickup.kind,pickup.item):_power_spawn.rpc(pickup.position)

static func powerful_pickup(kind: String,item: int) -> bool:
	return (kind=="health" and item==100) or (kind=="armor" and item==2) or (kind=="weapon" and item==8)

static func pickup_sound(kind: String,item: int) -> String:
	if powerful_pickup(kind,item):return "pickup_mega"
	return "pickup_"+kind if kind in ["health","armor","ammo","weapon"] else "pickup_health"

@rpc("authority","call_local","reliable",0)
func _power_spawn(where: Vector3) -> void:
	if is_instance_valid(district_worker):district_worker.event("_power_spawn",[where])
	if not headless:effects.play("power_spawn",where,-5)

@rpc("authority","call_local","reliable",0)
func _pickup_event(id: int,kind: String,item: int,weapon: int) -> void:
	if is_instance_valid(district_worker):district_worker.event("_pickup_event",[id,kind,item,weapon])
	if weapon<0 or weapon>=armory.SLOT_COUNT or (kind=="weapon" and (item<0 or item>=armory.SLOT_COUNT)):return
	demos.event("_pickup_event",[id,kind,item,weapon])
	if haptics:haptics.pickup(id,kind)
	var listener: int=demos.selected_player if demos.playing else multiplayer.get_unique_id()
	if id==listener:effects.pickup(pickup_sound(kind,item))
	elif fighters.has(id):effects.play(pickup_sound(kind,item),fighters[id].position+Vector3.UP*.8,-8)
	if id==listener:
		desired_weapon = weapon
		last_event = (armory.pickup_title(item) if kind=="weapon" else kind.to_upper())+" acquired"
		if hud: hud.toast(last_event)

func _update_melee(id: int) -> void:
	if lobby.active():return
	if match_mode.fixed_loadout() or match_mode.special.blocked(id):return
	_update_melee_hand(id,false)
	_update_melee_hand(id,true)
	_update_melee_foot(id,"left")
	_update_melee_foot(id,"right")

func _begin_melee(id: int,state: Dictionary,delay: float=Melee.COOLDOWN,block_fire: bool=true) -> void:
	var s: Dictionary=players[id]
	s.melee_ready_at=clock+delay
	for other in [s.melee_state,s.offhand_melee_state,s.get("left_kick",{}),s.get("right_kick",{})]:
		if not is_same(other,state):other.swing_until=0.0
	s.invulnerable=0
	if block_fire:
		s.cooldown=maxf(s.cooldown,.3);s.offhand_cooldown=maxf(s.offhand_cooldown,.3)

func _update_melee_foot(id: int,side: String) -> void:
	var s: Dictionary=players[id]
	if not s.vr_device:return
	var key:=side+"_kick"
	if not s.has(key):s[key]={}
	var state: Dictionary=s[key]
	if s.get("melee_ready_at",0.0)>clock:state.ready_at=maxf(state.get("ready_at",0.0),s.melee_ready_at)
	if not multiplayer.is_server() or not s.vr_device or not s.melee or s.dead or intermission>0 or clock-s.last_input>.35 or s.charge>0 or s.xr.is_empty():
		Melee.reset_motion(state);return
	if state.get("seq",-1)==s.last_seq:return
	state.seq=s.last_seq
	var swing:=Melee.sample_foot(state,s.xr,clock,side)
	if swing.is_empty():return
	if swing.started:_begin_melee(id,state,Melee.COOLDOWN,false)
	var frame:=Transform3D(Basis(Vector3.UP,s.yaw),fighters[id].position)*Transform3D(Basis.IDENTITY,s.xr.head.origin)
	var body: Vector3=fighters[id].position+Vector3.UP*fighters[id].torso_height()
	for segment in swing.segments:
		var start: Vector3=frame*segment[0];var end: Vector3=frame*segment[1]
		if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body,start,1)).is_empty():continue
		var hit:=_trace(start,end,id,0,Melee.KICK_RADIUS)
		if hit.id==0:continue
		if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body,hit.position,1)).is_empty():continue
		state.hit=true
		s.cooldown=maxf(s.cooldown,.3);s.offhand_cooldown=maxf(s.offhand_cooldown,.3)
		_damage(hit.id,id,Melee.DAMAGE,"KICK",false,hit.position,(end-start).normalized())
		return

func _update_melee_hand(id: int,offhand: bool) -> void:
	if match_mode.fixed_loadout() or match_mode.special.blocked(id):return
	var s: Dictionary=players[id]
	var state: Dictionary=s.offhand_melee_state if offhand else s.melee_state
	var other: Dictionary=s.melee_state if offhand else s.offhand_melee_state
	if s.get("melee_ready_at",0.0)>clock:state.ready_at=maxf(state.get("ready_at",0.0),s.melee_ready_at)
	if other.has("ready_at"): state.ready_at=maxf(state.get("ready_at",0.0),other.ready_at)
	if offhand and (not s.vr_device or s.weapon!=2 or not s.xr.has("offhand_weapon")):
		Melee.reset_motion(state);return
	if not multiplayer.is_server() or not s.melee or s.dead or intermission>0 or clock-s.last_input>.35 or s.charge>0:
		Melee.reset_motion(state)
		return
	var axe: bool=s.vr_device and armory.effective()=="quake" and s.weapon in [0,1]
	var delay: float=armory.data(s.weapon).cycle if axe else Melee.COOLDOWN
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
		var tip: Vector3=Art.muzzle(s.weapon,"quake")*Art.VR_SCALE if axe else Vector3(0,0,-Melee.WEAPON_LENGTH)
		var swing:=Melee.sample(state,pose,clock,s.weapon,tip,delay)
		if swing.is_empty(): return
		started=swing.started;segments=swing.segments
		frame=Transform3D(Basis(Vector3.UP,s.yaw),fighters[id].position)*Transform3D(Basis.IDENTITY,s.xr.head.origin)
	else:
		if clock<state.get("ready_at",0.0): return
		state.ready_at=clock+Melee.COOLDOWN;state.hit=false;started=true
		var weapon:=_weapon_transform(id)
		segments.append([weapon.origin,weapon*Vector3(0,0,-Melee.DESKTOP_REACH)])
	if started:
		# Re-aiming a tracked gun can resemble a weapon whip. Only actual
		# contact should interrupt shooting; explicit melee and axes keep
		# their normal wind-up lock even when the swing misses.
		_begin_melee(id,state,delay,not s.vr_device or axe or s.weapon<2)
		_melee_fx.rpc(id,offhand)
	var body: Vector3=fighters[id].position+Vector3.UP*fighters[id].torso_height()
	for segment in segments:
		var start: Vector3=frame*segment[0]
		var end: Vector3=frame*segment[1]
		if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body,start,1)).is_empty(): continue
		var hit:=_trace(start,end,id,0,Melee.RADIUS)
		if hit.id==0 and not (axe and hit.has("building")): continue
		if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body,hit.position,1)).is_empty(): continue
		state.hit=true
		s.cooldown=maxf(s.cooldown,.3);s.offhand_cooldown=maxf(s.offhand_cooldown,.3)
		var damage: int=armory.data(s.weapon).damage if axe else Melee.DAMAGE
		if hit.has("building"):match_mode.fortress.damage_building(hit.building,id,damage)
		else:_damage(hit.id,id,damage,"AXE" if axe else "WEAPON WHIP",false,hit.position,(end-start).normalized())
		return

func _fire(id: int, offhand: bool=false) -> void:
	if armory.experimental():variant_combat.fire(id,offhand);return
	if lobby.active():return
	if match_mode.special.blocked(id):return
	if not multiplayer.is_server() or not players.has(id) or players[id].dead or intermission>0: return
	if offhand and (players[id].weapon!=2 or (players[id].vr_device and not players[id].xr.has("offhand_weapon"))): return
	var s: Dictionary = players[id]
	var w: int = s.weapon
	if w==0 and s.vr_device:return # VR fists use physical melee, not trigger hitscan.
	if (s.offhand_cooldown if offhand else s.cooldown)>0: return
	# Clearance sweeps run only for a ready shot, then share the result with launch.
	var shot: Dictionary={} if w==1 else _shot_solution(id,offhand)
	if shot.get("blocked",false):return
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
	if w>=2:match_mode.fortress.revealed(id)
	s.invulnerable = 0
	s.shots += 1
	_shot_fx.rpc(id,w,offhand)
	if w==1:
		chainsaw.fire(self,id);s.held=true;return
	if w==8:
		s.charge = d.charge
	elif w>=6 and w<=8 and not (match_mode.fortress.enabled() and s.get("tf_class","")=="pyro" and w==7):
		_launch(id,w,shot)
	else:
		var start: Vector3 = shot.origin
		var endpoints := PackedVector3Array()
		if w==9:
			var end: Vector3=start-_weapon_transform(id).basis.z*d.range
			var wall:=HitDetection.world_fraction(get_world_3d().direct_space_state,start,end,0.0)
			var hull_pilot: int=match_mode.fortress.walkers.trace_pilot(start,end,0.,wall)
			end=start.lerp(end,minf(1.0,wall))
			if hull_pilot!=0 and hull_pilot!=id:_damage(hull_pilot,id,d.damage,"RAILGUN",false,end,(end-start).normalized(),false,true)
			var rewound:=_rewound_positions(_shot_rewind(id))
			var heights:=_rewound_heights(_shot_rewind(id))
			var yaws:=_rewound_yaws(_shot_rewind(id))
			for target in players:
				if target==id or players[target].dead or players[target].spectator or match_mode.fortress.walkers.mounted(target):continue
				var target_pos: Vector3=rewound.get(target,fighters[target].position)
				var height: float=heights.get(target,fighters[target].collision_height)
				var yaw: float=yaws.get(target,fighters[target].damage_yaw())
				var fraction:=HitDetection.player_fraction(start-target_pos,end-target_pos,height,yaw)
				if fraction<=1.0:
					var impact:=start.lerp(end,fraction)
					var axis:=target_pos+HitDetection.player_axis(impact-target_pos,height,yaw)
					if get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(impact,axis,1)).is_empty():
						_damage(target,id,d.damage,"RAILGUN",false,impact,(end-start).normalized())
			var structure: Dictionary=match_mode.fortress.trace(start,end,1.0)
			if not structure.is_empty():match_mode.fortress.damage_building(structure.key,id,d.damage)
			_impacts.rpc(start,PackedVector3Array([end]),w)
			s.held=true
			return
		for pellet in range(d.pellets):
			var spread: float = 0.0 if (w==2 or w==5) and not (s.offhand_held if offhand else s.held) else d.spread
			var accuracy: float=fighters[id].accuracy_scale() if d.range>3.0 and d.name!="FLAMETHROWER" else 1.0
			spread*=accuracy
			var yaw: float = s.yaw+deg_to_rad((randf()-randf())*spread)
			var pitch: float = s.pitch+deg_to_rad((randf()-randf())*d.vertical*accuracy)
			var direction := W.direction(yaw,pitch)
			if not s.xr.is_empty():
				direction=_weapon_transform(id,offhand).basis*W.direction(yaw-s.yaw,pitch-s.pitch)
			var hit := _trace(start,start+direction*d.range,id,_shot_rewind(id))
			endpoints.append(hit.position)
			var amount: int=d.damage*randi_range(1,d.dice)
			_damage_map_hit(hit,id,amount)
			if hit.id!=0:
				_damage(hit.id,id,amount,d.name,false,hit.position,direction,false,hit.get("vehicle",false) and d.range>3 and d.name!="FLAMETHROWER")
				if d.name=="FLAMETHROWER":match_mode.fortress.ignite(hit.id,id)
			if hit.has("building"):match_mode.fortress.damage_building(hit.building,id,amount)
		if d.name=="FLAMETHROWER":_ability_fx.rpc("flame",start,endpoints[0],s.team)
		else:_impacts.rpc(start,endpoints,w)
	if offhand: s.offhand_held=true
	else: s.held = true

func _trace(start: Vector3,end: Vector3,exclude: int,rewind: float = 0.0,radius: float = 0.0,movement_start: Dictionary = {},candidates: Variant = null) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var wall_fraction := HitDetection.world_fraction(space,start,end,radius)
	var nearest := wall_fraction
	var point := start.lerp(end,minf(1.0,nearest))
	var hull_pilot: int=match_mode.fortress.walkers.trace_pilot(start,end,radius,wall_fraction)
	var target := hull_pilot if hull_pilot!=exclude else 0
	var old:=_rewound_positions(rewind)
	var heights:=_rewound_heights(rewind)
	var yaws:=_rewound_yaws(rewind)
	var head_hit:=false
	for id in (players if candidates==null else candidates):
		if id==exclude or players[id].dead or players[id].spectator or match_mode.fortress.walkers.mounted(id): continue
		var position: Vector3 = old.get(id,fighters[id].position)
		var previous: Vector3 = position
		if movement_start.has(id) and movement_start[id].serial==players[id].serial:
			previous=movement_start[id].position
		var height: float=heights.get(id,fighters[id].collision_height)
		if movement_start.has(id) and movement_start[id].serial==players[id].serial:height=maxf(height,movement_start[id].get("height",height))
		var yaw: float=yaws.get(id,fighters[id].damage_yaw())
		# Relative motion catches targets crossing the projectile between ticks.
		var fraction := HitDetection.player_fraction(start-previous,end-position,height,yaw,radius)
		if fraction<nearest:
			var impact := start.lerp(end,fraction)
			var target_at := previous.lerp(position,fraction)
			var axis := target_at+HitDetection.player_axis(impact-target_at,height,yaw)
			# Expanded damage volumes must not reach through thin walls/corners.
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(impact,axis,1)).is_empty(): continue
			nearest=fraction
			point=impact
			target=id
			head_hit=HitDetection.player_head(impact-target_at,height,yaw,radius)
	var structure: Dictionary=match_mode.fortress.trace(start,end,nearest,radius)
	if not structure.is_empty():return {"id":0,"building":structure.key,"position":start.lerp(end,structure.fraction),"hit":true}
	var result:={"id":target,"position":point,"headshot":head_hit,"hit":target!=0 or is_finite(wall_fraction),"vehicle":target!=0 and target==hull_pilot}
	# Shootable trigger volumes participate in damage traces, without blocking movement.
	var query:=PhysicsRayQueryParameters3D.create(start,point+(end-start).normalized()*.04,1)
	query.collide_with_areas=true
	var contact:=space.intersect_ray(query)
	if not contact.is_empty() and (target==0 or start.distance_to(contact.position)<start.distance_to(point)):
		var runtime=get_node_or_null("Map/MapRuntime")
		if runtime and runtime.triggers.rows.has(contact.collider):
			result["map_node"]=contact.collider
			if contact.collider is Area3D:result.id=0;result.vehicle=false;result.hit=true;result.position=contact.position
	return result

func _damage_map_hit(hit: Dictionary,id: int,amount: float) -> void:
	if not multiplayer.is_server() or not hit.has("map_node"):return
	var runtime=get_node_or_null("Map/MapRuntime")
	if runtime:runtime.triggers.damage(hit.map_node,id,amount)

func _launch(id: int,weapon: int,solution: Dictionary={}) -> void:
	if not players.has(id) or players[id].dead: return
	if solution.is_empty():solution=_shot_solution(id)
	if solution.blocked or (players[id].vr_device and players[id].xr.is_empty()): return
	var s: Dictionary = players[id]
	var start: Vector3 = solution.origin
	var direction := -_weapon_transform(id).basis.z
	var shot_yaw:=atan2(-direction.x,-direction.z)
	var shot_pitch:=asin(clampf(direction.y,-1,1))
	projectile_id += 1
	_projectile_spawn.rpc(projectile_id,id,weapon,start,direction,shot_yaw,shot_pitch)

@rpc("authority","call_local","reliable",0)
func _projectile_spawn(id: int,owner_id: int,weapon: int,pos: Vector3,direction: Vector3,yaw: float,pitch: float,extra: Dictionary={}) -> void:
	if is_instance_valid(district_worker):district_worker.event("_projectile_spawn",[id,owner_id,weapon,pos,direction,yaw,pitch,extra])
	if not armory.valid(weapon):return
	if projectiles.has(id):return
	if not multiplayer.is_server() and (ended_projectiles.has(id) or (id<=projectile_watermark and not id in snapshot_projectiles)):return
	var definition: Dictionary=variant_combat.definition(owner_id,weapon,extra) if armory.experimental() else {}
	var node: Node3D = null
	if not headless:
		var visual_definition: Dictionary=definition.duplicate() if armory.experimental() else W.DATA[weapon].duplicate()
		if not visual_definition.has("kind"):visual_definition.kind=preload("res://deathmatch/lighting/weapon_emission.gd").kind("doom",weapon)
		node=_weapon_visuals().projectile(armory.effective(),visual_definition)
		# This node is positioned in the render loop. Mixing that with engine
		# physics interpolation adds another delay and can interpolate its spawn
		# from the scene origin. Interpolate the authoritative samples explicitly.
		node.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(node);node.position=pos;node.set_meta("trail_position",pos)
		if absf(direction.dot(Vector3.UP))<.99:node.look_at(pos+direction)
	projectiles[id] = {"owner":owner_id,"weapon":weapon,"position":pos,"direction":direction,"life":4.0,"node":node,"yaw":yaw,"pitch":pitch,"fresh":true,"visual_error":Vector3.ZERO,"visual_age":0.0}
	projectiles[id].previous_position=pos
	if multiplayer.is_server() and owner_id==multiplayer.get_unique_id() and is_vr() and xr_rig.gun_id==weapon:
		var visible_start: Vector3=xr_rig.gun.global_transform*Art.muzzle(weapon,match_mode.fortress.art_rules(owner_id,weapon))
		if visible_start.distance_to(pos)<.75 and get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(visible_start,pos,1)).is_empty():
			projectiles[id].previous_position=visible_start
	if not definition.is_empty():projectiles[id].merge({"definition":definition,"extra":extra,"velocity":direction*definition.speed,"life":definition.fuse,"stuck":false},true)

func _update_projectiles(delta: float,movement_start: Dictionary = {}) -> void:
	if projectiles.is_empty():return
	var targets:=ProjectileTargets.new()
	targets.build(players,fighters,movement_start)
	for id in projectiles.keys():
		if not projectiles.has(id):continue
		var p: Dictionary = projectiles[id]
		if not p.fresh:p.previous_position=p.position
		if p.has("definition"):variant_combat.tick_projectile(id,delta,movement_start,targets);continue
		p.life -= delta
		var end: Vector3 = p.position+p.direction*W.DATA[p.weapon].speed*delta
		# New shots originate after this tick's movement: do not hit a past crossing.
		var radius:float=W.DATA[p.weapon].radius
		var hit := _trace(p.position,end,p.owner,0.0,radius,{} if p.fresh else movement_start,targets.candidates(p.position,end,radius))
		p.fresh=false
		if hit.hit or p.life<=0:
			var d: Dictionary = W.DATA[p.weapon]
			_damage_map_hit(hit,p.owner,d.damage)
			if hit.id!=0: _damage(hit.id,p.owner,d.damage*randi_range(1,d.dice),d.name,false,hit.position,p.direction,false,hit.get("vehicle",false))
			if hit.has("building"):match_mode.fortress.damage_building(hit.building,p.owner,d.damage*randi_range(1,d.dice))
			if p.weapon==6: _blast(hit.position,p.owner,128,5.76,"ROCKET LAUNCHER",hit.id if hit.get("vehicle",false) else 0)
			if p.weapon==8:_blast(hit.position,p.owner,W.BFG_SPLASH_DAMAGE,W.BFG_SPLASH_RADIUS,"BFG 9000",hit.id if hit.get("vehicle",false) else 0)
			if p.weapon==8 and players.has(p.owner):
				var origin: Vector3 = fighters[p.owner].position+Vector3.UP*minf(1.45,fighters[p.owner].collision_height-.15)
				for ray in range(40):
					var dir := W.direction(p.yaw+deg_to_rad(-45+90.0*ray/39),p.pitch)
					var target := _trace(origin,origin+dir*46,p.owner)
					if target.id!=0:
						var damage := 0
						for die in range(15): damage += randi_range(1,8)
						_damage(target.id,p.owner,damage,"BFG 9000",false,target.position,dir,false,target.get("vehicle",false))
			_projectile_end.rpc(id,hit.position,p.weapon)
		else: p.position = end

func _blast(pos: Vector3,owner_id: int,damage: int,radius: float,weapon_name: String="ROCKET LAUNCHER",hull_impact: int=0) -> void:
	if lobby.active():return
	if not multiplayer.is_server() or intermission>0:return
	match_mode.fortress.blast(pos,owner_id,damage,radius)
	var map_runtime=get_node_or_null("Map/MapRuntime")
	if map_runtime:map_runtime.triggers.blast(pos,owner_id,damage,radius)
	for id in players:
		if players[id].dead or players[id].spectator or players[id].invulnerable>clock: continue
		if match_mode.special.frozen.has(id):continue
		if not match_mode.fortress.walkers.accepts_explosion(id,pos,hull_impact):continue
		if id==owner_id and weapon_name=="BFG 9000":continue
		if id!=owner_id and match_mode.same_team(id,owner_id) and not match_mode.friendly_fire:continue
		var target: Vector3 = fighters[id].position+Vector3.UP*(.85 if fighters[id].collision_height>=1.65 else fighters[id].collision_height*.5)
		target=match_mode.fortress.walkers.blast_target(id,pos,target)
		var distance := maxf(0,pos.distance_to(target)-.3)
		if distance>=radius: continue
		var query := PhysicsRayQueryParameters3D.create(pos+(target-pos).normalized()*.06,target,1)
		if not match_mode.fortress.walkers.blast_reaches(id,get_world_3d().direct_space_state.intersect_ray(query)):continue
		var falloff:=1.0-distance/radius
		var push:Vector3=(target-pos).normalized()
		if push.length_squared()<.01:push=Vector3.UP
		fighters[id].apply_blast(push*15.0*falloff)
		# Self splash costs health but permits a healthy player to rocket jump.
		_damage(id,owner_id,maxi(1,int(damage*falloff*(.5 if id==owner_id else 1.0))),weapon_name,false,target,push,true,match_mode.fortress.walkers.mounted(id))

func _damage(victim: int,attacker: int,amount: int,weapon_name: String,bypass: bool = false,impact: Vector3=Vector3.INF,direction: Vector3=Vector3.ZERO,blast: bool=false,hull_contact: bool=false,heavy_automatic: bool=false) -> void:
	if lobby.active():return
	if not multiplayer.is_server() or not players.has(victim): return
	var s: Dictionary = players[victim]
	# Seated players receive combat damage only through a verified hull impact.
	# Administrative death/suicide still works through the existing bypass path.
	if match_mode.fortress.walkers.mounted(victim) and not bypass and not hull_contact:return
	var telefrag:=weapon_name=="TELEFRAG" and bypass
	if s.spectator or s.dead or (match_mode.special.blocked(victim) and not (telefrag and match_mode.special.frozen.has(victim))) or intermission>0 or (s.invulnerable>clock and not bypass): return
	if attacker!=victim and match_mode.same_team(victim,attacker) and not match_mode.friendly_fire and not telefrag: return
	if not bypass and match_mode.fortress.walkers.heavy_ordnance_only and match_mode.fortress.walkers.mounted(victim) and not match_mode.fortress.walkers.accepts_pilot_weapon(weapon_name,heavy_automatic):
		server_log.record("titan_hull_blocked",{"victim":victim,"attacker":attacker,"weapon":weapon_name,"raw_damage":amount,"blast":blast},2)
		return
	amount=match_mode.fortress.outgoing_damage(attacker,victim,amount,weapon_name)
	amount=match_mode.fortress.incoming_damage(victim,amount,weapon_name,bypass)
	match_mode.fortress.walkers.enforce_pilot(victim)
	var damage := Vector2i(amount,s.armor) if match_mode.instagib() or weapon_name=="CIRCUS HUNGER" else W.armor_damage(amount,s.armor,s.tier)
	var old_armor: int=s.armor
	var old_hp: int=s.hp
	s.hp = maxi(0,s.hp-damage.x)
	s.armor = damage.y
	match_mode.fortress.walkers.enforce_pilot(victim)
	if weapon_name in ["FIST","AXE","IMPACT HAMMER","CHAINSAW","WEAPON WHIP","KICK"] and (s.hp<old_hp or s.armor<old_armor):
		match_mode.fortress.revealed(attacker)
	match_mode.special.heal(attacker,victim,old_hp-s.hp,weapon_name)
	if s.hp==0 and match_mode.freeze_tag() and not bypass:
		if attacker!=victim and players.has(attacker):_hit_confirm.rpc(attacker)
		_hurt_fx.rpc(victim,fighters[victim].position+Vector3.UP,direction,damage.x,false,false,randi(),false,weapon_name,blast)
		match_mode.special.freeze(victim,attacker)
		return
	if attacker!=victim and players.has(attacker): _hit_confirm.rpc(attacker)
	if not impact.is_finite(): impact=fighters[victim].position+Vector3.UP
	if direction.length()<.1 and fighters.has(attacker): direction=(fighters[victim].position-fighters[attacker].position).normalized()
	var gibbed: bool=s.hp==0 and (damage.x-old_hp>=25 or weapon_name in ["ROCKET LAUNCHER","BFG 9000","TITAN CRUSH"])
	server_log.record("damage",{"victim":victim,"attacker":attacker,"damage":damage.x,"remaining_hp":s.hp,"remaining_armor":s.armor,"weapon":weapon_name,"fatal":s.hp==0,"gibbed":gibbed,"blast":blast,"hull_contact":hull_contact},2)
	if s.hp==0 and match_mode.fortress.walkers.mounted(victim):
		s.dead=true;match_mode.fortress.walkers.leave(victim,true)
	_hurt_fx.rpc(victim,impact,direction,damage.x,s.hp==0,gibbed,randi(),weapon_name=="CIRCUS HUNGER",weapon_name,blast)
	if s.hp>0: return
	var already_frozen: bool=telefrag and match_mode.special.frozen.has(victim)
	s.dead = true
	if telefrag:match_mode.special.frozen.erase(victim)
	if not already_frozen:s.deaths += 1
	s.fire = false
	s.charge = 0
	s.respawn_at = clock+2
	if already_frozen:return # A frozen victim already awarded its death and frag.
	var killer: String = s.name
	if players.has(attacker):
		killer = players[attacker].name
	announcer.killed(victim,attacker)
	match_mode.killed(victim,attacker)
	_announcement.rpc("%s  →  %s   ·   %s" % [killer,s.name,weapon_name])

func _end_round() -> void:
	if intermission>0:return
	intermission = 10
	votes.ballot.clear()
	var winner := "No winner"
	var score := -999
	for s in players.values():
		if s.spectator:continue
		if s.kills>score:
			score = s.kills
			winner = s.name
	round_message = "%s wins · %d frags" % [winner,score] if score>-999 else "Round ended · no active players"
	if match_mode.team_game():round_message=match_mode.result()
	if not practice and votes.enabled:lobby.prepare()
	lobby.last_results=preload("res://deathmatch/modes/scoreboard_data.gd").capture(self)
	server_log.record("round_ended",{"result":round_message,"team_scores":match_mode.scores})
	_announcement.rpc(round_message)
	_round_end_gong.rpc(map_epoch)

@rpc("authority","call_local","reliable",0)
func _round_end_gong(epoch: int) -> void:
	if epoch==map_epoch and is_instance_valid(round_clock):round_clock.play_gong()

func _restart_round() -> void:
	lobby.reset_ballot()
	announcer.reset_scores()
	intermission=0
	if map_rotation.size()>1:
		var next_index: int=(rotation_index+1)%map_rotation.size()
		if map_rotation[next_index]!=current_map:
			if _rotate_map(map_rotation[next_index]): rotation_index=next_index;return
		else: rotation_index=next_index
	if is_instance_valid(district_gateway):district_gateway.resetting=true
	match_mode.reset()
	round_left = time_limit
	round_message = ""
	for id in players:
		players[id].kills = 0
		players[id].deaths = 0
		_spawn(id)
	for p in pickups: p.available = not match_mode.fixed_loadout()
	for id in projectiles.keys(): _projectile_end.rpc(id,projectiles[id].position,7)
	history.clear()
	remote_view_time=-1.0;snapshot_view_time=-1.0;projectile_watermark=-1;snapshot_projectiles.clear();ended_projectiles.clear()
	if is_instance_valid(district_gateway):district_gateway.reset_round()
	_announcement.rpc("New round · "+match_mode.status())

func _history_positions() -> Dictionary:
	var positions: Dictionary={}
	for id in players:positions[id]={"position":fighters[id].position,"serial":players[id].serial,"height":fighters[id].collision_height,"yaw":fighters[id].damage_yaw()}
	return positions
func _record_history() -> void:
	history.append({"time":clock,"positions":_history_positions()})
	while history.size()>2 and history[1].time<clock-LagCompensation.MAX_REWIND-.05:history.pop_front()
func _rewound_positions(rewind: float) -> Dictionary:
	# Projectiles and local shots use current positions. Avoid building a complete
	# player-history dictionary only for LagCompensation to immediately discard it.
	if rewind<=0 or history.is_empty():return {}
	return LagCompensation.positions(history,clock,rewind,_history_positions())
func _rewound_heights(rewind: float) -> Dictionary:
	if rewind<=0 or history.is_empty():return {}
	return LagCompensation.positions(history,clock,rewind,_history_positions(),true)
func _rewound_yaws(rewind: float) -> Dictionary:
	if rewind<=0 or history.is_empty():return {}
	return LagCompensation.positions(history,clock,rewind,_history_positions(),false,true)
func _shot_rewind(id: int) -> float:
	if id<=1:return 0.0 # Local host and bots see the authoritative world.
	var s: Dictionary=players[id]
	return LagCompensation.delay(clock,s.ping,s.get("view_time",-1.0),s.last_input)

func asset_allowance(peer: int, requested: int) -> int:
	var active_peers: Dictionary={}
	for id in map_network.outgoing:active_peers[id]=true
	for id in avatars.outgoing:active_peers[id]=true
	var outstanding:=0
	for service in [map_network,avatars]:
		if service.outgoing.has(peer):
			var row: Dictionary=service.outgoing[peer]
			outstanding+=int(row.sent)-int(row.ack)+int(row.get("reading_bytes",0))
	var rtt:=0.0
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer and peer in multiplayer.get_peers():
		rtt=multiplayer.multiplayer_peer.get_peer(peer).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	return bandwidth.claim(peer,requested,clock,active_peers.size(),rtt,outstanding)

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
	var mode_state: Dictionary=match_mode.snapshot();mode_state["lobby"]=lobby.snapshot()
	mode_state["weapon_rules"]=armory.kind
	if not variant_combat.charging.is_empty():mode_state["weapon_charge"]=variant_combat.charge_snapshot()
	mode_state["ordnance"]={}
	for id in projectiles:
		var p: Dictionary=projectiles[id]
		if p.has("definition"):mode_state.ordnance[id]={"extra":p.extra,"velocity":p.velocity,"life":p.life,"stuck":p.stuck}
	var bsp_runtime=get_node_or_null("Map/MapRuntime")
	if bsp_runtime and not bsp_runtime.triggers.killed_targets.is_empty():mode_state["bsp_killed"]=bsp_runtime.triggers.killed_targets
	mode_state["map_movers"]=[]
	for i in gates.size():
		if gates[i].get("bsp",false):mode_state.map_movers.append([i,gates[i].node.position])
	mode_state["elevators"]=[]
	for i in gates.size():
		if gates[i].get("elevator",false):mode_state.elevators.append([i,gates[i].node.position])
	mode_state["locomotion"]={}
	for id in fighters:
		input_delivery.sync_life(players[id])
		fire_delivery.sync_life(players[id])
		mode_state.locomotion[id]=fighters[id].locomotion_state()
		mode_state.locomotion[id]["jump_ack"]=players[id].get("jump_ack",0)
		mode_state.locomotion[id]["fire_ack"]=players[id].get("fire_ack",0)
	mode_state["movement_ack"]={}
	for id in players:mode_state.movement_ack[id]=players[id].last_seq
	var state: Array=[data,items,round_left,intermission,round_message,frag_limit,time_limit,shots,gate_states,map_epoch,mode_state,votes.snapshot(),clock,projectile_id]
	if is_instance_valid(district_gateway):district_gateway.replicate(state);return
	callv("_snapshot",state)
	if not multiplayer.get_peers().is_empty():
		var packets: Dictionary = replication.packets(state)
		for bytes in packets.normal:
			bandwidth.reserve((bytes.size()+64)*multiplayer.get_peers().size(),clock); _state_packet.rpc(bytes)
		for bytes in packets.large:
			bandwidth.reserve((bytes.size()+64)*multiplayer.get_peers().size(),clock); _state_large.rpc(bytes)

@rpc("authority","call_remote","unreliable",1)
func _state_packet(bytes: PackedByteArray) -> void:
	if not map_loading and replication.receive(bytes,map_epoch) and not network_flush_pending:
		network_flush_pending=true; _flush_network_state.call_deferred()

@rpc("authority","call_remote","reliable",7)
func _state_large(bytes: PackedByteArray) -> void:
	if not map_loading and replication.receive(bytes,map_epoch) and not network_flush_pending:
		network_flush_pending=true; _flush_network_state.call_deferred()

func _flush_network_state() -> void:
	network_flush_pending=false
	if not active or map_loading or multiplayer.is_server() or demos.playing:return
	var received: Array=replication.flush()
	if not received.is_empty():callv("_snapshot",received)

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
	if not multiplayer.is_server():cq_client.membership(data)
	var was_frozen: bool=match_mode.special.frozen.has(multiplayer.get_unique_id())
	if not multiplayer.is_server():
		snapshot_view_time=server_time
		if remote_view_time<0:remote_view_time=server_time
		projectile_watermark=maxi(projectile_watermark,shot_watermark)
		snapshot_projectiles=shots.map(func(shot):return shot[0])
	lobby.view=mode_state.get("lobby",{}).duplicate(true)
	demos.capture([data,items,remaining,pause,message,limit,duration,shots,gate_states,epoch,mode_state,vote_state])
	if not multiplayer.is_server():match_mode.receive(mode_state);votes.view=vote_state
	if mode_state.get("weapon_rules",armory.kind)!=armory.kind:armory.select(mode_state.weapon_rules)
	variant_combat.charge_view=mode_state.get("weapon_charge",{})
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
			if id!=mine:
				actor.velocity.x+=actor.blast_velocity.x-old_blast.x;actor.velocity.z+=actor.blast_velocity.y-old_blast.y
			s.respawn_at = clock+row[15]
			s.invulnerable = clock+1 if row[16] else 0
			actor.target = row[1]
			actor.target_yaw = row[3]
			if id!=mine:
				remote_interpolation.push(id,float(mode_state.get("sample_time",{}).get(id,server_time)),row[1],row[2],row[3],row[14],clock)
			if id==mine and actor.spawn_serial==row[14]:
				if not was_frozen and match_mode.special.frozen.has(id):
					# Begin passive falling at the freeze location, discarding pre-hit
					# movement history so reconciliation cannot restore a jump.
					actor.position=row[1];actor.velocity=row[2];actor.reset_view()
				else:
					var locomotion: Dictionary=mode_state.get("locomotion",{}).get(id,{})
					actor.prediction.reconcile(actor,int(mode_state.get("movement_ack",{}).get(id,-1)),row[1],row[2],float(locomotion.get("height",-1.0)),locomotion.get("grounded",false))
		if actor.spawn_serial!=row[14]:
			actor.spawn_serial = row[14]
			actor.gibbed=false
			if not headless and not s.spectator: effects.play("spawn",row[1],-6)
			actor.position = row[1]
			actor.velocity = row[2]
			actor.reset_view()
			if id==mine:
				prone_toggle=false
				local_yaw = row[3]
				local_pitch = 0
				desired_weapon = row[8]
				if is_vr(): xr_rig.on_spawn()
		# The owner samples tracking every render frame; network echoes are older.
		if id!=mine or demos.playing or multiplayer.is_server() or not is_vr():
			actor.xr_pose=row[18] if row.size()>18 else {}
			if not multiplayer.is_server() and (id!=mine or demos.playing or not is_vr() and actor.prediction.samples.is_empty()):actor.receive_locomotion(mode_state.get("locomotion",{}).get(id,{}))
		if not multiplayer.is_server(): s.xr=actor.xr_pose
		actor.visual_velocity = row[2]
		if id!=mine or demos.playing:actor.visual_grounded=mode_state.get("locomotion",{}).get(id,{}).get("grounded",absf(row[2].y)<.5)
		if not multiplayer.is_server():actor.tracked_leg_animation=mode_state.get("locomotion",{}).get(id,{}).get("assist",false)
		actor.visual_pitch = row[4]
		actor.visual_weapon = row[8]
		actor.spectator=s.spectator
		actor.show_alive(not s.dead,id==mine and not dedicated)
		if id==mine:
			input_delivery.acknowledge(row[14],int(mode_state.get("locomotion",{}).get(id,{}).get("jump_ack",0)))
			fire_delivery.acknowledge(row[14],int(mode_state.get("locomotion",{}).get(id,{}).get("fire_ack",0)))
			last_local_hp = s.hp
	for i in range(mini(items.size(),pickups.size())):
		if not multiplayer.is_server(): pickups[i].available = items[i]==1
		if is_instance_valid(pickups[i].node): pickups[i].node.visible = items[i]==1 and not match_mode.fixed_loadout()
	for shot in shots:
		if multiplayer.is_server(): continue
		if not projectiles.has(shot[0]): _projectile_spawn(shot[0],shot[2],shot[3],shot[1],shot[4],shot[5],shot[6],mode_state.get("ordnance",{}).get(shot[0],{}).get("extra",{}))
		if projectiles.has(shot[0]) and projectiles[shot[0]].has("definition"):projectiles[shot[0]].merge(mode_state.get("ordnance",{}).get(shot[0],{}),true)
		if projectiles.has(shot[0]):
			var p: Dictionary=projectiles[shot[0]]
			var error: Vector3=p.position+p.visual_error-shot[1]
			p.visual_error=error if error.length()<2.0 else Vector3.ZERO
			p.position=shot[1];p.visual_age=0.0
	if not multiplayer.is_server():
		var live_shots: Array = shots.map(func(shot): return shot[0])
		for id in projectiles.keys():
			if not live_shots.has(id) and (shot_watermark<0 or id<=shot_watermark):
				if is_instance_valid(projectiles[id].node):
					var pool=get_node_or_null("Map/MapRuntime/WeaponLighting")
					if pool:pool.remove_source(projectiles[id].node.get_instance_id())
					projectiles[id].node.queue_free()
				projectiles.erase(id)
		for i in range(mini(gate_states.size(),gates.size())):
			if gates[i].open!=gate_states[i]: _gate_state(i,gate_states[i])
		_sync_elevators(mode_state.get("elevators",[]))
		var bsp_runtime=get_node_or_null("Map/MapRuntime")
		if bsp_runtime:bsp_runtime.triggers.receive_killed(mode_state.get("bsp_killed",[]))
		for row in mode_state.get("map_movers",[]):
			if row.size()!=2 or not row[0] in range(gates.size()):continue
			var gate: Dictionary=gates[row[0]]
			if not gate.get("bsp",false):continue
			# Authoritative positions include trains and both legs of secret doors.
			if gate.has("motion_tween") and is_instance_valid(gate.motion_tween):gate.motion_tween.kill()
			gate.node.position=row[1]

func _sync_elevators(rows: Array) -> void:
	# A joining client may arrive halfway through a long elevator journey.
	# A boolean door state alone would replay that entire journey from the bottom.
	for row in rows:
		if row.size()!=2 or not row[0] in range(gates.size()):continue
		var gate: Dictionary=gates[row[0]]
		if not gate.get("elevator",false) or gate.node.position.distance_to(row[1])<.35:continue
		if gate.has("motion_tween") and is_instance_valid(gate.motion_tween):gate.motion_tween.kill()
		gate.node.position=row[1]
		var destination: Vector3=gate.base_position+(gate.travel if gate.open else Vector3.ZERO)
		var remaining: float=gate.move_seconds*gate.node.position.distance_to(destination)/gate.travel.length()
		if remaining>.001:
			var motion:=create_tween().bind_node(gate.node).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			gate.motion_tween=motion;motion.tween_property(gate.node,"position",destination,remaining)

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
	if is_instance_valid(district_gateway):district_gateway.action(id,"use");return
	if lobby.active():return
	if match_mode.special.blocked(id):return
	if not players.has(id) or players[id].dead or clock<players[id].use_at: return
	players[id].use_at = clock+.5
	if match_mode.fortress.walkers.mounted(id):
		match_mode.fortress.walkers.leave(id);return
	match_mode.fortress.action(id)
	# Desktop AS keeps proximity activation; Use is the VR accessibility fallback.
	if players[id].get("vr_device",false):match_mode.assault.activate(id)
	for i in range(gates.size()):
		if match_mode.kind=="as" and match_mode.assault.stage<int(gates[i].get("as_unlock",0)):continue
		var offset: Vector3 = fighters[id].position-gates[i].get("center",gates[i].node.position)
		offset.y = 0
		if offset.length()<2.5:
			gates[i].until = maxf(gates[i].until,clock+4)
			_gate_state.rpc(i,true)

@rpc("authority","call_local","reliable",0)
func _gate_state(index: int,opened: bool) -> void:
	if index<0 or index>=gates.size(): return
	var gate: Dictionary = gates[index]
	if gate.open==opened:return
	gate.open = opened
	if gate.has("motion_tween") and is_instance_valid(gate.motion_tween):gate.motion_tween.kill()
	var motion:=create_tween().bind_node(gate.node).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	gate.motion_tween=motion
	# Place the motor just outside the solid door toward the listener, avoiding
	# permanent self-occlusion by the panel it belongs to.
	var sound_position: Vector3=gate.get("center",gate.node.global_position)
	if not headless and is_instance_valid(camera):
		var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,sound_position,1))
		if not hit.is_empty() and hit.collider==gate.node:sound_position=hit.position+hit.normal*.08
	effects.play("door_open" if opened else "door_close",sound_position,-7)
	if gate.has("secret_first"):
		var middle: Vector3=gate.base_position+gate.secret_first
		var finish: Vector3=gate.base_position+(gate.travel if opened else Vector3.ZERO)
		motion.tween_property(gate.node,"position",middle,gate.node.position.distance_to(middle)/gate.secret_speed)
		motion.tween_interval(1.0)
		motion.tween_property(gate.node,"position",finish,middle.distance_to(finish)/gate.secret_speed)
	elif gate.has("base_position"):
		motion.tween_property(gate.node,"position",gate.base_position+(gate.travel if opened else Vector3.ZERO),float(gate.get("move_seconds",.6)))
	else:
		motion.tween_property(gate.node,"position:y",gate.base+(3.5 if opened else 0),.6)

func chat_send(message: String,team_only: bool=false) -> void:
	if multiplayer.is_server(): _chat_for(1,message,team_only)
	else: _chat_request.rpc_id(1,message,team_only)

@rpc("any_peer","call_remote","reliable",0)
func _chat_request(message: String,team_only: bool=false) -> void:
	if multiplayer.is_server(): _chat_for(multiplayer.get_remote_sender_id(),message,team_only)

func _chat_for(id: int,message: String,team_only: bool=false) -> void:
	if not players.has(id) or clock<players[id].chat_at: return
	players[id].chat_at = clock+.8
	var cleaned := message.left(256).replace("\n"," ").replace("\r"," ").strip_edges().left(140)
	if cleaned.is_empty():return
	if team_only:
		if not voice.team_available(id):return
		var text: String="[TEAM] "+players[id].name+": "+cleaned
		for peer in voice.recipients(id,true)+[id]:
			if peer==1:_announcement(text,true)
			elif peer>1:_announcement.rpc_id(peer,text,true)
		server_log.record("team_chat_activity",{"sender":id,"team":players[id].team,"characters":cleaned.length()},2)
	else:_announcement.rpc(players[id].name+": "+cleaned,true)

@rpc("authority","call_local","reliable",0)
func _announcement(message: String,is_chat: bool=false) -> void:
	if is_instance_valid(district_worker):district_worker.event("_announcement",[message,is_chat])
	if is_chat:server_log.record("chat_activity",{"characters":message.length()},2)
	else:server_log.record("match_event",{"message":message.left(512)})
	feed.append({"text":message,"until":clock+8})
	while feed.size()>5: feed.pop_front()
	if is_chat:
		chat_feed.append({"text":message,"until":clock+8})
		while chat_feed.size()>2:chat_feed.pop_front()
	last_event = message
	print("DM_EVENT ","[chat activity]" if is_chat and dedicated else message)

@rpc("authority","call_local","unreliable",3)
func _hit_confirm(id: int) -> void:
	if is_instance_valid(district_worker):district_worker.event("_hit_confirm",[id])
	if id==multiplayer.get_unique_id(): hit_flash = .14

@rpc("authority","call_local","unreliable",3)
func _melee_fx(id: int,offhand: bool=false) -> void:
	if is_instance_valid(district_worker):district_worker.event("_melee_fx",[id,offhand])
	demos.event("_melee_fx",[id,offhand])
	if fighters.has(id): fighters[id].animate_fire(offhand)
	if headless: return
	if armory.effective()=="quake" and players.has(id) and players[id].weapon in [0,1] and fighters.has(id):
		spatial.play("quake_weapon_0",_weapon_transform(id).origin,-8)
	if id==multiplayer.get_unique_id():
		melee_animation=.3
		if haptics:haptics.shot(id,0,offhand)
		if is_vr(): xr_rig.feedback(.2,.08,offhand)

@rpc("authority","call_local","unreliable",3)
func _shot_fx(id: int,weapon: int,offhand: bool=false) -> void:
	if is_instance_valid(district_worker):district_worker.event("_shot_fx",[id,weapon,offhand])
	demos.event("_shot_fx",[id,weapon,offhand])
	var predicted:=predicted_offhand_shot_clock if offhand else predicted_shot_clock
	if id==multiplayer.get_unique_id() and not multiplayer.is_server() and clock-predicted<.5: return
	_play_shot_fx(id,weapon,offhand)

func _play_shot_fx(id: int,weapon: int,offhand: bool=false,alternate: bool=false) -> void:
	if fighters.has(id): fighters[id].animate_fire(offhand)
	if headless: return
	var flame:bool=match_mode.fortress.art_rules(id,weapon)=="tf_flame"
	if id==multiplayer.get_unique_id():
		if haptics:haptics.shot(id,weapon,offhand,alternate)
		if offhand:
			offhand_recoil=1;offhand_visual_cooldown=match_mode.fortress.weapon_data(id,weapon).cycle
		else:
			recoil=1;visual_cooldown=match_mode.fortress.weapon_data(id,weapon).cycle
		if is_vr(): xr_rig.feedback(.25 if weapon<3 else .65,.08,offhand)
		if camera and weapon>=2 and weapon!=8 and not flame:
			var flash := Node3D.new()
			camera.add_child(flash)
			var model: Node3D=offhand_viewmodel if offhand else viewmodel
			if is_vr(): model=xr_rig.offhand_gun if offhand else xr_rig.gun
			flash.position=Vector3(-.18 if offhand else .18,-.18,-.8)
			if is_instance_valid(model):
				flash.global_position=model.to_global(model.get_meta("muzzle",Vector3(0,0,-.6)))
				flash.global_basis=model.global_basis.orthonormalized()
			_weapon_illumination(flash.global_position,flash.global_position,preload("res://deathmatch/lighting/weapon_emission.gd").recipe("muzzle"),id)
			var spark := Art.box(flash,Vector3(0,0,-.05),Vector3(.08,.07,.10),Art.material(armory.color(weapon),0,5))
			spark.rotation.z = randf()*PI
			get_tree().create_timer(.055).timeout.connect(flash.queue_free)
	if fighters.has(id):
		if flame:spatial.play("flamethrower",_weapon_transform(id,offhand).origin,-10)
		elif not armory.experimental():spatial.play("weapon_"+str(weapon),_weapon_transform(id,offhand).origin,-4)

@rpc("authority","call_local","unreliable",3)
func _ability_fx(kind: String,start: Vector3,end: Vector3,team: int) -> void:
	if is_instance_valid(district_worker):district_worker.event("_ability_fx",[kind,start,end,team])
	if not kind in preload("res://deathmatch/modes/fortress_fx.gd").KINDS or not start.is_finite() or not end.is_finite() or team not in [0,1]:return
	demos.event("_ability_fx",[kind,start,end,team])
	if headless:return
	if not is_instance_valid(ability_effects):
		ability_effects=preload("res://deathmatch/modes/fortress_fx.gd").new();ability_effects.game=self;ability_effects.name="AbilityEffects";add_child(ability_effects)
	ability_effects.emit(kind,start,end,team)

@rpc("authority","call_local","unreliable",3)
func _impacts(start: Vector3,ends: PackedVector3Array,weapon: int) -> void:
	if is_instance_valid(district_worker):district_worker.event("_impacts",[start,ends,weapon])
	demos.event("_impacts",[start,ends,weapon])
	if headless or weapon<2: return
	var definition: Dictionary=armory.data(weapon).duplicate()
	if match_mode.kind=="tf" and weapon==9:definition.name="SNIPER RIFLE"
	if match_mode.kind=="tf" and weapon==7:definition.kind="hitscan"
	_weapon_visuals().impacts(armory.effective(),start,ends,weapon,definition)
	var impact_budget:=2
	for end in ends:
		if impact_budget>0:
			var direction: Vector3=(end-start).normalized()
			var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(end-direction*.08,end+direction*.08,1))
			if not hit.is_empty():
				spatial.play("impact",hit.position+hit.normal*.02,-17)
				impact_budget-=1
@rpc("authority","call_local","reliable",0)
func _projectile_end(id: int,pos: Vector3,weapon: int) -> void:
	if is_instance_valid(district_worker):district_worker.event("_projectile_end",[id,pos,weapon])
	if not multiplayer.is_server():
		if ended_projectiles.has(id):return
		ended_projectiles[id]=true
		while ended_projectiles.size()>2048:ended_projectiles.erase(ended_projectiles.keys()[0])
	demos.event("_projectile_end",[id,pos,weapon])
	var projectile_definition: Dictionary=projectiles.get(id,{}).get("definition",{})
	var projectile_kind: String=projectile_definition.get("kind","")
	if projectiles.has(id):
		if is_instance_valid(projectiles[id].node):
			var pool=get_node_or_null("Map/MapRuntime/WeaponLighting")
			if pool:pool.remove_source(projectiles[id].node.get_instance_id())
			projectiles[id].node.queue_free()
		projectiles.erase(id)
	if headless: return
	if armory.experimental():
		var explosive: bool=weapon in ([4,6] if armory.kind=="quake" else [1,3,4,6,8,10])
		spatial.play(armory.kind+("_explosion" if explosive else "_bounce"),pos,-8 if explosive else -18)
		_weapon_visuals().burst(armory.kind,pos,weapon,projectile_kind,projectile_definition)
		return
	elif weapon==6 or weapon==8: effects.play("explosion",pos,-3)
	_weapon_visuals().burst("doom",pos,weapon)

func _process(delta: float) -> void:
	if demos.playing:return
	if active and not multiplayer.is_server() and clock>=next_network_health:
		next_network_health=clock+5
		var mine:=multiplayer.get_unique_id()
		ConnectionLog.record("network_health",{"replication":replication.stats,"interpolation_ms":remote_interpolation.delay*1000,"jitter_ms":remote_interpolation.jitter*1000,"sample_age_ms":maxf(0,clock-remote_interpolation.arrived)*1000,"prediction":fighters[mine].prediction.stats if fighters.has(mine) else {}})
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
	if armory.experimental():camera.fov=18.0 if match_mode.fortress.weapon_data(multiplayer.get_unique_id(),s.weapon).get("scope",false) and bindings.pressed("alt_fire") and not menu_open else float(presentation.get("fov",85.0))
	var art_rules: String=match_mode.fortress.art_rules(multiplayer.get_unique_id(),s.weapon)
	if s.weapon!=model_weapon or art_rules!=model_art_rules:
		if is_instance_valid(viewmodel): viewmodel.queue_free()
		if is_instance_valid(offhand_viewmodel): offhand_viewmodel.queue_free()
		offhand_viewmodel=null
		if s.weapon==2 and armory.dual():
			offhand_viewmodel=Art.weapon(2,int(presentation.get("texture_filter",2)));offhand_viewmodel.scale=Vector3.ONE*.72;camera.add_child(offhand_viewmodel)
		viewmodel = Art.weapon(s.weapon,int(presentation.get("texture_filter",2)),art_rules)
		viewmodel.scale = Vector3.ONE*.72
		camera.add_child(viewmodel)
		model_weapon = s.weapon;model_art_rules=art_rules
	camera.rotation = Vector3(local_pitch,local_yaw,0)
	camera_eye_height = lerpf(camera_eye_height,.35 if s.dead and not s.spectator and not cq_client.waiting() else fighters[multiplayer.get_unique_id()].eye_height(),minf(1,delta*8))
	camera.global_position = fighters[multiplayer.get_unique_id()].render_position()+Vector3.UP*(camera_eye_height+fighters[multiplayer.get_unique_id()].view_offset)
	fighters[multiplayer.get_unique_id()].rotation.y = local_yaw
	viewmodel.visible = not s.dead and not menu_open and not lobby.active()
	var speed: float = fighters[multiplayer.get_unique_id()].velocity.length()
	viewmodel.position = Vector3(.18+sin(clock*10)*minf(speed*.003,.025),-.24+absf(cos(clock*10))*minf(speed*.003,.025)-recoil*.035,-.48+recoil*.075)
	if s.weapon==1 and not armory.experimental():Art.clip_saw(viewmodel)
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

var loaded_pickup_rules:=""
func _load_map(map_id: String) -> bool:
	if cq_profile and map_id!=match_mode.conquest.MAP_ID:return false
	if cq_profile and cq_maps.enabled:return cq_maps.load_world()
	if map_id==lobby.ID:return lobby.build()
	var pickup_rules: String=match_mode.kind+":"+armory.effective()
	if current_map==map_id and loaded_pickup_rules==pickup_rules and $Map.get_child_count()>0: return true
	var info: Dictionary = {}
	for row in map_catalog:
		if row.id==map_id: info=row; break
	if info.is_empty(): return false
	if match_mode.kind=="as" and not Maps.supports_assault(info.path):return false
	var scene: PackedScene=Maps.scene(info)
	if not scene: return false
	match_mode.clear_visuals()
	for child in $Map.get_children(): child.free()
	pickups.clear()
	gates.clear()
	lifts.clear()
	spawn_points.clear()
	spawn_yaws.clear()
	map_objectives.clear();ctf_spawns=[[],[]];tf_resupply=[[],[]];tf_capture.clear();map_assault.clear()
	var level := scene.instantiate()
	$Map.add_child(level)
	current_map=map_id
	map_title=info.title
	map_sha=info.sha256
	var runtime := preload("res://deathmatch/maps/runtime.gd").new()
	runtime.name = "MapRuntime"
	$Map.add_child(runtime)
	match_mode.fortress.walkers.configure([])
	match_mode.titanball.configure([],[])
	runtime.configure(self,level,info.path)
	if cq_profile:match_mode.conquest.configure_pickups()
	loaded_pickup_rules=pickup_rules
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
			var end: Vector3=p.position+(p.get("velocity",p.direction*float(armory.data(p.weapon).get("speed",0)))*step if not p.get("stuck",false) else Vector3.ZERO)
			var wall:=HitDetection.world_fraction(get_world_3d().direct_space_state,p.position,end,float(armory.data(p.weapon).get("radius",.1))) if step>0 else INF
			p.position=p.position.lerp(end,minf(1.0,wall));p.visual_age+=delta
			p.visual_error*=exp(-20*delta)
		if is_instance_valid(p.node):
			var rendered: Vector3=p.position
			if multiplayer.is_server() and not demos.playing:rendered=p.get("previous_position",p.position).lerp(p.position,Engine.get_physics_interpolation_fraction())
			p.node.position=rendered+p.visual_error
			_weapon_visuals().travel(p.node,p.get("velocity",p.direction*float(armory.data(p.weapon).get("speed",0))),delta,p.get("stuck",false))

func is_vr() -> bool:
	return is_instance_valid(xr_rig) and xr_rig.enabled
func _weapon_transform(id: int, offhand: bool=false) -> Transform3D:
	var s: Dictionary=players[id]
	if id==multiplayer.get_unique_id() and not multiplayer.is_server() and is_vr() and not demos.playing:
		var pose: Dictionary=xr_rig.sample_pose()
		if not pose.is_empty():return Transform3D(Basis(Vector3.UP,local_yaw),fighters[id].render_position())*pose.get("offhand_weapon" if offhand else "weapon",Transform3D.IDENTITY)
	if not s.xr.is_empty(): return Transform3D(Basis(Vector3.UP,s.yaw),fighters[id].position)*s.xr.get("offhand_weapon" if offhand else "weapon",Transform3D.IDENTITY)
	var aim:=Basis(Vector3.UP,s.yaw)*Basis(Vector3.RIGHT,s.pitch)
	# Desktop weapons share the crosshair ray. Parallel left/right pistol rays
	# missed the visible head despite a centered crosshair; XR keeps tracked muzzles.
	return Transform3D(aim,fighters[id].position+Vector3.UP*minf(1.45,fighters[id].eye_height()))
func _update_crouch(id: int,pose: Dictionary,command: Dictionary={}) -> void:
	var actor=fighters[id]
	var state: Dictionary=players[id] if command.is_empty() else command
	var requested:=1.65
	var prone: bool=state.get("prone",false)==true and not actor.in_water
	if not pose.is_empty():
		# Tracked users cannot hide an upright headset inside a prone collider.
		var head_height: float=pose.head.origin.y
		requested=maxf(float(pose.get("height",1.65)),clampf(head_height+.10,.80,1.65))
		if prone and head_height<.69:requested=clampf(head_height+.10,.65,.79)
	elif prone:requested=.65
	elif state.get("crouch",false)==true:requested=1.05
	actor.update_height(requested)
	actor.tracked_leg_animation=state.get("leg_assist",false)==true
	if not pose.is_empty():pose.height=actor.collision_height
func _shot_origin(id: int, offhand: bool=false) -> Vector3:
	return _shot_solution(id,offhand).origin
func _shot_solution(id: int, offhand: bool=false) -> Dictionary:
	var local_tracking: bool=id==multiplayer.get_unique_id() and not multiplayer.is_server() and is_vr() and not demos.playing
	if players[id].vr_device and players[id].xr.is_empty() and not local_tracking:return {"origin":fighters[id].position,"blocked":true,"clipped":false}
	var transform_here:=_weapon_transform(id,offhand)
	var chest: Vector3=fighters[id].position+Vector3.UP*fighters[id].torso_height()
	if players[id].xr.is_empty() and not local_tracking:
		var blocked:=false
		if players[id].weapon==2:blocked=not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(chest,transform_here.origin,1)).is_empty()
		return {"origin":transform_here.origin,"blocked":blocked,"clipped":false}
	var weapon: int=players[id].weapon
	var art_rules: String=match_mode.fortress.art_rules(id,weapon)
	var muzzle: Vector3=Art.held_transform(transform_here,weapon,Art.VR_SCALE,art_rules)*Art.muzzle(weapon,art_rules)
	var radius: float=float(armory.data(weapon).get("radius",.025)) if armory.experimental() else W.DATA[weapon].radius if weapon in [6,7,8] else .025
	return preload("res://deathmatch/vr/weapon_clearance.gd").solve(get_world_3d().direct_space_state,chest,transform_here.origin,muzzle,radius)
func _weapon_blocked(id: int, offhand: bool=false) -> bool:
	if not players.has(id): return true
	return _shot_solution(id,offhand).blocked

@rpc("authority","call_local","reliable",0)
func _hurt_fx(id: int,pos: Vector3,direction: Vector3,amount: int,dead: bool,gibbed: bool,seed_value: int,screen_only: bool=false,weapon_name: String="",blast: bool=false) -> void:
	if is_instance_valid(district_worker):district_worker.event("_hurt_fx",[id,pos,direction,amount,dead,gibbed,seed_value,screen_only,weapon_name,blast])
	demos.event("_hurt_fx",[id,pos,direction,amount,dead,gibbed,seed_value,screen_only,weapon_name,blast])
	if fighters.has(id):fighters[id].gibbed=gibbed
	if haptics:haptics.hurt(id,direction,amount,dead,screen_only,pos,weapon_name,blast)
	# Hunger has no impact/pain sounds, blood or hit haptics. Preserve fatal death effects.
	if not screen_only or dead:effects.hit(id,pos,direction,amount,dead,gibbed,seed_value)
	if id==multiplayer.get_unique_id() and not dedicated and not headless:
		hurt_flash=maxf(hurt_flash,clampf(.18+amount*.006,.18,.42))
		if not screen_only:effects.local_hit()

@rpc("authority","call_local","reliable",0)
func _teleport_fx(pos: Vector3) -> void:
	if is_instance_valid(district_worker):district_worker.event("_teleport_fx",[pos])
	demos.event("_teleport_fx",[pos])
	effects.play("teleport",pos)

func _clear_map_players() -> void:
	if haptics:haptics.stop()
	# Cosmetic buildings live under the arena, not under the map scene.
	# The authority has already installed destination-map sentries in _rotate_map.
	if not multiplayer.is_server():match_mode.fortress.reset()
	chainsaw.reset();variant_combat.reset()
	announcer.reset()
	votes.reset()
	# Preserve the ENet connection; every peer goes through map readiness again.
	active=false
	for actor in fighters.values(): actor.free()
	fighters.clear();players.clear()
	for shot in projectiles.values():
		if is_instance_valid(shot.node): shot.node.free()
	projectiles.clear();history.clear()
	if is_instance_valid(variant_visuals):variant_visuals.queue_free();variant_visuals=null
	var weapon_pool=get_node_or_null("Map/MapRuntime/WeaponLighting")
	if weapon_pool:weapon_pool.clear()
	remote_view_time=-1.0;snapshot_view_time=-1.0;projectile_watermark=-1;snapshot_projectiles.clear();ended_projectiles.clear()
	avatars.reset();effects.clear()
	camera=xr_rig.head if is_vr() else null
	viewmodel=null;model_weapon=-1;camera_eye_height=1.48
	hurt_flash=0;hit_flash=0;recoil=0;visual_cooldown=0;offhand_visual_cooldown=0;offhand_recoil=0;melee_animation=0
	if not headless and not is_vr(): $Overview.make_current()

func _prepare_client_map(epoch: int) -> void:
	replication.reset(); input_delivery.reset(); fire_delivery.reset(); remote_interpolation.reset(); bandwidth.reset(); input_paused_until=0
	lobby.view.clear()
	loading.begin();loading.phase="Preparing server map…"
	map_network.reset()
	if uploads:uploads.reset()
	_clear_map_players()
	map_epoch=epoch;map_loading=true
	connect_deadline=clock+240
	menu_open=true
	if hud: hud.show_menu(true)

@rpc("authority","call_remote","reliable",0)
func _map_input_pause(epoch: int, paused: bool) -> void:
	if epoch==map_epoch:input_paused_until=clock+15.0 if paused else 0.0

func _rotate_map(map_id: String) -> bool:
	if not multiplayer.is_server(): return false
	# Notify before synchronous scene/physics construction. Peers stop feeding
	# stale movement into the socket while the authority cannot poll it.
	_map_input_pause.rpc(map_epoch,true)
	if not _load_map(map_id):
		_map_input_pause.rpc(map_epoch,false)
		status("Could not load rotation map: "+map_id)
		return false
	if map_id!=lobby.ID:lobby.reset_ballot()
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
	loading.pending.clear()
	map_epoch+=1;map_loading=not names.is_empty()
	selected_map=map_id
	round_left=time_limit;round_message="";intermission=0
	active=true
	# Send the new map on the same reliable channel as its download messages.
	for id in names:
		pending_joins[id]=clock+240
		map_network.offer(id)
	if not dedicated: _add_player(1,nickname)
	bot_population.refresh_navigation()
	bot_population.maintain()
	server_log.record("map_rotated",{"map":current_map,"waiting_peers":pending_names.size()})
	print("MAP_ROTATED ",current_map," epoch=",map_epoch)
	return true

@rpc("authority","call_local","reliable",0)
func _capture_feedback(team: int,scorer: String,score: int) -> void:
	match_mode.capture_feedback(team,scorer,score)

func _announcer_cue(cue: String,target: int=0) -> void:
	var listener: int=demos.selected_player if demos.playing else multiplayer.get_unique_id()
	if target==0 or target==listener:announcer.enqueue(cue,2 if cue=="objective_completed" else 1)

@rpc("authority","call_local","unreliable",3)
func _saw_contact(pos: Vector3,normal: Vector3,id: int,other: int=0) -> void:
	if is_instance_valid(district_worker):district_worker.event("_saw_contact",[pos,normal,id,other])
	demos.event("_saw_contact",[pos,normal,id,other])
	if headless:return
	effects.sparks(pos,normal)
	effects.play("saw_grind",pos,-12)
	if is_vr() and multiplayer.get_unique_id() in [id,other]:xr_rig.feedback(.45,.08)

func _fighter_movement_sound(kind: String,where: Vector3,id: int) -> void:
	# Predicted client movement never creates a second copy of the server cue.
	if not multiplayer.is_server() or not active or not players.has(id):return
	if players[id].dead or players[id].spectator:return
	_movement_sound.rpc(map_epoch,id,int(players[id].serial),kind,where)

@rpc("authority","call_local","reliable",3)
func _movement_sound(epoch: int,id: int,serial: int,kind: String,where: Vector3) -> void:
	if is_instance_valid(district_worker):district_worker.event("_movement_sound",[epoch,id,serial,kind,where])
	if not kind in ["jump","land"] or not where.is_finite():return
	if not demos.playing:
		if epoch!=map_epoch or not players.has(id) or serial<int(players[id].serial):return
		# Reliable audio may precede the next unreliable spawn snapshot.
		if serial==int(players[id].serial) and (players[id].dead or players[id].spectator):return
	demos.event("_movement_sound",[epoch,id,serial,kind,where])
	if headless:return
	effects.play(kind,where,-10 if kind=="jump" else -14)

@rpc("authority","call_local","unreliable",3)
func _variant_shot_fx(id: int,weapon: int,alternate: bool) -> void:
	if is_instance_valid(district_worker):district_worker.event("_variant_shot_fx",[id,weapon,alternate])
	if not armory.experimental() or not armory.valid(weapon):return
	demos.event("_variant_shot_fx",[id,weapon,alternate])
	if variant_combat.consume_prediction(id,weapon,alternate):return
	_play_variant_shot_fx(id,weapon,alternate)

func _play_variant_shot_fx(id: int,weapon: int,alternate: bool) -> void:
	_play_shot_fx(id,weapon,false,alternate)
	if headless:return
	if id==multiplayer.get_unique_id():visual_cooldown=armory.data(weapon,alternate).cycle
	if fighters.has(id) and match_mode.fortress.art_rules(id,weapon)!="tf_flame":spatial.play(armory.kind+"_weapon_"+str(weapon)+("_alt" if alternate else ""),_weapon_transform(id).origin,-4)

@rpc("authority","call_local","unreliable",3)
func _variant_bounce_fx(pos: Vector3,weapon: int) -> void:
	if is_instance_valid(district_worker):district_worker.event("_variant_bounce_fx",[pos,weapon])
	if not armory.experimental():return
	demos.event("_variant_bounce_fx",[pos,weapon])
	if headless:return
	spatial.play(armory.kind+"_bounce",pos,-12)

@rpc("authority","call_local","unreliable",3)
func _variant_combo_fx(pos: Vector3) -> void:
	if is_instance_valid(district_worker):district_worker.event("_variant_combo_fx",[pos])
	demos.event("_variant_combo_fx",[pos])
	if headless:return
	spatial.play("ut99_combo",pos,-3)
	_weapon_visuals().combo(pos)

func _weapon_visuals():
	if not is_instance_valid(variant_visuals):
		variant_visuals=load("res://deathmatch/experimental/visuals.gd").new();variant_visuals.name="WeaponEffects";add_child(variant_visuals);variant_visuals.illumination.connect(_weapon_illumination)
	return variant_visuals

func _weapon_illumination(a: Vector3,b: Vector3,recipe: Dictionary,key: int=0) -> void:
	var pool=get_node_or_null("Map/MapRuntime/WeaponLighting")
	if pool:pool.emit_source(a,b,recipe,key)

func maps_for_mode(mode: String) -> Array:
	if cq_profile:return [match_mode.conquest.MAP_ID] if mode=="cq" else []
	if mode=="cq":return []
	var list_kind: String=match_mode.maplist_kind(mode)
	if mode=="if" and not mode_maplists.has(list_kind) and mode_maplists.has("ig"):
		return Maps.inherited_maplist(map_catalog,mode,Maps.choices_for_mode(map_catalog,mode,mode_maplists.ig))
	return Maps.choices_for_mode(map_catalog,mode,mode_maplists.get(list_kind,[]))

# CQ uses the same public ENet connection, with a generation per district visit.
@rpc("authority","call_remote","reliable",0)
func _cq_transition(epoch: int,generation: int,zone: int) -> void:cq_client.transition(epoch,generation,zone)
@rpc("any_peer","call_remote","reliable",0)
func _cq_ready(epoch: int,generation: int) -> void:
	if multiplayer.is_server() and is_instance_valid(district_gateway) and epoch==map_epoch:district_gateway.ready(multiplayer.get_remote_sender_id(),generation)
@rpc("authority","call_remote","reliable",0)
func _cq_baseline(epoch: int,generation: int,bytes: PackedByteArray) -> void:cq_client.baseline(epoch,generation,bytes)
@rpc("authority","call_remote","unreliable",1)
func _cq_state(epoch: int,generation: int,bytes: PackedByteArray) -> void:cq_client.packet(epoch,generation,bytes)
@rpc("authority","call_remote","reliable",7)
func _cq_large(epoch: int,generation: int,bytes: PackedByteArray) -> void:cq_client.packet(epoch,generation,bytes)
@rpc("authority","call_remote","reliable",0)
func _cq_event(epoch: int,generation: int,method: String,args: Array) -> void:cq_client.event(epoch,generation,method,args)
@rpc("authority","call_remote","reliable",0)
func _cq_capacity(epoch: int,counts: Array,revision: int) -> void:
	if cq_profile and epoch==map_epoch:cq_client.capacity(counts,revision)
