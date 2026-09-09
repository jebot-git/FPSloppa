extends SceneTree
## Explicit, local-only live microphone verification. Never used by normal gameplay.
const Codec=preload("res://deathmatch/voice/codec.gd")
var game
var packets:Array[PackedByteArray]=[]
var pcm:=PackedByteArray()
var first_packet:=0
var recording:=true
var peak:=0.0
var energy:=0.0
func _initialize():call_deferred("run")
func run():
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.voice.test_receive=true
	game.start_join("Local voice recorder","127.0.0.1",29108,true)
	if OS.get_cmdline_user_args().has("--replay-only"):
		recording=false
		var until:=Time.get_ticks_msec()+20000
		while not game.active and Time.get_ticks_msec()<until:await create_timer(.1).timeout
		if not game.active:quit(2);return
		var wav:=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://test-results/live-vr-microphone.wav"))
		if wav==null:quit(2);return
		for offset in range(0,wav.data.size()-Codec.FRAMES*2+1,Codec.FRAMES*2):
			var samples:=PackedFloat32Array();samples.resize(Codec.FRAMES)
			for i in range(Codec.FRAMES):samples[i]=wav.data.decode_s16(offset+i*2)/32768.0
			packets.append(Codec.encode(samples))
		await create_timer(2).timeout
		await replay();return
	process_frame.connect(capture_packets)
	print("LIVE_VOICE_WAITING hold off-hand grip and speak; recording lasts 12 seconds after first packet")
	var deadline:=Time.get_ticks_msec()+180000
	while first_packet==0 and Time.get_ticks_msec()<deadline:await create_timer(.1).timeout
	if first_packet==0:push_error("LIVE_VOICE no push-to-talk packets received");quit(2);return
	while Time.get_ticks_msec()-first_packet<12000:await create_timer(.05).timeout
	recording=false
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=Codec.RATE;wav.stereo=false;wav.data=pcm
	var path:="res://test-results/live-vr-microphone.wav"
	var saved:=wav.save_to_wav(path)
	var report:={"received_packets":packets.size(),"decoded_seconds":pcm.size()/32000.0,"peak":peak,"rms":sqrt(energy/maxi(1,pcm.size()/2)),"saved":saved==OK,"path":path,"source":"WiVRn headset microphone via live host capture, PTT, ADPCM and local ENet peer"}
	var file:=FileAccess.open("res://test-results/live-vr-voice-result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("LIVE_VOICE_RECORDED ",JSON.stringify(report))
	await create_timer(2).timeout
	await replay()
func replay():
	print("LIVE_VOICE_REPLAY_START")
	for packet in packets:
		game.voice.send_packet(packet)
		await create_timer(.02).timeout
	await create_timer(2).timeout
	print("LIVE_VOICE_REPLAY_DONE")
	game.disconnect_game();quit(0 if not packets.is_empty() else 1)
func capture_packets():
	if not recording or not game:return
	for state in game.voice.streams.values():
		while not state.queue.is_empty():
			var packet:PackedByteArray=state.queue.pop_front()
			if first_packet==0:first_packet=Time.get_ticks_msec()
			packets.append(packet)
			var samples:=Codec.decode(packet)
			for sample in samples:
				peak=maxf(peak,absf(sample.x));energy+=sample.x*sample.x
				var offset:=pcm.size();pcm.resize(offset+2);pcm.encode_s16(offset,clampi(roundi(sample.x*32767),-32768,32767))
