extends Node
## A narrow, gently saturated receive channel; generated clicks need no external assets.
var bus: StringName
var cue_player: AudioStreamPlayer
var clicks: Array[AudioStreamWAV]=[]
func setup() -> void:
	bus=StringName("TeamRadio_"+str(get_instance_id()))
	AudioServer.add_bus();var index:=AudioServer.bus_count-1;AudioServer.set_bus_name(index,bus)
	var high:=AudioEffectHighPassFilter.new();high.cutoff_hz=320;AudioServer.add_bus_effect(index,high)
	var distortion:=AudioEffectDistortion.new();distortion.mode=AudioEffectDistortion.MODE_WAVESHAPE;distortion.drive=.12;distortion.post_gain=4;AudioServer.add_bus_effect(index,distortion)
	var low:=AudioEffectLowPassFilter.new();low.cutoff_hz=3500;AudioServer.add_bus_effect(index,low)
	cue_player=AudioStreamPlayer.new();add_child(cue_player)
	for ending in [false,true]:
		var stream:=AudioStreamWAV.new();stream.mix_rate=24000;stream.format=AudioStreamWAV.FORMAT_16_BITS
		var data:=PackedByteArray();data.resize(2880*2);var noise:=RandomNumberGenerator.new();noise.seed=4242
		for i in 2880:
			var t:=float(i)/24000;var envelope:=minf(t/.005,1)*maxf(0,1-t/.12)
			var value: float=(sin(t*TAU*(740 if ending else 1120))*.16+noise.randf_range(-.08,.08))*envelope
			data.encode_s16(i*2,roundi(value*32767))
		stream.data=data;clicks.append(stream)
func cue(active: bool,volume: float) -> void:
	if not is_instance_valid(cue_player) or volume<=0:return
	cue_player.stream=clicks[0 if active else 1];cue_player.volume_db=linear_to_db(volume);cue_player.play()
func _exit_tree() -> void:
	var index:=AudioServer.get_bus_index(bus)
	if index>=0 and not bus.is_empty():AudioServer.remove_bus(index)
