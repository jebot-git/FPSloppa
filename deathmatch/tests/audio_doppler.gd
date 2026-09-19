extends SceneTree
var failures: Array=[]
var game
class Motion extends Node:
	var source: Node3D
	var camera: Camera3D
	var source_velocity:=Vector3.ZERO
	var listener_velocity:=Vector3.ZERO
	func _process(delta: float) -> void:
		source.position+=source_velocity*delta;camera.position+=listener_velocity*delta
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func frequency(capture: AudioEffectCapture) -> float:
	var frames:=capture.get_buffer(capture.get_frames_available())
	var crossings:=0;var previous:=0.0
	for sample in frames:
		var value:=sample.x+sample.y
		if value>0 and previous<=0:crossings+=1
		previous=value
	return crossings*AudioServer.get_mix_rate()/maxi(1,frames.size())
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
	if game.headless:game.headless=false;game.spatial.setup(game)
	game.camera=game.get_node("Overview");game.camera.transform=Transform3D.IDENTITY;game.camera.make_current()
	var bus:=AudioServer.bus_count;AudioServer.add_bus();AudioServer.set_bus_name(bus,"DopplerTest")
	var capture:=AudioEffectCapture.new();capture.buffer_length=2;AudioServer.add_bus_effect(bus,capture)
	var tone:=AudioStreamWAV.new();tone.mix_rate=48000;tone.format=AudioStreamWAV.FORMAT_16_BITS
	var samples:=PackedByteArray();samples.resize(48000*2)
	for i in 48000:samples.encode_s16(i*2,roundi(3000*sin(i*TAU*660/48000)))
	tone.data=samples;tone.loop_mode=AudioStreamWAV.LOOP_FORWARD;tone.loop_end=48000
	for backend in ["steam_audio","stereo"]:
		game.presentation.spatial_audio=backend
		var player: AudioStreamPlayer3D=game.spatial.create_player();game.spatial.configure(player);player.bus="DopplerTest";player.max_distance=200;player.unit_size=100
		check(player.has_method("play_stream")== (backend=="steam_audio"),backend+": requested mixer backend is active")
		if player.has_method("play_stream"):player.set("min_attenuation_distance",100.0)
		player.stream=tone;game.add_child(player)
		var motion:=Motion.new();motion.source=player;motion.camera=game.camera;game.add_child(motion)
		var measured: Dictionary={}
		for phase in ["stationary","approach","recede","listener"]:
			motion.source_velocity=Vector3.ZERO;motion.listener_velocity=Vector3.ZERO
			player.stop();player.position=Vector3(0,0,-60);game.camera.position=Vector3.ZERO
			await create_timer(.2).timeout;player.play();await create_timer(.2).timeout
			if phase=="approach":motion.source_velocity=Vector3(0,0,60)
			if phase=="recede":motion.source_velocity=Vector3(0,0,-60)
			if phase=="listener":motion.listener_velocity=Vector3(0,0,-60)
			await create_timer(.2).timeout;capture.clear_buffer();await create_timer(.25).timeout
			measured[phase]=frequency(capture)
		print("DOPPLER_FREQUENCIES ",backend," ",JSON.stringify(measured))
		check(absf(measured.stationary-660)<15,backend+": stationary pitch is unchanged")
		check(measured.approach>measured.stationary*1.10,backend+": approaching source audibly shifts pitch upward")
		check(measured.recede<measured.stationary*.92 and measured.recede>0,backend+": receding source audibly shifts pitch downward")
		check(measured.listener>measured.stationary*1.10,backend+": actual camera/listener velocity affects pitch")
		motion.free();player.stop();player.free()
	await create_timer(.1).timeout;AudioServer.remove_bus(bus)
	print("AUDIO_DOPPLER_RESULT ",JSON.stringify(failures));game.free();quit(0 if failures.is_empty() else 1)
