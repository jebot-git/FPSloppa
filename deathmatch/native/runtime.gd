extends RefCounted
## Optional acceleration. Command-line switches retain the reference implementations.
static var attempted:=false
static var bodies: Array=[]
static func available(type: StringName) -> bool:
	if not attempted:
		attempted=true
		var path:="res://addons/fps_native/fps_native.gdextension"
		if FileAccess.file_exists(path) and not ClassDB.class_exists("FPSProjectiles"):
			GDExtensionManager.load_extension(path)
	return ClassDB.class_exists(type)
static func pose():
	if OS.get_cmdline_user_args().has("--gdscript-poses") or not available("FPSPose"):return null
	return ClassDB.instantiate("FPSPose")
static func projectiles():
	if OS.get_cmdline_user_args().has("--gdscript-projectiles") or not available("FPSProjectiles"):return null
	if bodies.is_empty():
		for height in range(65,166):bodies.append(preload("res://deathmatch/avatars/hit_body.gd").parts(height*.01))
	var result=ClassDB.instantiate("FPSProjectiles");result.configure_bodies(bodies);return result

static func codec():
	if OS.get_cmdline_user_args().has("--gdscript-codec") or not available("FPSCodec"):return null
	return ClassDB.instantiate("FPSCodec")

static func bots():
	if OS.get_cmdline_user_args().has("--gdscript-bots") or not available("FPSBots"):return null
	return ClassDB.instantiate("FPSBots")
