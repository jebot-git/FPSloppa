extends SceneTree
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func capture(player: AudioStreamPlayer,effect: AudioEffectCapture) -> PackedVector2Array:
	effect.clear_buffer();player.play()
	var result:=PackedVector2Array();var until:=Time.get_ticks_msec()+roundi(player.stream.get_length()*1000)+200
	while Time.get_ticks_msec()<until:
		await process_frame
		result.append_array(effect.get_buffer(effect.get_frames_available()))
	return result
func rms(data: PackedVector2Array) -> float:
	var power:=0.0
	for frame in data:power+=frame.length_squared()*.5
	return sqrt(power/maxi(1,data.size()))
func run() -> void:
	var radio=preload("res://deathmatch/voice/radio_audio.gd").new();root.add_child(radio);radio.setup()
	var index:=AudioServer.get_bus_index(radio.bus)
	check(AudioServer.get_bus_effect_count(index)==3,"Radio installs filters and gentle distortion")
	var recorder:=AudioEffectCapture.new();recorder.buffer_length=.5;AudioServer.add_bus_effect(index,recorder)
	var player:=AudioStreamPlayer.new();root.add_child(player);player.bus=radio.bus
	player.stream=load("res://deathmatch/audio/announcer/objective_completed.ogg")
	for effect in 3:AudioServer.set_bus_effect_enabled(index,effect,false)
	var dry:=await capture(player,recorder)
	for effect in 3:AudioServer.set_bus_effect_enabled(index,effect,true)
	var filtered:=await capture(player,recorder)
	var ratio:=rms(filtered)/maxf(.0001,rms(dry))
	check(rms(dry)>.01 and ratio>.70 and ratio<1.5,"Radio speech stays audible without excessive gain")
	print("RADIO_LEVEL ",JSON.stringify({"dry_rms":rms(dry),"radio_rms":rms(filtered),"ratio":ratio}))
	var all:=dry;all.append_array(PackedVector2Array([Vector2.ZERO]));all.append_array(filtered)
	var bytes:=PackedByteArray();bytes.resize(all.size()*4)
	for i in all.size():
		bytes.encode_s16(i*4,roundi(clampf(all[i].x,-1,1)*32767));bytes.encode_s16(i*4+2,roundi(clampf(all[i].y,-1,1)*32767))
	var wav:=AudioStreamWAV.new();wav.stereo=true;wav.mix_rate=int(AudioServer.get_mix_rate());wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.data=bytes
	wav.save_to_wav("res://test-results/team-radio/dry-then-radio.wav")
	radio.clicks[0].save_to_wav("res://test-results/team-radio/radio-on.wav");radio.clicks[1].save_to_wav("res://test-results/team-radio/radio-off.wav")
	check(radio.clicks[0].data!=radio.clicks[1].data and radio.clicks[0].data.size()==5760,"Activation and release have distinct short click tones")
	var bus: StringName=radio.bus
	player.free();radio.free()
	check(AudioServer.get_bus_index(bus)<0,"Radio test audio bus removed")
	print("RADIO_AUDIO_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
