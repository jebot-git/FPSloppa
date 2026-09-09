extends RefCounted
# Independent 20 ms IMA ADPCM blocks: signed LE predictor, index, reserved,
# then 319 low-nibble-first deltas. No state carries across network packets.
const RATE=16000
const FRAMES=320
const BYTES=164
const INDEX=[-1,-1,-1,-1,2,4,6,8]
const STEPS=[7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767]

static func valid(data: PackedByteArray) -> bool:
	return data.size()==BYTES and data[2]<=88 and data[3]==0

static func encode(samples: PackedFloat32Array) -> PackedByteArray:
	if samples.size()!=FRAMES: return PackedByteArray()
	var data:=PackedByteArray()
	data.resize(BYTES)
	var predictor:=clampi(roundi(samples[0]*32767),-32768,32767)
	var index:=48
	data.encode_s16(0,predictor); data[2]=index
	for i in range(1,FRAMES):
		var step: int=STEPS[index]
		var difference:=clampi(roundi(samples[i]*32767),-32768,32767)-predictor
		var code:=8 if difference<0 else 0
		difference=absi(difference)
		var delta:=step>>3
		if difference>=step: code|=4; difference-=step; delta+=step
		if difference>=(step>>1): code|=2; difference-=step>>1; delta+=step>>1
		if difference>=(step>>2): code|=1; delta+=step>>2
		predictor=clampi(predictor+(-delta if code&8 else delta),-32768,32767)
		index=clampi(index+INDEX[code&7],0,88)
		data[4+((i-1)>>1)]|=code<<(((i-1)&1)*4)
	return data

static func decode(data: PackedByteArray) -> PackedVector2Array:
	if not valid(data): return PackedVector2Array()
	var samples:=PackedVector2Array()
	samples.resize(FRAMES)
	var predictor:=data.decode_s16(0)
	var index: int=data[2]
	samples[0]=Vector2.ONE*(predictor/32768.0)
	for i in range(1,FRAMES):
		var code: int=(data[4+((i-1)>>1)]>>(((i-1)&1)*4))&15
		var step: int=STEPS[index]
		var delta: int=(step>>3)+(step if code&4 else 0)+(step>>1 if code&2 else 0)+(step>>2 if code&1 else 0)
		predictor=clampi(predictor+(-delta if code&8 else delta),-32768,32767)
		index=clampi(index+INDEX[code&7],0,88)
		samples[i]=Vector2.ONE*(predictor/32768.0)
	return samples
