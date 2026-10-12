extends SceneTree
const Codec=preload("res://deathmatch/network/codec.gd")
const Runtime=preload("res://deathmatch/native/runtime.gd")
var checks:=0
var failures: Array=[]
var rng:=RandomNumberGenerator.new()
var native
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<20:failures.append(label);push_error(label)
func vector() -> Vector3:return Vector3(rng.randf_range(-100,100),rng.randf_range(-100,100),rng.randf_range(-100,100))
func value(depth: int=0) -> Variant:
	match rng.randi_range(0,9 if depth<4 else 7):
		0:return rng.randi_range(-2147483648,2147483647)
		1:return rng.randf_range(-1e5,1e5)
		2:return "český 玩家 😀 "+str(rng.randi())
		3:return vector()
		4:return Transform3D(Basis.from_euler(vector()),vector())
		5:return PackedFloat32Array([rng.randf(),rng.randf(),rng.randf()])
		6:return null
		7:return Color(rng.randf(),rng.randf(),rng.randf(),rng.randf())
		8:
			var result: Array=[]
			for i in rng.randi_range(0,8):result.append(value(depth+1))
			return result
		_:
			var result: Dictionary={}
			for i in rng.randi_range(0,8):result[i if i%2 else str(i)]=value(depth+1)
			return result
func decoded(raw: PackedByteArray,label: String) -> void:
	var a=Codec.decode_reference(raw);var b=native.decode(raw)
	# Re-encoding also handles NaNs and recursive values without approximate ==.
	check(Codec.encode_reference(a)==Codec.encode_reference(b),"Decode parity "+label)
func compare(v: Variant,label: String) -> void:
	var a:=Codec.encode_reference(v);var b: PackedByteArray=native.encode(v)
	check(a==b,"Exact wire bytes "+label)
	decoded(a,label)
func _initialize() -> void:
	native=Runtime.codec();check(native!=null,"Native codec loaded")
	if native==null:quit(1);return
	rng.seed=20260929
	var cases: Array=[null,false,true,0,-1,127,128,-128,-129,2147483647,-2147483648,2147483648,-2147483649,9223372036854775807,-9223372036854775807-1,.0,-.0,INF,-INF,NAN,"",&"StringName",Vector2(1,-2),Vector3(INF,NAN,-0.0),Transform3D.IDENTITY,[],{},PackedByteArray(),PackedByteArray([0,128,255]),PackedFloat32Array([INF,-INF,NAN,-.0]),Color(.1,.2,.3,.4),NodePath("unsupported"),Vector4.ONE]
	for i in cases.size():compare(cases[i],"edge "+str(i))
	for bits in [0x7f800001,0x7fc00001,0xff800001,0x80000001,0x007fffff]:
		var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,bits)
		compare(bytes.to_float32_array(),"Float32 bit pattern "+str(bits))
		decoded(PackedByteArray([12,1])+bytes,"Raw float32 bit pattern")
	for i in 3000:compare(value(),"random "+str(i))
	var nested: Array=[]
	for depth in 24:nested=[nested];compare(nested,"depth "+str(depth))
	for length in [0,1,4096,4097,32768,32769,262130,262144,262145]:
		var bytes:=PackedByteArray();bytes.resize(length);compare(bytes,"bytes "+str(length))
		if length<=32769:
			var array: Array=[];array.resize(length);compare(array,"array "+str(length))
	var corpus: Array[PackedByteArray]=[]
	for v in cases.slice(0,30):corpus.append(Codec.encode_reference(v))
	for i in 100:corpus.append(Codec.encode_reference(value()))
	for bytes in corpus:
		for end in mini(bytes.size(),256):decoded(bytes.slice(0,end),"truncation")
		decoded(bytes+PackedByteArray([0]),"trailing data")
	for i in 5000:
		# Arbitrary bounded packet bytes exercise tags, lengths and invalid quaternions.
		var bytes:=PackedByteArray();bytes.resize(rng.randi_range(0,100))
		for j in bytes.size():bytes[j]=rng.randi()%256
		decoded(bytes,"malformed "+str(i))
	# Overlong varints, dictionary key types, excessive counts and recursion.
	for bytes in [PackedByteArray([3,128,128,128,128,128,0]),PackedByteArray([10,1,2,0]),PackedByteArray([9,255,255,127]),PackedByteArray([3,255,255,255,255,127])]:decoded(bytes,"limits")
	print("NATIVE_CODEC_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
