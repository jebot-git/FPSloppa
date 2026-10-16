extends RefCounted
const Runtime=preload("res://deathmatch/native/runtime.gd")
static func create():
 if OS.get_cmdline_user_args().has("--gdscript-world") or not Runtime.available("FPSWorld"):return null
 return ClassDB.instantiate("FPSWorld")
