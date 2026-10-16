extends RefCounted
const Runtime=preload("res://deathmatch/native/runtime.gd")
static func create():
 if OS.get_cmdline_user_args().has("--gdscript-motion") or not Runtime.available("FPSMovement"):return null
 return ClassDB.instantiate("FPSMovement")
