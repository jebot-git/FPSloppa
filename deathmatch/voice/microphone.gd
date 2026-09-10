extends "res://addons/twovoip/voiphelper/two_voip_mic.gd"
## Game-controlled capture around TwoVoIP's resampler, denoiser and Opus encoder.
var voice
var pending:=PackedVector2Array()
func configure(owner_voice: Node) -> bool:
	voice=owner_voice
	if not set_opus_values(48000,20,1,24000,5,true,TwovoipOpusEncoder.DENOISER_RNNOISE,TwovoipOpusEncoder.AGC_DISABLED):return false
	set_process(true)
	return AudioServer.set_input_device_active(true)==OK
func _process(_delta: float) -> void:
	var allowed: bool=voice.can_transmit()
	var talking: bool=allowed and (voice.push_to_talk() if voice.mode==1 else voice.hangover>0)
	processtalkstreamends(talking)
	voice.transmitting=talking
	# Bound work after a stalled frame, retaining any unconsumed resampler input.
	for iteration in range(12):
		var required: int=opusencoder.get_required_input_chunk_size()
		if pending.size()<required:
			var frames:=AudioServer.get_input_frames(required-pending.size())
			if frames.is_empty():break
			pending.append_array(frames)
		if pending.size()<required:break
		var consumed: int=opusencoder.process_chunk(pending)
		if consumed<=0:pending.clear();break
		pending=pending.slice(consumed)
		voice.meter=opusencoder.get_rms()
		voice.hangover=.25 if voice.meter>voice.threshold and allowed else maxf(0,voice.hangover-.02)
		if currentlytalking:
			var mono: PackedFloat32Array=opusencoder.get_current_chunk_16khz(false)
			var mouth:=PackedVector2Array()
			for sample in mono:mouth.append(Vector2.ONE*sample)
			voice.animate_mouth(voice.multiplayer.get_unique_id(),mouth)
			processopuschunk()
func _exit_tree() -> void:
	AudioServer.set_input_device_active(false)
