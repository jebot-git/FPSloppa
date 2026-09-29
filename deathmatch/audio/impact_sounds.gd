extends RefCounted
## Short original synthesized contact cues; mono PCM, cached by the spatial mixer.
static func make(kind: String) -> AudioStreamWAV:
	var rate:=22050
	var duration:=.045 if kind=="hit_confirm" else .14 if kind=="impact_energy" else .11
	var count:=int(rate*duration);var data:=PackedByteArray();data.resize(count*2)
	var rng:=RandomNumberGenerator.new();rng.seed=93471
	var low:=0.0
	for i in count:
		var t:=float(i)/rate;var fade:=pow(1.0-float(i)/count,2.5);var noise:=rng.randf_range(-1,1)
		low=lerpf(low,noise,.24)
		var sample: float
		match kind:
			"hit_confirm":sample=(noise-low)*.48+sin(TAU*1350*t)*.15
			"impact_energy":sample=sin(TAU*(2200*t-4800*t*t))*.38+noise*.22
			"impact_heavy":sample=low*.85+sin(TAU*110*t)*.35
			_:sample=low*.75+noise*.25+sin(TAU*240*t)*.16
		data.encode_s16(i*2,int(clampf(sample*fade*minf(1,t*2000),-1,1)*26000))
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=data
	return stream
