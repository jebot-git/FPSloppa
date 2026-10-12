extends RefCounted
## Optional acceleration. Command-line switches retain the reference implementations.
static var attempted:=false
static func available(type: StringName) -> bool:
	if not attempted:
		attempted=true
		var path:="res://addons/fps_native/fps_native.gdextension"
		if FileAccess.file_exists(path) and not ClassDB.class_exists("FPSCodec"):
			GDExtensionManager.load_extension(path)
	return ClassDB.class_exists(type)
static func pose():
	if OS.get_cmdline_user_args().has("--gdscript-poses") or not available("FPSPose"):return null
	return ClassDB.instantiate("FPSPose")
static func codec():
	if OS.get_cmdline_user_args().has("--gdscript-codec") or not available("FPSCodec"):return null
	return ClassDB.instantiate("FPSCodec")
