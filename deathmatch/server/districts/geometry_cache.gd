extends RefCounted
## This cache is generated and embedded in the trusted server PCK, never uploaded.
const HASH="727ebb90f7c4239b1a3a3e6fde4bd713a971ba2b552444afe1a16888d7599ca3"
const PATH="res://deathmatch/server/districts/cache/vesper.scn"
static func scene(row: Dictionary) -> PackedScene:
	if row.get("sha256","")!=HASH or not FileAccess.file_exists(PATH):return null
	return load(PATH)
