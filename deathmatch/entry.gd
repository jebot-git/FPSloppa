extends Node
## Runtime templates deliberately disable command-line scene path overrides.
## Keep one packaged entry point for the game and optional desktop frontend.
func _ready() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.has("--launcher-install"):
		get_tree().change_scene_to_file.call_deferred("res://deathmatch/launcher/installer.tscn");return
	if not OS.has_feature("editor") and not OS.has_feature("dedicated_server") and OS.get_name() in ["Linux","Windows"]:
		var root:=OS.get_executable_path().get_base_dir()
		if FileAccess.file_exists(root.path_join("INSTALL-MANIFEST.json")):
			var lease:=preload("res://deathmatch/launcher/update_lease.gd").new()
			get_tree().root.add_child.call_deferred(lease)
			if not lease.register(root) or FileAccess.file_exists(root.path_join(".launcher-update/pending.json")):
				push_error("An update is pending or the installation is not writable. Start Launch-FPSloppa.");get_tree().quit(1);return
	var scene:="res://deathmatch/arena.tscn"
	if not OS.has_feature("dedicated_server") and not OS.has_feature("android"):
		if args.has("--launcher-worker"):scene="res://deathmatch/launcher/worker.tscn"
		elif args.has("--launcher"):scene="res://deathmatch/launcher/launcher.tscn"
	get_tree().change_scene_to_file.call_deferred(scene)
