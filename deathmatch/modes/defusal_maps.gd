extends RefCounted
## Curated objectives are bound to compiled BSP hashes, including renamed copies.
const DEFAULT="de_dust2_rebuilt"
const IDS=[DEFAULT,"de_nuke_rebuilt","de_inferno_rebuilt","de_aztec_rebuilt","de_train_rebuilt"]
static var bank: Dictionary={}
static var converted: Dictionary={}
static func entries() -> Dictionary:
	if bank.is_empty():
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/defusal.json"))
		if data is Dictionary:bank=data
	return bank
static func resolve(id: String,hash: String="") -> Dictionary:
	var rows:=entries()
	if hash.is_empty():return rows.get(id,{})
	for row in rows.values():
		if row.sha256==hash:return row
	return converted.get(hash,{})
static func supported(id: String,hash: String="") -> bool:return not resolve(id,hash).is_empty()
static func vector(row: Array) -> Vector3:return Vector3(row[0],row[1],row[2])

static func numeric(value) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and absf(float(value))<32768.0
static func point(value) -> bool:
	return value is Array and value.size()==3 and value.all(numeric)
static func valid_box(box) -> bool:
	if not box is Dictionary or not point(box.get("min")) or not point(box.get("max")):return false
	var size:=vector(box.max)-vector(box.min)
	return size.x>0 and size.y>0 and size.z>0 and size.length()<=4096
static func box_contains(box, p: Array) -> bool:
	return AABB(vector(box.min),vector(box.max)-vector(box.min)).grow(.1).has_point(vector(p))
static func valid_layout(data) -> bool:
	if not data is Dictionary or data.get("version")!=1:return false
	for key in ["sites","bounds","starts","yaw","start_yaws"]:
		if not data.get(key) is Array or data[key].size()!=2:return false
	if not data.sites.all(point) or not data.yaw.all(numeric):return false
	for i in 2:
		var box=data.bounds[i]
		if not valid_box(box) or not box_contains(box,data.sites[i]):return false
		if not data.starts[i] is Array or data.starts[i].is_empty() or data.starts[i].size()>64 or not data.starts[i].all(point):return false
		if not data.start_yaws[i] is Array or data.start_yaws[i].size()!=data.starts[i].size() or not data.start_yaws[i].all(numeric):return false
	if data.has("volumes"):
		if not data.volumes is Array or data.volumes.size()!=2:return false
		for i in 2:
			var boxes=data.volumes[i]
			if not boxes is Array or boxes.is_empty() or boxes.size()>64 or not boxes.all(valid_box):return false
			if not boxes.any(func(box):return box_contains(box,data.sites[i])):return false
			for box in boxes:
				if not box_contains(data.bounds[i],box.min) or not box_contains(data.bounds[i],box.max):return false
	return true
static func embedded(path: String) -> Dictionary:
	var bytes:=preload("res://deathmatch/maps/bsp_extensions.gd").read(path,"FSL_DE",65536)
	if bytes.is_empty():return {}
	var data=JSON.parse_string(bytes.get_string_from_utf8())
	return data if valid_layout(data) else {}
static func register_map(path: String,hash: String) -> Dictionary:
	if converted.has(hash):return converted[hash]
	var data:=embedded(path)
	if data.is_empty() or FileAccess.get_sha256(path)!=hash:return {}
	data.sha256=hash
	if converted.size()>=256:converted.clear()
	converted[hash]=data
	return data
static func installed(id: String) -> bool:
	if id in IDS:return true
	if id.is_empty() or id.length()>80 or not id.is_valid_filename() or id.contains(".."):return false
	var path:=preload("res://deathmatch/assets/paths.gd").folder("maps")+id+".bsp"
	return FileAccess.file_exists(path) and not register_map(path,FileAccess.get_sha256(path)).is_empty()
