extends Node
const Codec=preload("res://deathmatch/voice/codec.gd")
const Visemes=preload("res://deathmatch/voice/visemes.gd")
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
var mic: AudioStreamPlayer
var capture: AudioEffectCapture
var bus_index:=-1
var sequence:=0
var hangover:=0.0
var streams: Dictionary={}
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
	if not game.headless:
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

func set_mode(value: int) -> void:
	mode=clampi(value,0,2)
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
	bus_index=AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index,"VoiceCapture")
	AudioServer.set_bus_mute(bus_index,true) # Capture effect receives samples; never monitor own mic.
	capture=AudioEffectCapture.new()
	capture.buffer_length=.12
	AudioServer.add_bus_effect(bus_index,capture)
	mic=AudioStreamPlayer.new()
	mic.stream=AudioStreamMicrophone.new()
	mic.bus="VoiceCapture"
	add_child(mic)
	mic.play()
	message="Hold V / off-hand grip to talk" if mode==1 else "Voice activation enabled"

func stop_capture() -> void:
	permission_wait=false
	transmitting=false
	meter=0
	hangover=0
	if mic: mic.stop(); mic.queue_free(); mic=null
	capture=null
	if bus_index>=0:
		var index:=AudioServer.get_bus_index("VoiceCapture")
		if index>=0:AudioServer.remove_bus(index)
		bus_index=-1

func push_to_talk() -> bool:
	if game.is_vr():
		var rig=game.xr_rig
		var hand=rig.right if rig.left_handed else rig.left
		return rig.focused and (rig.simulated or hand.get_has_tracking_data()) and hand.get_float("grip")>.6
	return Input.is_physical_key_pressed(KEY_V)

func _process(delta: float) -> void:
	if mode==1 and not push_to_talk(): transmitting=false
	if capture:
		var can_send: bool=game.active and not game.practice and not game.dedicated and game.voice_enabled and game.players.has(multiplayer.get_unique_id())
		if game.is_vr() and not game.xr_rig.focused: can_send=false
		if not can_send:
			capture.clear_buffer(); transmitting=false; meter=0
		else:
			# 20 ms at the device's mixer rate, averaged into 16 kHz mono bins.
			var count:=roundi(AudioServer.get_mix_rate()*.02)
			var budget:=3
			while capture.can_get_buffer(count) and budget>0:
				budget-=1
				var input:=capture.get_buffer(count)
				var samples:=PackedFloat32Array()
				samples.resize(Codec.FRAMES)
				var energy:=0.0
				for i in range(Codec.FRAMES):
					var begin:=int(i*count/float(Codec.FRAMES))
					var end:=maxi(begin+1,int((i+1)*count/float(Codec.FRAMES)))
					var value:=0.0
					for j in range(begin,mini(end,count)): value+=(input[j].x+input[j].y)*.5
					value/=end-begin
					samples[i]=clampf(value,-1,1); energy+=value*value
				meter=sqrt(energy/Codec.FRAMES)
				if meter>threshold: hangover=.18
				else: hangover=maxf(0,hangover-.02)
				transmitting=push_to_talk() if mode==1 else hangover>0
				if transmitting:
					var packet:=Codec.encode(samples)
					animate_mouth(multiplayer.get_unique_id(),Codec.decode(packet))
					send_packet(packet)
			if capture.get_frames_available()>count*3: capture.clear_buffer()
	for id in streams.keys():
		var state: Dictionary=streams[id]
		if not game.players.has(id) or game.clock-state.last_time>2: remove_peer(id); continue
		while not state.mouth_queue.is_empty() and state.mouth_queue[0][0]<=game.clock:
			animate_mouth(id,state.mouth_queue.pop_front()[1])
		if state.queue.is_empty(): state.started=false; continue
		if not state.started:
			if state.queue.size()<3 and game.clock-state.first_time<.06: continue
			state.started=true
		if state.playback==null and is_instance_valid(state.player) and state.player.has_method("get_inner_stream_playback"):
			state.playback=state.player.get_inner_stream_playback()
		var playback=state.playback
		if playback:
			while not state.queue.is_empty() and playback.get_frames_available()>=Codec.FRAMES:
				var decoded:=Codec.decode(state.queue.pop_front())
				var delay:=maxf(0,.12-playback.get_frames_available()/float(Codec.RATE))
				state.mouth_queue.append([game.clock+delay,decoded])
				playback.push_buffer(decoded)
			if game.fighters.has(id): state.player.global_position=game.fighters[id].global_position+Vector3.UP*1.55
			game.spatial.update_source(state.player,linear_to_db(volume) if not muted_all and not muted.has(id) else -80.0)
		elif test_receive:
			while not state.queue.is_empty():
				if Codec.decode(state.queue.pop_front()).size()==Codec.FRAMES: decoded_packets+=1
	if panel: panel.refresh(delta)

func send_packet(data: PackedByteArray) -> void:
	sequence+=1
	if multiplayer.is_server(): relay(multiplayer.get_unique_id(),sequence,data)
	else: submit.rpc_id(1,sequence,data)

@rpc("any_peer","call_remote","unreliable_ordered",6)
func submit(serial: int,data: PackedByteArray) -> void:
	if multiplayer.is_server(): relay(multiplayer.get_remote_sender_id(),serial,data)

func accept_sender(id: int,serial: int,data: PackedByteArray) -> bool:
	if not game.active or not game.voice_enabled or not game.players.has(id) or id<1 or not Codec.valid(data) or serial<0 or serial>2147483647:
		rejected_packets+=1; return false
	var state: Dictionary=guard.get(id,{"last":-1,"tokens":8.0,"time":game.clock})
	state.tokens=minf(8,state.tokens+maxf(0,game.clock-state.time)*55)
	state.time=game.clock
	guard[id]=state
	if serial<=state.last or state.tokens<1:
		rejected_packets+=1; return false
	state.last=serial; state.tokens-=1
	return true

func relay(id: int,serial: int,data: PackedByteArray) -> void:
	if not accept_sender(id,serial,data): return
	for peer in game.players:
		if peer>1 and peer!=id: receive.rpc_id(peer,id,serial,data)
	if id!=1 and not game.dedicated: receive(id,serial,data)
	relayed_packets+=1

@rpc("authority","call_remote","unreliable_ordered",6)
func receive(id: int,serial: int,data: PackedByteArray) -> void:
	if not game.voice_enabled or not game.players.has(id) or id==multiplayer.get_unique_id() or muted_all or muted.has(id) or not Codec.valid(data): return
	if game.headless and not test_receive: return
	if not streams.has(id):
		var player: AudioStreamPlayer3D
		var playback
		if not game.headless:
			player=game.spatial.create_player()
			game.spatial.configure(player,true)
			var generator:=AudioStreamGenerator.new()
			generator.mix_rate=Codec.RATE
			generator.buffer_length=.12
			player.stream=generator
			add_child(player)
			player.play()
			playback=null if player.has_method("get_inner_stream_playback") else player.get_stream_playback()
		streams[id]={"player":player,"playback":playback,"mouth_queue":[],"queue":[],"last":-1,"last_time":game.clock,"first_time":game.clock,"started":false}
	var state: Dictionary=streams[id]
	if serial<=state.last: return
	if state.queue.is_empty(): state.first_time=game.clock
	# Conceal short losses with silence, never retransmit stale speech.
	var silence:=PackedFloat32Array(); silence.resize(Codec.FRAMES)
	for i in range(mini(2,maxi(0,serial-state.last-1))):
		if state.last>=0: state.queue.append(Codec.encode(silence))
	state.last=serial; state.last_time=game.clock
	state.queue.append(data)
	while state.queue.size()>6: state.queue.pop_front()
	received_packets+=1

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
		streams.erase(id)

func remove_peer(id: int) -> void:
	remove_stream(id); guard.erase(id); muted.erase(id)

func reset() -> void:
	for id in streams.keys(): remove_stream(id)
	guard.clear(); muted.clear(); sequence=0
	game.voice_enabled=true
	set_mode(mode)

func _exit_tree() -> void:
	stop_capture()

func animate_mouth(id: int,samples: PackedVector2Array) -> void:
	if not game.fighters.has(id): return
	var actor=game.fighters[id]
	if actor.avatar_hash.is_empty() or not is_instance_valid(actor.avatar) or actor.avatar.dead: return
	if actor.avatar.mouth: actor.avatar.mouth.speak(Visemes.analyze(samples))
