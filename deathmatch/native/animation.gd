extends RefCounted
const Runtime=preload("res://deathmatch/native/runtime.gd")
static func create():
 if OS.get_cmdline_user_args().has("--gdscript-animation") or not Runtime.available("FPSAvatar"):return null
 return ClassDB.instantiate("FPSAvatar")
