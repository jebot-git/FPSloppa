extends RefCounted
## Curated objectives are bound to compiled BSP hashes, including renamed copies.
const DEFAULT="de_dust2_rebuilt"
const IDS=[DEFAULT,"de_nuke_rebuilt","de_inferno_rebuilt","de_aztec_rebuilt","de_train_rebuilt"]
static var bank: Dictionary={}
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
	return {}
static func supported(id: String,hash: String="") -> bool:return not resolve(id,hash).is_empty()
static func vector(row: Array) -> Vector3:return Vector3(row[0],row[1],row[2])
