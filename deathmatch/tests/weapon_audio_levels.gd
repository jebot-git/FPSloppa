extends SceneTree
const Levels=preload("res://deathmatch/audio/weapon_levels.gd")
const Bank=preload("res://deathmatch/audio/modes/catalog.gd")
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	game.headless=false;game.presentation.spatial_audio="stereo";game.spatial.setup(game)
	game.camera=game.get_node("Overview");game.camera.position=Vector3(10000,10000,10000)
	var mixer=game.spatial;mixer.set_physics_process(false)
	var kinds: Array=Bank.SOUNDS.keys()
	for slot in 10:kinds.append("weapon_%d"%slot)
	kinds.append_array(["flamethrower","explosion","cs_reload_mag_in","cs_reload_mag_out","cs_reload_rack_back","cs_reload_rack_close","cs_reload_empty_lock","de_snip"])
	for kind in kinds:
		for i in maxi(1,Bank.SOUNDS.get(kind,[]).size()):
			mixer.play(kind,game.camera.global_position,-4)
			var player: AudioStreamPlayer3D=mixer.active.back();var path:=player.stream.resource_path
			check(Levels.TRIM_DB.has(path),"Every live stream is calibrated: "+path)
			var expected: float=-4+Levels.TRIM_DB.get(path,0)
			check(is_equal_approx(player.volume_db,expected) and is_equal_approx(player.get_meta("dry_db"),expected),"Playback applies one normalization gain: "+kind)
			mixer.update_source(player,expected)
			check(is_equal_approx(player.volume_db,expected) and player.max_db>=expected,"Spatial refresh preserves quiet-source boost: "+kind)
			mixer.clear()
	check(Levels.gain_db("flesh","res://deathmatch/audio/recorded/impactPunch_heavy_000.ogg")==0,"Fist normalization does not alter shared body-impact audio")
	check(Levels.gain_db("pickup","res://deathmatch/audio/pickup.wav")==0,"Pickup audio is unchanged")
	check(mixer.effects_limiter!=null and mixer.effects_limiter.ceiling_db==-3,"Effects sum has headroom limiter")
	var bus:=AudioServer.get_bus_index("ArenaEffects")
	var capture:=AudioEffectCapture.new();capture.buffer_length=1;AudioServer.add_bus_effect(bus,capture)
	AudioServer.set_bus_volume_db(bus,0);AudioServer.set_bus_mute(bus,false)
	var wave:=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS;wave.mix_rate=48000
	var pcm:=PackedByteArray();pcm.resize(48000*2)
	for i in 48000:pcm.encode_s16(i*2,roundi(28000*sin(TAU*220*i/48000)))
	wave.data=pcm;wave.loop_mode=AudioStreamWAV.LOOP_FORWARD;wave.loop_end=48000
	var loud: Array=[]
	for i in 8:
		var player:=AudioStreamPlayer.new();player.stream=wave;player.bus="ArenaEffects";game.add_child(player);player.play();loud.append(player)
	await create_timer(.15).timeout;capture.clear_buffer();await create_timer(.15).timeout
	var frames:=capture.get_buffer(capture.get_frames_available());var peak:=0.0
	for frame in frames:peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	check(frames.size()>1000 and peak>.4 and peak<=db_to_linear(-2.9),"Eight overlapping loud voices remain audible without clipping")
	for player in loud:player.stop();player.queue_free()
	await create_timer(.15).timeout
	var report:={"checks":checks,"failures":failures,"overlap_peak_dbfs":linear_to_db(peak),"captured_frames":frames.size()}
	FileAccess.open("res://test-results/weapon-levels-20260930/playback.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WEAPON_AUDIO_LEVELS ",JSON.stringify(report));game.queue_free();await process_frame;quit.call_deferred(0 if failures.is_empty() else 1)
