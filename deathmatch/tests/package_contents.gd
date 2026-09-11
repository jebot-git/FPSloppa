extends SceneTree
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty() or not ProjectSettings.load_resource_pack(args[0]):print("PACKAGE_AUDIT_FAILED mount");quit(1);return
	var failures: Array=[];var stack: Array=["res://"];var count:=0
	while not stack.is_empty():
		var folder: String=stack.pop_back()
		for file in DirAccess.get_files_at(folder):
			count+=1;var path:=folder.path_join(file)
			if folder.begins_with("res://textures") or folder.begins_with("res://materials") or folder.contains("docs/audio") or folder.contains("deathmatch/audio/music/samples") or folder.contains("optional-arena-pack") or folder.contains("optional-ad-tools") or folder.contains("optional-threewave-tools") or folder.contains("optional-tf-tools"):failures.append(path)
			if file.get_extension().to_lower() in ["bsp","vrm","pak"] or path.contains("AD-NOTICES") or file.begins_with("ad_arena_"):failures.append(path)
		for child in DirAccess.get_directories_at(folder):stack.append(folder.path_join(child))
	for cue in ["start","team_deathmatch","capture_the_flag","last_man_standing","round_winner","game_over"]:
		if FileAccess.file_exists("res://deathmatch/audio/announcer/"+cue+".ogg") or FileAccess.file_exists("res://deathmatch/audio/announcer/"+cue+".ogg.remap"):failures.append("Retired announcer: "+cue)
	for required in ["res://deathmatch/modes/assault.gd","res://deathmatch/modes/fortress_fx.gd","res://deathmatch/maps/train_motion.gd","res://deathmatch/vr/swim_strokes.gd","res://deathmatch/vr/t_pose.gd","res://deathmatch/chainsaw.gd","res://deathmatch/audio/announcer.gd","res://deathmatch/audio/announcer/LICENSE.txt","res://deathmatch/audio/announcer/SOURCES.md","res://deathmatch/network/disk_worker.gd","res://deathmatch/maps/contents.gd","res://deathmatch/maps/filtering.gd","res://deathmatch/movement/quake.gd","res://deathmatch/movement/LICENSE.txt","res://deathmatch/voice/microphone.gd","res://deathmatch/modes/lobby_mirror.gd","res://deathmatch/modes/lobby_wall.gd","res://deathmatch/ui/choice.gd","res://addons/twovoip/twovoip.gdextension","res://addons/twovoip/LICENSE.txt","res://deathmatch/network/loading.gd","res://deathmatch/network/loading_overlay.gd","res://deathmatch/projectile_targets.gd","res://deathmatch/lag_compensation.gd","res://deathmatch/maps/static_batch.gd","res://deathmatch/maps/librequake-props/flame.json","res://deathmatch/maps/librequake-props/LICENCE.txt","res://deathmatch/maps/librequake-props/CREDITS.txt","res://deathmatch/maps/librequake-props/SOURCES.json"]:
		if not FileAccess.file_exists(required) and not FileAccess.file_exists(required+".remap"):failures.append("Missing "+required)
	print("PACKAGE_AUDIT ",JSON.stringify({"pack":args[0],"files":count,"failures":failures}));quit(0 if failures.is_empty() else 1)
