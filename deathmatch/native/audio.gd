extends RefCounted
const Runtime=preload("res://deathmatch/native/runtime.gd")
static func create():
 if OS.get_cmdline_user_args().has("--gdscript-audio") or not Runtime.available("FPSAudio"):return null
 return ClassDB.instantiate("FPSAudio")
