extends Node3D
const W = preload("res://deathmatch/weapons.gd")
const Art = preload("res://deathmatch/art.gd")
const Fighter = preload("res://deathmatch/fighter.gd")
const Interface = preload("res://deathmatch/interface.gd")
const PROTOCOL := "entryway-dm-7-eyes"
const MAX_PLAYERS := 8
const VRPoses=preload("res://deathmatch/vr/poses.gd")
const Maps = preload("res://deathmatch/maps/loader.gd")
var map_catalog: Array = Maps.catalog()
var selected_map := "lqdm1"
var current_map := ""
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
var server_name := "Entryway Arena"
var bind_address := "*"
var max_clients := MAX_PLAYERS
var voice_enabled := true
var voice
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
var camera: Camera3D
var viewmodel: Node3D
var model_weapon := -1
var recoil := 0.0
var visual_cooldown := 0.0
var hurt_flash := 0.0
var hit_flash := 0.0
var last_local_hp := 100
var hud
var menu_open := true
var feed: Array = []
var spatial
var sounds: Array = []
var history: Array = []
var pending_joins: Dictionary = {}
var connect_deadline := 0.0
var local_ping := 0
var last_event := ""
var headless := false
var predicted_shot_clock := -10.0

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
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
	effects=preload("res://deathmatch/effects/combat.gd").new()
	effects.name="CombatEffects"
	add_child(effects)
	effects.setup(self)
	voice=preload("res://deathmatch/voice/chat.gd").new()
	voice.name="VoiceChat"
	add_child(voice)
	voice.setup(self)
	_load_map(selected_map)
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
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): disconnect_game("Connection failed. Check address and UDP port."))
	multiplayer.server_disconnected.connect(func(): disconnect_game("The host disconnected."))
	var args := OS.get_cmdline_user_args()
	if args.has("--frame-stats") and not headless: add_child(preload("res://deathmatch/performance/frame_stats.gd").new())
	selected_map = _arg_value(args,"--map",selected_map)
	if args.has("--check-assets"):
		var result: int=await preload("res://deathmatch/diagnostics.gd").check_assets(self)
		get_tree().quit(result)
		return
	if args.has("--server") or OS.has_feature("dedicated_server"):
		_start_dedicated(args)
	elif args.has("--practice"):
		start_host("Marine",0,20,10,true)
	elif args.has("--connect"):
		start_join("Marine",_arg_value(args,"--connect","127.0.0.1"),_arg_int(args,"--port",7777))

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
	server_name=settings.sv_hostname
	bind_address=settings.net_ip
	max_clients=settings.sv_maxclients
	voice_enabled=settings.sv_voice==1
	selected_map=_arg_value(args,"--map",settings.map)
	start_host("Server",_arg_int(args,"--port",settings.net_port),_arg_int(args,"--frags",settings.fraglimit),_arg_int(args,"--minutes",settings.timelimit),false)
	if not active:
		get_tree().quit(2)
		return
	print("SERVER_CONFIG name=",server_name," bind=",bind_address," maxclients=",max_clients," voice=",voice_enabled," map=",current_map)

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
	if p.kind=="health": color = Color("f0746a")
	if p.kind=="armor": color = Color("89db74")
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
	var model: Node3D
	if p.kind=="weapon": model = Art.weapon(p.item)
	else:
		model = Node3D.new()
		if p.kind=="armor":
			Art.box(model,Vector3.ZERO,Vector3(.46,.48,.23),Art.material(color,.3))
			for x in [-.29,.29]: Art.box(model,Vector3(x,.15,0),Vector3(.2,.18,.25),Art.material(color,.3))
		elif p.kind=="bonus":
			Art.barrel(model,Vector3.ZERO,.11,.22,Art.material(color,0,1)).rotation = Vector3.ZERO
		else:
			Art.box(model,Vector3.ZERO,Vector3(.34,.24,.24),Art.material(Color("a4b4b9"),.3))
			Art.box(model,Vector3(0,0,-.13),Vector3(.22,.065,.02),Art.material(color,0,1))
			if p.kind=="health": Art.box(model,Vector3(0,0,-.13),Vector3(.065,.18,.02),Art.material(color,0,1))
	root.add_child(model)
	model.name = "Display"
	model.position.y = .58
	var label := Label3D.new()
	label.text = W.DATA[p.item].name if p.kind=="weapon" else (W.AMMO_NAMES[p.item] if p.kind=="ammo" else p.kind.to_upper())
	label.position.y = 1.05
	label.font_size = 24
	label.pixel_size = .004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	root.add_child(label)
	return root

func start_host(player_name: String,port: int,frags: int,minutes: int,training: bool) -> void:
	if active: return
	if not _load_map(selected_map):
		status("Could not load the selected map.")
		return
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
	for pickup in pickups:
		pickup.available = true
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

func start_join(player_name: String,address: String,port: int) -> void:
	if active: return
	nickname = clean_name(player_name)
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
	var output := ""
	for character in value.strip_edges().left(64):
		if character.unicode_at(0)>=32 and character not in ["[","]","\n","\r"]: output += character
	return output.left(18) if not output.is_empty() else "Marine"

func _connected() -> void:
	_hello.rpc_id(1,nickname,PROTOCOL)

func _peer_connected(id: int) -> void:
	if multiplayer.is_server(): pending_joins[id] = clock+8

@rpc("any_peer","call_remote","reliable",0)
func _hello(player_name: String,version: String) -> void:
	if not multiplayer.is_server() or not active: return
	var id := multiplayer.get_remote_sender_id()
	if id<=1 or players.has(id) or not pending_joins.has(id): return
	if version != PROTOCOL or players.size()>=max_clients or practice:
		_rejected.rpc_id(id,"Version mismatch, private practice session, or server full.")
		return
	pending_names[id] = clean_name(player_name)
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
	_add_player(id,player_name)
	avatars.sync_peer(id)
	voice.policy.rpc_id(id,voice_enabled,server_name)
	_announcement.rpc(player_name+" joined the arena.")

@rpc("authority","call_remote","reliable",0)
func _rejected(reason: String) -> void:
	disconnect_game(reason)

func _new_state(player_name: String,id: int) -> Dictionary:
	return {"name":clean_name(player_name),"color":posmod(id,8),"hp":100,"armor":0,"tier":1,"ammo":[50,0,0,0],"owned":[2],"weapon":2,"kills":0,"deaths":0,"ping":0,"dead":false,"serial":0,"cooldown":0.0,"charge":0.0,"invulnerable":0.0,"respawn_at":0.0,"last_input":clock,"last_seq":-1,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":false,"held":false,"slow":false,"chat_at":0.0,"use_at":0.0,"want_respawn":false,"jump":false,"shots":0,"xr":{},"vr_device":false,"room":Vector3.ZERO}

func _create_fighter(id: int) -> void:
	var actor = Fighter.new()
	actor.setup(id,players[id].name,COLORS[players[id].color])
	actor.quake_movement = true
	add_child(actor)
	fighters[id] = actor

func _add_player(id: int,player_name: String) -> void:
	players[id] = _new_state(player_name,id)
	_create_fighter(id)
	_spawn(id)
	var defaults: Array = avatars.library.entries.keys()
	if not defaults.is_empty():
		var hash: String = defaults[posmod(id,mini(3,defaults.size()))]
		avatars.choices[id] = {"hash":hash,"size":avatars.library.entries[hash].size}
	_broadcast_roster()

func _broadcast_roster() -> void:
	var data: Array = []
	for id in players: data.append([id,players[id].name,players[id].color,fighters[id].position,players[id].yaw])
	_roster.rpc(data)

@rpc("authority","call_local","reliable",0)
func _roster(data: Array) -> void:
	var keep: Array = []
	for row in data:
		var id: int = row[0]
		keep.append(id)
		if not players.has(id):
			players[id] = _new_state(row[1],id)
			players[id].color = row[2]
			_create_fighter(id)
			fighters[id].position = row[3]
			players[id].yaw = row[4]
			if id==multiplayer.get_unique_id(): local_yaw = row[4]
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
		camera.fov = 85
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
	avatars.remove_peer(id)
	pending_joins.erase(id)
	pending_names.erase(id)
	if not multiplayer.is_server() or not players.has(id): return
	var player_name: String = players[id].name
	fighters[id].queue_free()
	fighters.erase(id)
	players.erase(id)
	_finish_departure.call_deferred(player_name)

func _finish_departure(player_name: String) -> void:
	if not active or not multiplayer.is_server(): return
	_broadcast_roster()
	_announcement.rpc(player_name+" left the arena.")

func disconnect_game(reason: String = "Disconnected.") -> void:
	active = false
	avatars.reset()
	voice.reset()
	map_network.reset()
	effects.clear()
	connect_deadline = 0
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for actor in fighters.values(): actor.queue_free()
	fighters.clear()
	players.clear()
	for projectile in projectiles.values():
		if is_instance_valid(projectile.node): projectile.node.queue_free()
	projectiles.clear()
	pending_joins.clear()
	pending_names.clear()
	camera = null
	viewmodel = null
	model_weapon = -1
	if is_instance_valid(bots): bots.free()
	bots=null
	practice = false
	menu_open = true
	intermission = 0
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
	var best: Vector3 = spawn_points[0]
	var best_score := -1.0
	for point in spawn_points:
		var distance := 100.0
		for other in fighters:
			if other != id and not players[other].dead: distance = minf(distance,point.distance_to(fighters[other].position))
		var score := distance+randf()*2
		if score>best_score:
			best = point
			best_score = score
	fighters[id].position = best
	fighters[id].velocity = Vector3.ZERO
	fighters[id].gibbed=false
	state.merge({"hp":100,"armor":0,"tier":1,"ammo":[50,0,0,0],"owned":[2],"weapon":2,"dead":false,"cooldown":.3,"charge":0.0,"invulnerable":clock+1.5,"move":Vector2.ZERO,"fire":false,"held":false,"yaw":0.0,"pitch":0.0,"want_respawn":false},true)
	if not spawn_yaws.is_empty(): state.yaw = spawn_yaws[spawn_points.find(best)]
	if id==multiplayer.get_unique_id():
		local_yaw = state.yaw
		local_pitch = 0.0
	state.xr={}
	state.room=Vector3.ZERO
	if id==multiplayer.get_unique_id() and is_vr(): xr_rig.on_spawn()
	state.serial += 1

func _unhandled_input(event: InputEvent) -> void:
	if is_vr(): return
	if not active or dedicated: return
	if event is InputEventMouseMotion and not menu_open and not (hud and hud.chat.has_focus()):
		local_yaw = wrapf(local_yaw-event.relative.x*.0022,-PI,PI)
		local_pitch = clampf(local_pitch-event.relative.y*.0022,-1.45,1.45)
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: fire_down = event.pressed and not menu_open
		if event.pressed and not menu_open:
			var owned: Array = local_state().get("owned",[2])
			if event.button_index==MOUSE_BUTTON_WHEEL_UP: desired_weapon = W.next_owned(desired_weapon,1,owned)
			if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: desired_weapon = W.next_owned(desired_weapon,-1,owned)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			menu_open = not menu_open
			fire_down = false
			if hud: hud.show_menu(menu_open)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
		elif event.physical_keycode==KEY_ENTER and not menu_open:
			if hud: hud.open_chat()
		elif not menu_open:
			var owned: Array = local_state().get("owned",[2])
			var slots = {KEY_1:[0,1],KEY_2:[2],KEY_3:[3,4],KEY_4:[5],KEY_5:[6],KEY_6:[7],KEY_7:[8]}
			if slots.has(event.physical_keycode):
				var options: Array = slots[event.physical_keycode].filter(func(w): return owned.has(w))
				if not options.is_empty(): desired_weapon = options[(options.find(desired_weapon)+1)%options.size()]
			if event.physical_keycode==KEY_E:
				if multiplayer.is_server(): _use_for(1)
				else: _use_request.rpc_id(1)

func local_state() -> Dictionary:
	return players.get(multiplayer.get_unique_id(),{}) if active else {}

func _local_command() -> Dictionary:
	if is_vr(): return xr_rig.command(sequence)
	var blocked: bool = menu_open or (hud != null and hud.chat.has_focus())
	var move := Vector2.ZERO if blocked else Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).limit_length(1)
	return {"seq":sequence,"move":move,"yaw":local_yaw,"pitch":local_pitch,"fire":fire_down and not blocked,"weapon":desired_weapon,"slow":Input.is_physical_key_pressed(KEY_SHIFT),"jump":not blocked and Input.is_physical_key_pressed(KEY_SPACE),"respawn":not blocked and (fire_down or Input.is_physical_key_pressed(KEY_SPACE))}

@rpc("any_peer","call_remote","unreliable_ordered",2)
func _input_command(command: Dictionary) -> void:
	if multiplayer.is_server(): _accept_input(multiplayer.get_remote_sender_id(),command)

func _accept_input(id: int,command: Dictionary) -> void:
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
	s.last_seq = command.seq
	s.last_input = clock
	s.move = command.move.limit_length(1.0)
	s.yaw = wrapf(command.yaw,-PI,PI)
	s.pitch = clampf(command.pitch,-1.45,1.45)
	s.fire = command.fire
	s.slow = command.slow
	s.want_respawn = command.respawn
	s.jump = command.get("jump",false)==true
	s.vr_device=command.has("xr")
	s.xr=VRPoses.validate(command.get("xr",{}))
	s.room=Vector3.ZERO
	if command.get("room") is Vector3 and command.room.is_finite() and not s.xr.is_empty():
		s.room=Vector3(command.room.x,0,command.room.z).limit_length(.08)
	if command.has("xr") and s.xr.is_empty(): s.fire=false
	if s.owned.has(command.weapon) and command.weapon!=s.weapon and s.charge<=0:
		s.weapon = command.weapon
		s.cooldown = maxf(s.cooldown,.28)
		s.held = false

func _physics_process(delta: float) -> void:
	clock += delta
	if connect_deadline>0 and clock>connect_deadline: disconnect_game("Connection timed out. Check host, firewall and UDP port forwarding.")
	if not active: return
	var mine := multiplayer.get_unique_id()
	if players.has(mine) and not dedicated:
		sequence += 1
		var command := _local_command()
		if multiplayer.is_server(): _accept_input(mine,command)
		else:
			input_accumulator += delta
			if input_accumulator>=1.0/30:
				input_accumulator = 0
				_input_command.rpc_id(1,command)
			if not players[mine].dead and intermission<=0:
				var room: Vector3=command.get("room",Vector3.ZERO)
				var speed:=5.2 if command.slow else 9.4
				fighters[mine].simulate(command.move*(1.0-minf(room.length()*30/speed,1.0)),local_yaw,command.slow,delta,command.get("jump",false))
				if is_vr():
					fighters[mine].move_and_collide(Basis(Vector3.UP,local_yaw)*room*delta*30)
					xr_rig.origin_offset-=room*delta*30
			if not headless and command.fire and not players[mine].dead and intermission<=0 and visual_cooldown<=0 and W.can_fire(players[mine].weapon,players[mine].ammo):
				predicted_shot_clock = clock
				_play_shot_fx(mine,players[mine].weapon)
	if multiplayer.is_server():
		_server_tick(delta)
		snapshot_accumulator += delta
		if snapshot_accumulator>=.05:
			snapshot_accumulator = 0
			_record_history()
			_send_snapshot()
	else:
		for id in fighters:
			if id==mine: continue
			fighters[id].position = fighters[id].position.lerp(fighters[id].target,minf(delta*16,1))
			fighters[id].rotation.y = lerp_angle(fighters[id].rotation.y,fighters[id].target_yaw,minf(delta*16,1))
	ping_accumulator += delta
	if ping_accumulator>1 and not multiplayer.is_server():
		ping_accumulator = 0
		_ping.rpc_id(1,Time.get_ticks_msec())
	for lift in lifts:
		var phase := fmod(time_limit-round_left,10.0)
		lift.node.position.y = lift.base + clampf((phase-2)/2,0,1)*float(lift.get("travel",1.65)) if phase<6 else lift.base+clampf((10-phase)/2,0,1)*float(lift.get("travel",1.65))

func _server_tick(delta: float) -> void:
	for id in pending_joins.keys():
		if clock>pending_joins[id]:
			multiplayer.multiplayer_peer.disconnect_peer(id)
			pending_joins.erase(id)
	if intermission>0:
		intermission -= delta
		if intermission<=0: _restart_round()
		return
	round_left = maxf(0,round_left-delta)
	if round_left<=0:
		_end_round()
		return
	if practice and is_instance_valid(bots): bots.tick(delta)
	for id in players:
		var s: Dictionary = players[id]
		if s.dead:
			if clock>=s.respawn_at and (s.want_respawn or clock>s.respawn_at+3 or id<0): _spawn(id)
			continue
		if clock-s.last_input>.35:
			s.move = Vector2.ZERO
			s.room=Vector3.ZERO
			s.fire = false
		fighters[id].simulate(s.move*(1.0-minf(s.room.length()*30/(5.2 if s.slow else 9.4),1.0)),s.yaw,s.slow,delta,s.jump)
		if not s.xr.is_empty():
			var shift: Vector3=s.room*delta*30.0
			fighters[id].move_and_collide(Basis(Vector3.UP,s.yaw)*shift)
			if id==multiplayer.get_unique_id() and is_vr(): xr_rig.origin_offset-=shift
		if fighters[id].position.y < fall_limit:
			_damage(id,id,1000,"fell out of the arena",true)
			continue
		s.cooldown = maxf(0,s.cooldown-delta)
		if s.charge>0:
			s.charge -= delta
			if s.charge<=0: _launch(id,8)
		if s.fire and s.cooldown<=0: _fire(id)
		if not s.fire: s.held = false
		_collect(id)
	_update_projectiles(delta)
	for pickup in pickups:
		if not pickup.available and clock>=pickup.respawn: pickup.available = true
	for gate in gates:
		if gate.open and clock>gate.until:
			var clear := true
			for actor in fighters.values():
				var offset: Vector3 = actor.position-gate.get("center",gate.node.position)
				offset.y = 0
				if offset.length()<1.3: clear = false
			if clear:
				gate.open = false
				_gate_state.rpc(gates.find(gate),false)

func _collect(id: int) -> void:
	var s: Dictionary = players[id]
	for p in pickups:
		if not p.available or fighters[id].position.distance_to(p.position) > .85: continue
		var took := false
		match p.kind:
			"weapon":
				var ammo_type: int = W.DATA[p.item].ammo
				if not s.owned.has(p.item):
					s.owned.append(p.item)
					s.weapon = p.item
					s.cooldown = maxf(s.cooldown,.25)
					took = true
				if ammo_type>=0 and s.ammo[ammo_type]<W.MAX_AMMO[ammo_type]:
					s.ammo[ammo_type] = mini(W.MAX_AMMO[ammo_type],s.ammo[ammo_type]+[20,8,2,40][ammo_type])
					took = true
			"ammo":
				if s.ammo[p.item]<W.MAX_AMMO[p.item]:
					s.ammo[p.item] = mini(W.MAX_AMMO[p.item],s.ammo[p.item]+[50,20,5,100][p.item])
					took = true
			"health":
				var maximum := 200 if p.item==100 else 100
				if s.hp<maximum:
					s.hp = mini(maximum,s.hp+p.item)
					took = true
			"bonus":
				if s.hp<200:
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
			_pickup_event.rpc(id,p.kind,p.item,s.weapon)

@rpc("authority","call_local","reliable",0)
func _pickup_event(id: int,kind: String,item: int,weapon: int) -> void:
	if fighters.has(id): effects.play("pickup",fighters[id].position,-12)
	if id==multiplayer.get_unique_id():
		desired_weapon = weapon
		last_event = (W.DATA[item].name if kind=="weapon" else kind.to_upper())+" acquired"
		if hud: hud.toast(last_event)

func _fire(id: int) -> void:
	if _weapon_blocked(id): return
	var s: Dictionary = players[id]
	var w: int = s.weapon
	if not W.can_fire(w,s.ammo):
		for choice in [7,4,5,3,2,1,0]:
			if s.owned.has(choice) and W.can_fire(choice,s.ammo):
				s.weapon = choice
				_pickup_event.rpc(id,"weapon",choice,choice)
				break
		return
	var d: Dictionary = W.DATA[w]
	if d.ammo>=0: s.ammo[d.ammo] -= d.cost
	s.cooldown = d.cycle
	s.invulnerable = 0
	s.shots += 1
	_shot_fx.rpc(id,w)
	if w==8:
		s.charge = d.charge
	elif w>=6:
		_launch(id,w)
	else:
		var start: Vector3 = _shot_origin(id)
		var endpoints := PackedVector3Array()
		for pellet in range(d.pellets):
			var spread: float = 0.0 if (w==2 or w==5) and not s.held else d.spread
			var yaw: float = s.yaw+deg_to_rad((randf()-randf())*spread)
			var pitch: float = s.pitch+deg_to_rad((randf()-randf())*d.vertical)
			var direction := W.direction(yaw,pitch)
			if not s.xr.is_empty():
				direction=_weapon_transform(id).basis*W.direction(yaw-s.yaw,pitch-s.pitch)
			var hit := _trace(start,start+direction*d.range,id,minf(s.ping/2000.0,.2))
			endpoints.append(hit.position)
			if hit.id!=0: _damage(hit.id,id,d.damage*randi_range(1,d.dice),d.name,false,hit.position,direction)
		_impacts.rpc(start,endpoints,w)
	s.held = true

func _trace(start: Vector3,end: Vector3,exclude: int,rewind: float = 0.0) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start,end,1)
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = wall.get("position",end)
	var nearest_distance := start.distance_to(point)
	var target := 0
	var old: Dictionary = {}
	if rewind>0:
		for sample in history:
			if sample.time<=clock-rewind: old = sample.positions
	for id in players:
		if id==exclude or players[id].dead: continue
		var position: Vector3 = old.get(id,fighters[id].position)
		for height in [.32,.62,.92,1.22,1.38]:
			var hits := Geometry3D.segment_intersects_sphere(start,end,position+Vector3.UP*height,.32)
			if not hits.is_empty():
				var distance := start.distance_to(hits[0])
				if distance<nearest_distance:
					nearest_distance = distance
					point = hits[0]
					target = id
	return {"id":target,"position":point,"hit":target!=0 or not wall.is_empty()}

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
	var node: Node3D = null
	if not headless:
		node = Node3D.new()
		add_child(node)
		node.position = pos
		var ball := SphereMesh.new()
		ball.radius = .27 if weapon==8 else .10
		ball.height = ball.radius*2
		var mesh := MeshInstance3D.new()
		mesh.mesh = ball
		mesh.material_override = Art.material(W.COLORS[weapon],0,3)
		node.add_child(mesh)
	projectiles[id] = {"owner":owner_id,"weapon":weapon,"position":pos,"direction":direction,"life":4.0,"node":node,"yaw":yaw,"pitch":pitch}

func _update_projectiles(delta: float) -> void:
	for id in projectiles.keys():
		var p: Dictionary = projectiles[id]
		p.life -= delta
		var end: Vector3 = p.position+p.direction*W.DATA[p.weapon].speed*delta
		var hit := _trace(p.position,end,p.owner)
		if hit.hit or p.life<=0:
			var d: Dictionary = W.DATA[p.weapon]
			if hit.id!=0: _damage(hit.id,p.owner,d.damage*randi_range(1,d.dice),d.name,false,hit.position,p.direction)
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
	for id in players:
		if players[id].dead: continue
		var target: Vector3 = fighters[id].position+Vector3.UP*.85
		var distance := maxf(0,pos.distance_to(target)-.3)
		if distance>=radius: continue
		var query := PhysicsRayQueryParameters3D.create(pos+(target-pos).normalized()*.06,target,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		_damage(id,owner_id,maxi(1,int(damage*(1-distance/radius))),"ROCKET LAUNCHER",false,target,(target-pos).normalized())

func _damage(victim: int,attacker: int,amount: int,weapon_name: String,bypass: bool = false,impact: Vector3=Vector3.INF,direction: Vector3=Vector3.ZERO) -> void:
	if not multiplayer.is_server() or not players.has(victim): return
	var s: Dictionary = players[victim]
	if s.dead or intermission>0 or (s.invulnerable>clock and not bypass): return
	var damage := W.armor_damage(amount,s.armor,s.tier)
	var old_hp: int=s.hp
	s.hp = maxi(0,s.hp-damage.x)
	s.armor = damage.y
	if attacker!=victim and players.has(attacker): _hit_confirm.rpc(attacker)
	if not impact.is_finite(): impact=fighters[victim].position+Vector3.UP
	if direction.length()<.1 and fighters.has(attacker): direction=(fighters[victim].position-fighters[attacker].position).normalized()
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
		players[attacker].kills += -1 if attacker==victim else 1
	_announcement.rpc("%s  →  %s   ·   %s" % [killer,s.name,weapon_name])
	if players.has(attacker) and players[attacker].kills>=frag_limit: _end_round()

func _end_round() -> void:
	intermission = 10
	var winner := "No winner"
	var score := -999
	for s in players.values():
		if s.kills>score:
			score = s.kills
			winner = s.name
	round_message = "%s wins · %d frags" % [winner,score]
	_announcement.rpc(round_message)

func _restart_round() -> void:
	round_left = time_limit
	round_message = ""
	for id in players:
		players[id].kills = 0
		players[id].deaths = 0
		_spawn(id)
	for p in pickups: p.available = true
	for id in projectiles.keys(): _projectile_end.rpc(id,projectiles[id].position,7)
	_announcement.rpc("New round · frag limit %d" % frag_limit)

func _record_history() -> void:
	var positions: Dictionary = {}
	for id in fighters: positions[id] = fighters[id].position
	history.append({"time":clock,"positions":positions})
	while history.size()>7: history.pop_front()

func _send_snapshot() -> void:
	var data: Array = []
	for id in players:
		var s: Dictionary = players[id]
		data.append([id,fighters[id].position,fighters[id].velocity,s.yaw,s.pitch,s.hp,s.armor,s.dead,s.weapon,s.ammo,s.owned,s.kills,s.deaths,s.ping,s.serial,maxf(0,s.respawn_at-clock),s.invulnerable>clock,s.cooldown,s.xr])
	var items := PackedByteArray()
	for p in pickups: items.append(1 if p.available else 0)
	var shots: Array = []
	for id in projectiles:
		var p: Dictionary = projectiles[id]
		shots.append([id,p.position,p.owner,p.weapon,p.direction,p.yaw,p.pitch])
	var gate_states: Array = []
	for gate in gates: gate_states.append(gate.open)
	_snapshot.rpc(data,items,round_left,intermission,round_message,frag_limit,time_limit,shots,gate_states)

@rpc("authority","call_local","unreliable_ordered",1)
func _snapshot(data: Array,items: PackedByteArray,remaining: float,pause: float,message: String,limit: int,duration: float,shots: Array,gate_states: Array) -> void:
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
			s.merge({"yaw":row[3],"pitch":row[4],"hp":row[5],"armor":row[6],"dead":row[7],"weapon":row[8],"ammo":row[9],"owned":row[10],"kills":row[11],"deaths":row[12],"ping":row[13],"serial":row[14],"cooldown":row[17]},true)
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
			actor.gibbed=false
			if not headless: effects.play("spawn",row[1],-15)
			actor.position = row[1]
			actor.velocity = row[2]
			if id==mine:
				local_yaw = row[3]
				local_pitch = 0
				desired_weapon = row[8]
				if is_vr(): xr_rig.on_spawn()
		actor.xr_pose=row[18] if row.size()>18 else {}
		actor.visual_velocity = row[2]
		actor.visual_pitch = row[4]
		actor.visual_weapon = row[8]
		actor.show_alive(not s.dead,id==mine and not dedicated)
		if id==mine:
			if s.hp<last_local_hp: hurt_flash = .45
			last_local_hp = s.hp
	for i in range(mini(items.size(),pickups.size())):
		if not multiplayer.is_server(): pickups[i].available = items[i]==1
		if is_instance_valid(pickups[i].node): pickups[i].node.visible = items[i]==1
	for shot in shots:
		if multiplayer.is_server(): continue
		if not projectiles.has(shot[0]): _projectile_spawn(shot[0],shot[2],shot[3],shot[1],shot[4],shot[5],shot[6])
		projectiles[shot[0]].position = shot[1]
	if not multiplayer.is_server():
		var live_shots: Array = shots.map(func(shot): return shot[0])
		for id in projectiles.keys():
			if not live_shots.has(id):
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
	if not players.has(id) or players[id].dead or clock<players[id].use_at: return
	players[id].use_at = clock+.5
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
	if not cleaned.is_empty(): _announcement.rpc(players[id].name+": "+cleaned)

@rpc("authority","call_local","reliable",0)
func _announcement(message: String) -> void:
	feed.append({"text":message,"until":clock+8})
	while feed.size()>5: feed.pop_front()
	last_event = message
	print("DM_EVENT ",message)

@rpc("authority","call_local","unreliable",3)
func _hit_confirm(id: int) -> void:
	if id==multiplayer.get_unique_id(): hit_flash = .14

@rpc("authority","call_local","unreliable",3)
func _shot_fx(id: int,weapon: int) -> void:
	if id==multiplayer.get_unique_id() and not multiplayer.is_server() and clock-predicted_shot_clock<.5: return
	_play_shot_fx(id,weapon)

func _play_shot_fx(id: int,weapon: int) -> void:
	if fighters.has(id): fighters[id].animate_fire()
	if headless: return
	if id==multiplayer.get_unique_id():
		recoil = 1
		visual_cooldown = W.DATA[weapon].cycle
		if is_vr(): xr_rig.feedback(.25 if weapon<3 else .65)
		if camera and weapon>=2 and weapon!=8:
			var flash := OmniLight3D.new()
			flash.light_color = W.COLORS[weapon]
			flash.light_energy = 2.4
			flash.omni_range = 2.7
			camera.add_child(flash)
			flash.position = camera.to_local(viewmodel.to_global(viewmodel.get_meta("muzzle",Vector3(0,0,-.6)))) if is_instance_valid(viewmodel) else Vector3(.02,-.18,-.8)
			if is_vr() and is_instance_valid(xr_rig.gun): flash.global_position=xr_rig.gun.to_global(xr_rig.gun.get_meta("muzzle",Vector3(0,0,-.6)))
			var spark := Art.box(flash,Vector3.ZERO,Vector3(.08,.07,.10),Art.material(W.COLORS[weapon],0,5))
			spark.rotation.z = randf()*PI
			get_tree().create_timer(.055).timeout.connect(flash.queue_free)
	if fighters.has(id):
		spatial.play("weapon_"+str(weapon),_weapon_transform(id).origin if multiplayer.is_server() else fighters[id].position+Vector3.UP,-4)

@rpc("authority","call_local","unreliable",3)
func _impacts(start: Vector3,ends: PackedVector3Array,weapon: int) -> void:
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
		var tracer := Art.box(self,(start+end)/2,Vector3(.013,.013,length),Art.material(W.COLORS[weapon],0,1))
		tracer.look_at(end)
		get_tree().create_timer(.055).timeout.connect(tracer.queue_free)

@rpc("authority","call_local","reliable",0)
func _projectile_end(id: int,pos: Vector3,weapon: int) -> void:
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
	if headless: return
	hurt_flash = maxf(0,hurt_flash-delta)
	hit_flash = maxf(0,hit_flash-delta)
	recoil = move_toward(recoil,0,delta*7)
	visual_cooldown = maxf(0,visual_cooldown-delta)
	for p in pickups:
		if p.available and is_instance_valid(p.node):
			var display := p.node.get_node("Display") as Node3D
			display.rotation.y += delta*.8
			display.position.y = .58+sin(clock*2)*.05
	for p in projectiles.values():
		if not multiplayer.is_server() and intermission<=0: p.position += p.direction*W.DATA[p.weapon].speed*delta
		if is_instance_valid(p.node): p.node.position = p.position
	if is_vr(): return
	if not camera or not active: return
	var s := local_state()
	if s.is_empty(): return
	if s.weapon!=model_weapon:
		if is_instance_valid(viewmodel): viewmodel.queue_free()
		viewmodel = Art.weapon(s.weapon)
		viewmodel.scale = Vector3.ONE*.72
		camera.add_child(viewmodel)
		model_weapon = s.weapon
	camera.rotation.x = local_pitch
	camera.position.y = lerpf(camera.position.y,.35 if s.dead else 1.48,delta*8)
	fighters[multiplayer.get_unique_id()].rotation.y = local_yaw
	viewmodel.visible = not s.dead and not menu_open
	var speed: float = fighters[multiplayer.get_unique_id()].velocity.length()
	viewmodel.position = Vector3(.18+sin(clock*10)*minf(speed*.003,.025),-.24+absf(cos(clock*10))*minf(speed*.003,.025)-recoil*.035,-.48+recoil*.075)
	viewmodel.rotation = Vector3(recoil*.10,.10,0)
	if s.weapon==3 and visual_cooldown>.25 and visual_cooldown<.8: viewmodel.rotation.x -= sin((visual_cooldown-.25)/.55*PI)*.22
	if s.weapon==4 and visual_cooldown>.3 and visual_cooldown<1.3: viewmodel.rotation.x -= sin((visual_cooldown-.3)*PI)*.38

func _load_map(map_id: String) -> bool:
	if current_map==map_id and $Map.get_child_count()>0: return true
	var info: Dictionary = {}
	for row in map_catalog:
		if row.id==map_id: info=row; break
	if info.is_empty(): return false
	var scene: PackedScene=load(info.scene)
	if not scene: return false
	for child in $Map.get_children(): child.free()
	pickups.clear()
	gates.clear()
	lifts.clear()
	spawn_points.clear()
	spawn_yaws.clear()
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

func is_vr() -> bool:
	return is_instance_valid(xr_rig) and xr_rig.enabled
func _weapon_transform(id: int) -> Transform3D:
	var s: Dictionary=players[id]
	if not s.xr.is_empty(): return Transform3D(Basis(Vector3.UP,s.yaw),fighters[id].position)*s.xr.weapon
	return Transform3D(Basis(Vector3.UP,s.yaw)*Basis(Vector3.RIGHT,s.pitch),fighters[id].position+Vector3.UP*1.45)
func _shot_origin(id: int) -> Vector3:
	var transform_here:=_weapon_transform(id)
	if players[id].xr.is_empty(): return transform_here.origin
	var offset: Vector3=Vector3(0,.025,.22-Art.WEAPON_LENGTHS[players[id].weapon])*.65
	return transform_here*offset
func _weapon_blocked(id: int) -> bool:
	if not players.has(id) or players[id].xr.is_empty(): return false
	var from: Vector3=fighters[id].position+Vector3.UP*1.25
	var query:=PhysicsRayQueryParameters3D.create(from,_shot_origin(id),1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

@rpc("authority","call_local","reliable",0)
func _hurt_fx(id: int,pos: Vector3,direction: Vector3,amount: int,dead: bool,gibbed: bool,seed_value: int) -> void:
	effects.hit(id,pos,direction,amount,dead,gibbed,seed_value)

@rpc("authority","call_local","unreliable",3)
func _teleport_fx(pos: Vector3) -> void:
	effects.play("teleport",pos)
