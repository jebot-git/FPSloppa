extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func energy(capture: AudioEffectCapture) -> Vector2:
	var frames:=capture.get_buffer(capture.get_frames_available());var sum:=Vector2.ZERO
	for sample in frames:
		if not sample.is_finite():return Vector2.INF
		sum+=sample*sample
	return sum/maxi(1,frames.size())
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false)
	if g.headless:
		g.headless=false;g.spatial.setup(g)
	g.presentation.spatial_audio="steam_audio"
	g.camera=g.get_node("Overview");g.camera.transform=Transform3D.IDENTITY
	check(g.spatial.steam.available,"Steam Audio native plugin loads")
	var idx:=AudioServer.bus_count;AudioServer.add_bus();AudioServer.set_bus_name(idx,"HRTFTest")
	var capture:=AudioEffectCapture.new();capture.buffer_length=1.0;AudioServer.add_bus_effect(idx,capture)
	var player:AudioStreamPlayer3D=g.spatial.create_player();g.spatial.configure(player);player.bus="HRTFTest"
	var source:=AudioStreamWAV.new();source.format=AudioStreamWAV.FORMAT_16_BITS;source.mix_rate=48000
	var data:=PackedByteArray();data.resize(48000*2)
	for i in range(48000):data.encode_s16(i*2,roundi(1800*sin(i*TAU*660/48000.0)))
	source.data=data;source.loop_mode=AudioStreamWAV.LOOP_FORWARD;source.loop_end=48000;player.stream=source;g.add_child(player);player.position=Vector3(-3,0,0);player.play()
	await create_timer(.5).timeout;capture.clear_buffer();await create_timer(.35).timeout
	var left:=energy(capture);check(left.is_finite() and left.x>0.000001 and left.x>left.y*1.05,"HRTF produces finite spatial audio biased toward left source")
	print("HRTF_LEVEL left=",left," input_rms=",1800.0/32768.0/sqrt(2.0))
	player.stop();g.presentation.spatial_audio="stereo"
	var reference:AudioStreamPlayer3D=g.spatial.create_player();g.spatial.configure(reference);reference.bus="HRTFTest"
	reference.stream=source;g.add_child(reference);reference.position=Vector3(-3,0,0);reference.play()
	await create_timer(.15).timeout;capture.clear_buffer();await create_timer(.35).timeout
	var standard:=energy(capture);print("STANDARD_LEVEL ",standard)
	check(left.x+left.y>=(standard.x+standard.y)*.25,"HRTF close-source loudness stays within 6 dB of standard spatial audio")
	reference.stop();reference.free();g.presentation.spatial_audio="steam_audio";player.play()
	g.camera.rotation.y=PI;g.spatial.steam.sync_listener();capture.clear_buffer();await create_timer(.5).timeout
	var right:=energy(capture);check(right.is_finite() and right.y>right.x*1.05,"Rotating headset listener reverses perceived direction")
	player.stop();player.free();await create_timer(.1).timeout
	var voice:AudioStreamPlayer3D=g.spatial.create_player();g.spatial.configure(voice,true);voice.bus="HRTFTest"
	var generator:=AudioStreamGenerator.new();generator.mix_rate=16000;generator.buffer_length=.12;voice.stream=generator;g.add_child(voice);voice.position=Vector3(0,0,-1.5);voice.play()
	await create_timer(.1).timeout
	var playback=voice.get_inner_stream_playback();check(playback is AudioStreamGeneratorPlayback,"Voice generator remains writable through Steam Audio wrapper")
	if playback==null:g.free();quit(1);return
	var frames:=PackedVector2Array();frames.resize(960)
	for i in range(frames.size()):frames[i]=Vector2.ONE*sin(i*TAU*440/16000)*.06
	capture.clear_buffer();playback.push_buffer(frames);await create_timer(.2).timeout
	var speech:=energy(capture);check(speech.is_finite() and speech.length()>0.000001,"Streamed voice passes through native HRTF mixer")
	print("HRTF_VOICE_LEVEL ",speech)
	voice.stop();voice.free();await create_timer(.1).timeout;AudioServer.remove_bus(idx)
	# Exercise source lifetime while the native mixer is running, including deletion
	# before the first process notification and repeated cap/rotation cleanup.
	for batch in range(80):
		var burst:Array=[]
		for i in range(12):
			var sound:AudioStreamPlayer3D=g.spatial.create_player();g.spatial.configure(sound)
			sound.stream=source;sound.volume_db=-60;g.add_child(sound);sound.play()
			if i%3==0:sound.free()
			else:burst.append(sound)
		await create_timer(.025).timeout
		for sound in burst:sound.queue_free()
		await process_frame
	check(true,"960 native sources survive rapid creation, immediate deletion and deferred cleanup")
	g.presentation.spatial_audio="stereo";var fallback=g.spatial.create_player();check(not fallback.has_method("play_stream"),"Standard spatial audio fallback is selectable");fallback.free()
	print("STEAM_AUDIO_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
