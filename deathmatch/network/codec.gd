extends RefCounted
## Versioned, bounded value codec. No object/resource deserialization.
const LIMIT = 262144
const FIXED = {4:8, 6:8, 7:12, 8:20, 13:16, 14:8}
var stream := StreamPeerBuffer.new()
var valid := true
var nodes := 0

static func pack(value: Variant) -> PackedByteArray:
	var raw := encode(value)
	if raw.is_empty(): return raw
	var result := PackedByteArray(); result.resize(5)
	result[0] = 1; result.encode_u32(1, raw.size())
	result.append_array(raw.compress(FileAccess.COMPRESSION_FASTLZ))
	return result

static func encode(value: Variant) -> PackedByteArray:
	var codec = load("res://deathmatch/network/codec.gd").new()
	codec.write(value)
	if not codec.valid or codec.stream.data_array.size() > LIMIT: return PackedByteArray()
	return codec.stream.data_array

static func unpack(packet: PackedByteArray, maximum: int = LIMIT) -> Variant:
	if packet.size() < 6 or packet.size() > LIMIT or packet[0] != 1: return null
	var size := packet.decode_u32(1)
	if size < 1 or size > mini(maximum,LIMIT): return null
	var raw := packet.slice(5).decompress(size, FileAccess.COMPRESSION_FASTLZ)
	if raw.size() != size: return null
	return decode(raw)

static func decode(raw: PackedByteArray) -> Variant:
	if raw.size() > LIMIT: return null
	var codec = load("res://deathmatch/network/codec.gd").new()
	codec.stream.data_array = raw
	var result = codec.read()
	return result if codec.valid and codec.stream.get_available_bytes() == 0 else null

func uint(value: int) -> void:
	while value >= 128:
		stream.put_u8((value & 127) | 128); value >>= 7
	stream.put_u8(value)

func take(size: int) -> bool:
	if not valid or stream.get_available_bytes() < size: valid = false
	return valid

func read_uint() -> int:
	var result := 0
	for shift in range(0, 35, 7):
		if not take(1): return 0
		var byte := stream.get_u8(); result |= (byte & 127) << shift
		if byte < 128: return result
	valid = false; return 0

func write(value: Variant, depth: int = 0) -> void:
	nodes += 1
	if depth > 20 or nodes > 32768: valid = false; return
	match typeof(value):
		TYPE_NIL: stream.put_u8(0)
		TYPE_BOOL: stream.put_u8(2 if value else 1)
		TYPE_INT:
			if value < -2147483648 or value > 2147483647:
				stream.put_u8(14); stream.put_64(value)
			else: stream.put_u8(3); uint((value << 1) ^ (value >> 31))
		TYPE_FLOAT: stream.put_u8(4); stream.put_double(value)
		TYPE_STRING, TYPE_STRING_NAME:
			stream.put_u8(5); var bytes: PackedByteArray = str(value).to_utf8_buffer(); uint(bytes.size()); stream.put_data(bytes)
		TYPE_VECTOR2:
			stream.put_u8(6); stream.put_float(value.x); stream.put_float(value.y)
		TYPE_VECTOR3:
			stream.put_u8(7); stream.put_float(value.x); stream.put_float(value.y); stream.put_float(value.z)
		TYPE_TRANSFORM3D:
			stream.put_u8(8)
			for component in [value.origin.x, value.origin.y, value.origin.z]: stream.put_float(component)
			var q: Quaternion = value.basis.orthonormalized().get_rotation_quaternion()
			for component in [q.x, q.y, q.z, q.w]: stream.put_16(roundi(clampf(component, -1, 1) * 32767))
		TYPE_ARRAY:
			stream.put_u8(9); uint(value.size())
			for item in value: write(item, depth + 1)
		TYPE_DICTIONARY:
			stream.put_u8(10); uint(value.size())
			for key in value: write(key, depth + 1); write(value[key], depth + 1)
		TYPE_PACKED_BYTE_ARRAY:
			stream.put_u8(11); uint(value.size()); stream.put_data(value)
		TYPE_PACKED_FLOAT32_ARRAY:
			stream.put_u8(12); uint(value.size())
			for component in value: stream.put_float(component)
		TYPE_COLOR:
			stream.put_u8(13)
			for component in [value.r, value.g, value.b, value.a]: stream.put_float(component)
		_: valid = false

func read(depth: int = 0) -> Variant:
	nodes += 1
	if depth > 20 or nodes > 32768 or not take(1): valid = false; return null
	var tag := stream.get_u8()
	if FIXED.has(tag) and not take(FIXED[tag]): return null
	match tag:
		0: return null
		1: return false
		2: return true
		3:
			var value := read_uint()
			return (value >> 1) ^ -(value & 1)
		4: return stream.get_double()
		5, 11:
			var size := read_uint()
			if size > LIMIT or not take(size): valid = false; return null
			var bytes: PackedByteArray = stream.get_data(size)[1] if size > 0 else PackedByteArray()
			return bytes.get_string_from_utf8() if tag == 5 else bytes
		6: return Vector2(stream.get_float(), stream.get_float())
		7: return Vector3(stream.get_float(), stream.get_float(), stream.get_float())
		8:
			var origin := Vector3(stream.get_float(), stream.get_float(), stream.get_float())
			var q := Quaternion(stream.get_16()/32767.0, stream.get_16()/32767.0, stream.get_16()/32767.0, stream.get_16()/32767.0)
			if not origin.is_finite() or not q.is_finite() or q.length_squared() < .9: valid = false; return null
			return Transform3D(Basis(q.normalized()), origin)
		9, 10, 12:
			var count := read_uint()
			if count > 4096: valid = false; return null
			if tag == 12:
				if not take(count * 4): return null
				var floats := PackedFloat32Array()
				for i in count: floats.append(stream.get_float())
				return floats
			var array: Array = []; var dictionary: Dictionary = {}
			for i in count:
				var key = read(depth + 1)
				if not valid: return null
				if tag == 9: array.append(key)
				else:
					if not (key is String or key is int): valid = false; return null
					dictionary[key] = read(depth + 1)
			return array if tag == 9 else dictionary
		13: return Color(stream.get_float(), stream.get_float(), stream.get_float(), stream.get_float())
		14: return stream.get_64()
	valid = false; return null
