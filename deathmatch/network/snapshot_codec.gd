extends RefCounted
## Authority-only state uses Godot's native scalar serializer. Tracker transforms
## retain compact quaternion storage; client input uses the stricter bounded codec.
const LIMIT = 262144
static func pack(value: Array) -> PackedByteArray:
	var raw := var_to_bytes(value)
	if raw.size()>LIMIT: return PackedByteArray()
	var result := PackedByteArray(); result.resize(5); result[0]=2; result.encode_u32(1,raw.size())
	result.append_array(raw.compress(FileAccess.COMPRESSION_FASTLZ)); return result
static func unpack(packet: PackedByteArray) -> Variant:
	if packet.size()<6 or packet.size()>LIMIT or packet[0]!=2: return null
	var size:=packet.decode_u32(1)
	if size<1 or size>LIMIT:return null
	var raw:=packet.slice(5).decompress(size,FileAccess.COMPRESSION_FASTLZ)
	return bytes_to_var(raw) if raw.size()==size else null
static func encode(value: Array) -> PackedByteArray:
	# Player records are dense and latency-sensitive; compact their entire row.
	# Godot handles sparse world/objective records directly in native code.
	var player:bool=value.size()==5 and value[0]==2
	var result:=PackedByteArray([1 if player else 0])
	result.append_array(preload("res://deathmatch/network/codec.gd").encode(value) if player else var_to_bytes(value))
	return result
static func decode(bytes: PackedByteArray) -> Variant:
	if bytes.size()<2 or bytes.size()>LIMIT:return null
	if bytes[0]==1:return preload("res://deathmatch/network/codec.gd").decode(bytes.slice(1))
	return bytes_to_var(bytes.slice(1)) if bytes[0]==0 else null
