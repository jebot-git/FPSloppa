extends RefCounted
## All user and downloaded maps/models live outside the PCK/APK.
static func root() -> String:
	var args:=OS.get_cmdline_user_args()
	var index:=args.find("--asset-root")
	if index>=0 and index+1<args.size():return ProjectSettings.globalize_path(args[index+1]).simplify_path()
	if OS.has_feature("android"):
		var package:="org.entryway.arena.pico" if OS.has_feature("pico_xr") else "org.entryway.arena.quest"
		return "/sdcard/Android/data/"+package+"/files"
	if OS.has_feature("editor"):return ProjectSettings.globalize_path("res://").trim_suffix("/")
	return OS.get_executable_path().get_base_dir()
static func folder(kind: String) -> String:
	var path:=root().path_join(kind)
	DirAccess.make_dir_recursive_absolute(path)
	return path+"/"
static func resolve(path: String) -> String:
	for kind in ["maps","vrm"]:
		if path.begins_with("res://"+kind+"/"):return folder(kind)+path.trim_prefix("res://"+kind+"/")
	return path

static func migrate_preferences() -> void:
	# Desktop project rename: keep existing settings without replacing new choices.
	if OS.has_feature("android"):return
	var legacy:=OS.get_user_data_dir().get_base_dir().path_join("Entryway Deathmatch")
	for filename in ["deathmatch.cfg","tracking.cfg","avatars.cfg"]:
		var destination: String="user://"+filename
		var source:=legacy.path_join(filename)
		if not FileAccess.file_exists(destination) and FileAccess.file_exists(source):
			DirAccess.copy_absolute(source,ProjectSettings.globalize_path(destination))
