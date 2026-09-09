extends RefCounted
## Lightweight acoustic vowel estimate, not speech recognition. 16 kHz mono blocks.
static func energy(samples: PackedVector2Array,frequency: float) -> float:
	var coeff:=2*cos(TAU*frequency/16000)
	var a:=0.0; var b:=0.0
	for frame in samples:
		var next: float=frame.x+coeff*a-b
		b=a; a=next
	return maxf(0,a*a+b*b-coeff*a*b)/maxi(1,samples.size()*samples.size())
static func analyze(samples: PackedVector2Array) -> PackedFloat32Array:
	var weights:=PackedFloat32Array([0,0,0,0,0]) # aa ih ou ee oh
	if samples.is_empty(): return weights
	var rms:=0.0
	for sample in samples: rms+=sample.x*sample.x
	rms=sqrt(rms/samples.size())
	if rms<.008: return weights
	var low:=energy(samples,400)+energy(samples,650)
	var mid:=energy(samples,1000)+energy(samples,1400)
	var high:=energy(samples,2200)+energy(samples,2800)
	var total:=low+mid+high+.000001
	var openness:=clampf((rms-.008)*10,0,.9)
	weights[0]=openness*(.25+.6*mid/total)
	weights[1]=openness*.55*high/total
	weights[2]=openness*.5*low/total
	weights[3]=openness*.3*(mid+high)/total
	weights[4]=openness*.35*low/total
	return weights
