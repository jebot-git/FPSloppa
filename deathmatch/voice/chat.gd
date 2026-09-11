extends Node
const Speaker=preload("res://addons/twovoip/voiphelper/two_voip_speaker.gd")
const Microphone=preload("res://deathmatch/voice/microphone.gd")
const Visemes=preload("res://deathmatch/voice/visemes.gd")
const Preferences=preload("res://deathmatch/voice/preferences.gd")
var input_device:="Default"
const Permissions=preload("res://deathmatch/vr/permissions.gd")
var game
var mode:=1 # 0 listen only, 1 push-to-talk (startup default), 2 voice activation.
var muted_all:=false
var muted: Dictionary={}
var volume:=0.8
var threshold:=0.018
var meter:=0.0
var transmitting:=false
var message:="Push-to-talk · hold V / off-hand grip"
var mic: Node
var sequence:=0
var hangover:=0.0
var streams: Dictionary={}
var mouth_poses: Dictionary={}
var guard: Dictionary={}
var received_packets:=0
var decoded_packets:=0
var relayed_packets:=0
var rejected_packets:=0
var permission_wait:=false
var panel: Control
var test_receive:=false

func setup(arena: Node) -> void:
	game=arena
	load_preferences()
	if not game.headless:
		apply_input_device()
		panel=preload("res://deathmatch/voice/panel.gd").new()
		add_child(panel)
		panel.setup(self)
	multiplayer.peer_disconnected.connect(remove_peer)
	game.permissions.completed.connect(_permission_result)
	if not game.headless: set_mode.call_deferred(mode)

func _permission_result(permission: String,allowed: bool) -> void:
	if permission!=Permissions.MICROPHONE: return
	permission_wait=false
	if mode==0 or not game.voice_enabled: return
	if allowed: start_capture()
	else: message="Microphone access denied · listening only. Use RETRY ACCESS or headset app permissions."

func load_preferences(path: String="") -> void:
	var saved:=Preferences.read_settings(path)
	mode=saved.mode;muted_all=saved.mute_all;threshold=saved.threshold;input_device=saved.input_device

func save_preferences(path: String="") -> void:
	var error:=Preferences.save_settings({"mode":mode,"mute_all":muted_all,"threshold":threshold,"input_device":input_device},path)
	if error!=OK:push_warning("Cannot save voice settings: "+error_string(error))

func apply_input_device() -> void:
	var available:=AudioServer.get_input_device_list()
	AudioServer.input_device=input_device if input_device in available else "Default"

func select_input_device(value: String) -> void:
	input_device=value;apply_input_device();save_preferences();set_mode(mode)

func set_mode(value: int,persist: bool=false) -> void:
	mode=clampi(value,0,2)
	if persist:save_preferences()
	stop_capture()
	if mode==0: message="Microphone off"; return
	if game.headless: return
	if not game.voice_enabled: message="Voice disabled by host"; return
	if not game.permissions.granted(Permissions.MICROPHONE):
		permission_wait=true
		message="Allow microphone access to speak"
		game.permissions.request(Permissions.MICROPHONE)
		return
	start_capture()

func retry_access() -> void:
	if mode>0 and not game.headless:
		game.permissions.request(Permissions.MICROPHONE,true)
	game.permissions.request_tracking(true)

func start_capture() -> void:
	if mic or mode==0 or game.headless or not game.voice_enabled or not game.permissions.granted(Permissions.MICROPHONE): return
	mic=Microphone.new();add_child(mic)
	if not mic.configure(self):
		mic.queue_free();mic=null;message="Microphone unavailable · select an input device and retry";return
	mic.transmit_audio_packet.connect(send_packet)
	message="TwoVoIP · hold V / off-hand grip" if mode==1 else "TwoVoIP · voice activation enabled"

func stop_capture() -> void:
	permission_wait=false;transmitting=false;meter=0;hangover=0
	if is_instance_valid(mic):
		mic.set_process(false);remove_child(mic);mic.queue_free();mic=null

func can_transmit() -> bool:
	return game.active and not game.practice and not game.dedicated and game.voice_enabled and game.players.has(multiplayer.get_unique_id()) and (not game.is_vr() or game.xr_rig.focused)

func push_to_talk() -> bool:
	if game.is_vr():
		var rig=game.xr_rig
		var hand=rig.right if rig.left_handed else rig.left
		return rig.focused and game.bindings.vr_pressed(rig,"ptt")
	return game.bindings.pressed("ptt")

func _process(delta: float) -> void:
	for id in streams.keys():
		var state: Dictionary=streams[id]
		if not game.players.has(id) or game.clock-state.last_time>2:remove_stream(id);continue
		var speaker=state.speaker
		if game.clock-state.last_time>.16 and speaker.inopusstream:speaker.external_end_stream()
		if game.fighters.has(id) and state.player is AudioStreamPlayer3D:state.player.global_position=game.fighters[id].global_position+Vector3.UP*1.55
		state.player.volume_db=linear_to_db(maxf(.0001,volume)) if not muted_all and not muted.has(id) else -80.0
		if speaker.audio_stream_playback_opus:
			var peak: float=speaker.audio_stream_playback_opus.get_chunk_max()
			if peak>.001:decoded_peak=maxf(decoded_peak,peak)
			var audible: bool=speaker.inopusstream or speaker.audio_stream_playback_opus.queue_length_frames()>0
			var opening: float=clampf(sqrt(maxf(0,peak-.004))*2.6,0,.9) if audible else 0.0
			set_mouth_pose(id,PackedFloat32Array([opening,0,0,0,0]))

	if panel:panel.refresh(delta)

var decoded_peak:=0.0
signal packet_received(id: int,serial: int,data: PackedByteArray)
static func valid_packet(data: PackedByteArray) -> bool:
	# Fixed 48 kHz mono, 20 ms Opus frames. The prefix is replaced by the relay sequence.
	return data.size()>=3 and data.size()<=400 and (data[2]>>3) in [1,5,9,13,15,19,23,27,31] and (data[2]&7)==0

func send_packet(data: PackedByteArray) -> void:
	sequence+=1
	if multiplayer.is_server():relay(multiplayer.get_unique_id(),sequence,data)
	else:submit.rpc_id(1,sequence,data)

@rpc("any_peer","call_remote","unreliable",6)
func submit(serial: int,data: PackedByteArray) -> void:
	if multiplayer.is_server():relay(multiplayer.get_remote_sender_id(),serial,data)

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

func relay(id: int,serial: int,data: PackedByteArray) -> void:
	if not accept_sender(id,serial,data):return
	for peer in game.players:
		if peer>1 and peer!=id:receive.rpc_id(peer,id,serial,data)
	if id!=1 and not game.dedicated:receive(id,serial,data)
	relayed_packets+=1

func create_stream(id: int,serial: int) -> void:
	var player=AudioStreamPlayer.new() if game.headless else AudioStreamPlayer3D.new()
	if player is AudioStreamPlayer3D:
		player.unit_size=8;player.max_distance=60;player.attenuation_filter_cutoff_hz=18000
	add_child(player)
	var speaker=Speaker.new();speaker.audio_buffer_lag_time_target=.08;speaker.audio_buffer_lag_time_target_tolerance=.06;player.add_child(speaker)
	speaker.packet_decoded.connect(func():decoded_packets+=1)
	var header:={"opussamplerate":48000,"opuschannels":1,"lenchunkprefix":2,"opusstreamcount":0,"opusframesize":960,"opusframecount":0,"talkingtimestart":0}
	speaker.receive_audio_packet(JSON.stringify(header).to_ascii_buffer())
	streams[id]={"player":player,"speaker":speaker,"base":serial,"last":serial-1,"seen":{},"last_time":game.clock}

@rpc("authority","call_remote","unreliable",6)
func receive(id: int,serial: int,data: PackedByteArray) -> void:
	if not game.voice_enabled or not game.players.has(id) or id==multiplayer.get_unique_id() or muted_all or muted.has(id) or not valid_packet(data):return
	if game.headless and not test_receive:return
	if streams.has(id):
		var old: Dictionary=streams[id]
		if serial<old.base or serial<old.last-32 or old.seen.has(serial):return
		if serial>old.last+50 or serial-old.base>=32000 or game.clock-old.last_time>.16:remove_stream(id)
	if not streams.has(id):create_stream(id,serial)
	var state: Dictionary=streams[id]
	state.last=maxi(state.last,serial);state.last_time=game.clock;state.seen[serial]=true
	for old in state.seen.keys():
		if old<state.last-32:state.seen.erase(old)
	var frame: int=serial-state.base
	var packet:=data.duplicate();packet[0]=frame&255;packet[1]=(frame>>8)&127
	state.speaker.receive_audio_packet(packet)
	received_packets+=1;packet_received.emit(id,serial,data)

@rpc("authority","call_remote","reliable",0)
func policy(allowed: bool,host_name: String,backend: String="builtin",external_url: String="") -> void:
	game.voice_backend=backend if backend in ["builtin","mumble"] else "builtin"
	game.mumble_url=external_url if preload("res://deathmatch/voice/external.gd").valid_url(external_url) else ""
	game.voice_enabled=allowed and game.voice_backend=="builtin"
	game.server_name=host_name
	if game.voice_backend=="mumble":stop_capture();message="Server uses external Mumble · open your Mumble client below. Its audio and push-to-talk controls are separate."
	elif not allowed: stop_capture(); message="Voice disabled by host"
	else: set_mode(mode)

func set_muted(id: int,value: bool) -> void:
	if value: muted[id]=true; remove_stream(id)
	else: muted.erase(id)

func remove_stream(id: int) -> void:
	if streams.has(id):
		if is_instance_valid(streams[id].player): streams[id].player.queue_free()
		streams.erase(id);mouth_poses.erase(id)

func remove_peer(id: int) -> void:
	remove_stream(id); guard.erase(id); muted.erase(id)

func reset() -> void:
	for id in streams.keys(): remove_stream(id)
	guard.clear(); muted.clear();mouth_poses.clear(); sequence=0
	game.voice_enabled=true
	set_mode(mode)

func _exit_tree() -> void:
	stop_capture()

func animate_mouth(id: int,samples: PackedVector2Array) -> void:
	set_mouth_pose(id,Visemes.analyze(samples))
func set_mouth_pose(id: int,weights: PackedFloat32Array) -> void:
	mouth_poses[id]={"weights":weights,"until":game.clock+.14}
	if not game.fighters.has(id):return
	var actor=game.fighters[id]
	if actor.avatar_hash.is_empty() or not is_instance_valid(actor.avatar) or actor.avatar.dead:return
	if actor.avatar.mouth:actor.avatar.mouth.speak(weights)
func mouth_pose(id: int) -> PackedFloat32Array:
	var state: Dictionary=mouth_poses.get(id,{})
	return state.weights if state.get("until",0)>game.clock else PackedFloat32Array([0,0,0,0,0])
