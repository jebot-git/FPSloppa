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

static var backend_instance
static var backend_attempted:=false
static func backend():
	if backend_attempted:return backend_instance
	backend_attempted=true
	if OS.get_cmdline_user_args().has("--gdscript-backend") or not available("FPSBackend"):return null
	if not backend_instance:
		backend_instance=ClassDB.instantiate("FPSBackend")
		var rows:Array=[]
		for height in range(65,166):rows.append(preload("res://deathmatch/avatars/hit_body.gd").parts(height*.01))
		backend_instance.configure_hitboxes(rows)
		var args:=OS.get_cmdline_user_args();var index:=args.find("--native-workers")
		backend_instance.set_workers(clampi(int(args[index+1]),1,10) if index>=0 and index+1<args.size() else 4)
	return backend_instance

# Exported CQ clients must not silently run a partial scripted fallback. Reference
# selectors remain available in editor binaries for differential fixtures.
static func cq_release_error()->String:
	if OS.has_feature("editor"):return ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gdscript-"):return "Script reference paths require an editor build."
	for type in ["FPSNativeClient","FPSClientSession","FPSClientServices","FPSRemoteInterpolation","FPSCodec","FPSMovement","FPSWorld","FPSDestruction","FPSAvatar","FPSAudio","FPSPose","FPSVRInteraction"]:
		if not available(type):return "Missing native CQ capability: "+type
	if not ClassDB.class_has_method("FPSWorld","weather_sample"):return "Rebuild the native weather runtime."
	return ""
