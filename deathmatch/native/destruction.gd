extends RefCounted
const Runtime=preload("res://deathmatch/native/runtime.gd")
static func create():
 if OS.get_cmdline_user_args().has("--gdscript-destruction") or not Runtime.available("FPSDestruction"):return null
 return ClassDB.instantiate("FPSDestruction")
