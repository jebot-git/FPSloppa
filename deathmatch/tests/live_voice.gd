extends SceneTree
## Opt-in local recording of decoded TwoVoIP network playback, then packet replay.
var game
var packets: Array=[]
var pcm:=PackedByteArray()
var first_packet:=0
var recording:=true
var peak:=0.0
var energy:=0.0
var capture: AudioEffectCapture
var bus:=-1
func _initialize():call_deferred("run")
func run():
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.voice.test_receive=true
	game.start_join("Local voice recorder","127.0.0.1",29108,true)
	bus=AudioServer.bus_count;AudioServer.add_bus();AudioServer.set_bus_name(bus,"VoiceTestRecording");AudioServer.set_bus_mute(bus,true)
	capture=AudioEffectCapture.new();capture.buffer_length=.5;AudioServer.add_bus_effect(bus,capture)
	game.voice.packet_received.connect(on_packet)
	process_frame.connect(capture_audio)
	if OS.get_cmdline_user_args().has("--replay-only"):
		recording=false
		var saved=FileAccess.open("res://test-results/live-vr-microphone.opuspackets",FileAccess.READ)
		if not saved:quit(2);return
		packets=saved.get_var(false)
		var until:=Time.get_ticks_msec()+20000
		while not game.active and Time.get_ticks_msec()<until:await create_timer(.1).timeout
		if not game.active:quit(2);return
		await replay();return
	print("LIVE_VOICE_WAITING hold off-hand grip and speak; recording lasts 12 seconds after first packet")
	var deadline:=Time.get_ticks_msec()+180000
	while first_packet==0 and Time.get_ticks_msec()<deadline:await create_timer(.1).timeout
	if first_packet==0:push_error("LIVE_VOICE no push-to-talk packets received");quit(2);return
	while Time.get_ticks_msec()-first_packet<12000:await create_timer(.05).timeout
	recording=false
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=int(AudioServer.get_mix_rate());wav.stereo=false;wav.data=pcm
	var path:="res://test-results/live-vr-microphone.wav"
	var saved:=wav.save_to_wav(path)
	var archive:=FileAccess.open("res://test-results/live-vr-microphone.opuspackets",FileAccess.WRITE);archive.store_var(packets);archive.close()
	var report:={"received_packets":packets.size(),"decoded_seconds":pcm.size()/float(wav.mix_rate*2),"peak":peak,"rms":sqrt(energy/maxi(1,pcm.size()/2)),"saved":saved==OK,"path":path,"source":"WiVRn microphone, TwoVoIP RNNoise/Opus, local ENet relay, native jitter buffer and decoded playback capture"}
	var file:=FileAccess.open("res://test-results/live-vr-voice-result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("LIVE_VOICE_RECORDED ",JSON.stringify(report))
	await create_timer(2).timeout;await replay()
func on_packet(id: int,_serial: int,data: PackedByteArray):
	if not recording:return
	if first_packet==0:first_packet=Time.get_ticks_msec();capture.clear_buffer()
	packets.append(data)
	game.voice.streams[id].player.bus="VoiceTestRecording"
func capture_audio():
	if not recording or first_packet==0:return
	var frames:=capture.get_buffer(capture.get_frames_available())
	for sample in frames:
		var mono: float=(sample.x+sample.y)*.5
		peak=maxf(peak,absf(mono));energy+=mono*mono
		var offset:=pcm.size();pcm.resize(offset+2);pcm.encode_s16(offset,clampi(roundi(mono*32767),-32768,32767))
func replay():
	print("LIVE_VOICE_REPLAY_START")
	for packet in packets:
		game.voice.send_packet(packet);await create_timer(.02).timeout
	await create_timer(2).timeout;print("LIVE_VOICE_REPLAY_DONE")
	game.disconnect_game();AudioServer.remove_bus(bus);quit(0 if not packets.is_empty() else 1)
