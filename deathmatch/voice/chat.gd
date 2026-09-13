extends "res://deathmatch/voice/relay.gd"
const Speaker=preload("res://addons/twovoip/voiphelper/two_voip_speaker.gd")
const Microphone=preload("res://deathmatch/voice/microphone.gd")
const Visemes=preload("res://deathmatch/voice/visemes.gd")
const Preferences=preload("res://deathmatch/voice/preferences.gd")
var input_device:="Default"
const Permissions=preload("res://deathmatch/vr/permissions.gd")
var muted_all:=false
var muted: Dictionary={}
var threshold:=0.018
var meter:=0.0
var message:="Push-to-talk · hold V / off-hand grip"
var hangover:=0.0
var streams: Dictionary={}
var mouth_poses: Dictionary={}
var received_packets:=0
var decoded_packets:=0
var permission_wait:=false
var panel: Control
var test_receive:=false
var radio_active:=false
var radio_audio: Node
var channel_serial: Dictionary={}

func setup(arena: Node) -> void:
	super.setup(arena)
	load_preferences()
	if not game.headless:
		radio_audio=preload("res://deathmatch/voice/radio_audio.gd").new();add_child(radio_audio);radio_audio.setup()
	if not game.headless:
		apply_input_device()
		panel=preload("res://deathmatch/voice/panel.gd").new()
		add_child(panel)
		panel.setup(self)
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
	# WASAPI/OpenXR headset inputs can disappear or change rate during a switch.
	# Release capture before touching the driver, then create exactly one encoder.
	stop_capture()
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
		stop_capture();message="Microphone unavailable · select an input device and retry";return
	mic.transmit_audio_packet.connect(send_packet)
	message="TwoVoIP · hold V / off-hand grip" if mode==1 else "TwoVoIP · voice activation enabled"

func stop_capture() -> void:
	permission_wait=false;transmitting=false;meter=0;hangover=0;set_radio(false)
	if is_instance_valid(mic):
		mic.set_process(false);remove_child(mic);mic.queue_free();mic=null

func can_transmit() -> bool:
	return game.active and not game.practice and not game.dedicated and game.voice_enabled and game.players.has(multiplayer.get_unique_id()) and (not game.is_vr() or game.xr_rig.focused)

func set_radio(value: bool) -> void:
	value=value and team_available() and game.voice_enabled and mode>0
	if value==radio_active:return
	radio_active=value
	if is_instance_valid(radio_audio):radio_audio.cue(value,volume)

func team_channel() -> bool:
	return game.voice_enabled and mode>0 and team_available() and (radio_active or not game.is_vr() and game.bindings.pressed("team_ptt"))

func push_to_talk() -> bool:
	if team_channel():return true
	if game.is_vr():
		var rig=game.xr_rig
		return rig.focused and not rig.shoulder_radio.held and game.bindings.vr_pressed(rig,"ptt")
	return game.bindings.pressed("ptt")

func _process(delta: float) -> void:
	if not game.is_vr():set_radio(game.bindings.pressed("team_ptt") and can_transmit())
	if radio_active and not team_available():set_radio(false)
	for id in streams.keys():
		var state: Dictionary=streams[id]
		if not game.players.has(id) or game.clock-state.last_time>2 or state.get("team",false) and (not team_available(id) or not team_available() or not game.match_mode.same_team(id,multiplayer.get_unique_id())):remove_stream(id);continue
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
func create_stream(id: int,serial: int,team_only: bool=false) -> void:
	var player=AudioStreamPlayer.new() if game.headless or team_only else AudioStreamPlayer3D.new()
	if player is AudioStreamPlayer3D:
		player.unit_size=8;player.max_distance=60;player.attenuation_filter_cutoff_hz=18000
	if team_only and is_instance_valid(radio_audio):player.bus=radio_audio.bus
	add_child(player)
	var speaker=Speaker.new();speaker.audio_buffer_lag_time_target=.08;speaker.audio_buffer_lag_time_target_tolerance=.06;player.add_child(speaker)
	speaker.packet_decoded.connect(func():decoded_packets+=1)
	var header:={"opussamplerate":48000,"opuschannels":1,"lenchunkprefix":2,"opusstreamcount":0,"opusframesize":960,"opusframecount":0,"talkingtimestart":0}
	speaker.receive_audio_packet(JSON.stringify(header).to_ascii_buffer())
	streams[id]={"team":team_only,"player":player,"speaker":speaker,"base":serial,"last":serial-1,"seen":{},"last_time":game.clock}

func set_muted(id: int,value: bool) -> void:
	if value: muted[id]=true; remove_stream(id)
	else: muted.erase(id)

func remove_stream(id: int) -> void:
	if streams.has(id):
		var state: Dictionary=streams[id]
		if is_instance_valid(state.player):
			# Stop the audio callback immediately on mute/team change/channel switch.
			# Deferred node deletion alone can keep an Opus playback mixing until exit.
			state.speaker.set_physics_process(false)
			state.player.stop();state.player.stream=null
			state.speaker.audio_stream_playback_opus=null;state.speaker.audiostreamopus=null
			state.player.queue_free()
		streams.erase(id);mouth_poses.erase(id)

func remove_peer(id: int) -> void:
	remove_stream(id); guard.erase(id); muted.erase(id);channel_serial.erase(id)

func reset() -> void:
	for id in streams.keys(): remove_stream(id)
	guard.clear(); muted.clear();mouth_poses.clear();channel_serial.clear(); sequence=0;set_radio(false)
	game.voice_enabled=true
	set_mode(mode)

func _exit_tree() -> void:
	for id in streams.keys():remove_stream(id)
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

func _receive_audio(id: int,serial: int,data: PackedByteArray,team_only: bool=false) -> void:
	if not game.voice_enabled or not game.players.has(id) or id==multiplayer.get_unique_id() or muted_all or muted.has(id) or not valid_packet(data):return
	if team_only and (not team_available(id) or not team_available() or not game.match_mode.same_team(id,multiplayer.get_unique_id())):return
	if game.headless and not test_receive:return
	var channel: Dictionary=channel_serial.get(id,{"serial":-1,"team":team_only})
	if serial<=channel.serial and team_only!=channel.team:return
	if serial>channel.serial:channel_serial[id]={"serial":serial,"team":team_only}
	if streams.has(id) and streams[id].team!=team_only:remove_stream(id)
	if streams.has(id):
		var old: Dictionary=streams[id]
		if serial<old.base or serial<old.last-32 or old.seen.has(serial):return
		if serial>old.last+50 or serial-old.base>=32000 or game.clock-old.last_time>.16:remove_stream(id)
	if not streams.has(id):
		create_stream(id,serial,team_only)
		if team_only and is_instance_valid(radio_audio):radio_audio.cue(true,volume)
	var state: Dictionary=streams[id]
	state.last=maxi(state.last,serial);state.last_time=game.clock;state.seen[serial]=true
	for old in state.seen.keys():
		if old<state.last-32:state.seen.erase(old)
	var frame: int=serial-state.base
	var packet:=data.duplicate();packet[0]=frame&255;packet[1]=(frame>>8)&127
	state.speaker.receive_audio_packet(packet)
	received_packets+=1;packet_received.emit(id,serial,data)

func _policy_changed(allowed: bool) -> void:
	if game.voice_backend=="mumble":stop_capture();message="Server uses external Mumble · open your Mumble client below. Its audio and push-to-talk controls are separate."
	elif not allowed: stop_capture(); message="Voice disabled by host"
	else: set_mode(mode)
