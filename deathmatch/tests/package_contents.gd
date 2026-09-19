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
			if ".bsp" in file.to_lower() or file.get_extension().to_lower() in ["vrm","pak","log"] or path.contains("AD-NOTICES") or file.begins_with("ad_arena_"):failures.append(path)
		for child in DirAccess.get_directories_at(folder):stack.append(folder.path_join(child))
	if not FileAccess.file_exists("res://deathmatch/maps/texture_replacements/makkon-used.wad"):failures.append("Missing raw texture dictionary")
	var dictionary=load("res://deathmatch/maps/texture_replacements/dictionary.gd")
	var texture_manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/texture_replacements/manifest.json"))
	if FileAccess.get_sha256("res://deathmatch/maps/texture_replacements/makkon-used.wad")!=texture_manifest.makkon_pack_sha256:failures.append("Texture dictionary checksum")
	for key in texture_manifest.textures:
		if texture_manifest.textures[key].get("pack","")=="makkon-used.wad":
			var replacement: Dictionary=dictionary.resolve(key)
			if replacement.is_empty() or replacement.texture.get_width()!=int(texture_manifest.textures[key].width):failures.append("Cannot decode packaged Makkon texture")
			break
	for unwanted in ["export_presets.cfg","NETWORK_TESTING.md","LIVE_VR_TEST.md"]:
		if FileAccess.file_exists("res://"+unwanted):failures.append(unwanted)
	for cue in ["start","team_deathmatch","capture_the_flag","last_man_standing","round_winner","game_over"]:
		if FileAccess.file_exists("res://deathmatch/audio/announcer/"+cue+".ogg") or FileAccess.file_exists("res://deathmatch/audio/announcer/"+cue+".ogg.remap"):failures.append("Retired announcer: "+cue)
	for required in ["res://deathmatch/maps/triggers.gd","res://deathmatch/bot_ai/map_triggers.gd","res://deathmatch/maps/quake_light.gdshader","res://deathmatch/vr/body_basis.gd","res://deathmatch/vr/shoulder_radio.gd","res://deathmatch/network/fire_delivery.gd","res://deathmatch/vehicles/ba2/pilot_controls.gd","res://deathmatch/audio/flamethrower.res","res://deathmatch/modes/titanball.gd","res://deathmatch/vehicles/ba2/model.scn","res://deathmatch/experimental/combat.gd","res://deathmatch/maps/surface_assets.gd","res://deathmatch/maps/glow_masks.gd","res://deathmatch/movement/prediction.gd","res://deathmatch/vr/physical_crouch.gd","res://deathmatch/vr/weapon_clearance.gd","res://deathmatch/vr/face_expressions.gd","res://deathmatch/modes/vr_interactions.gd","res://deathmatch/ui/file_browser.gd","res://deathmatch/icon-final.png","res://deathmatch/audio/door_open.wav","res://deathmatch/audio/door_close.wav","res://deathmatch/audio/jump_pad.wav","res://deathmatch/modes/assault.gd","res://deathmatch/modes/fortress_fx.gd","res://deathmatch/maps/train_motion.gd","res://deathmatch/vr/swim_strokes.gd","res://deathmatch/vr/t_pose.gd","res://deathmatch/chainsaw.gd","res://deathmatch/audio/announcer.gd","res://deathmatch/audio/announcer/LICENSE.txt","res://deathmatch/audio/announcer/SOURCES.md","res://deathmatch/network/disk_worker.gd","res://deathmatch/maps/contents.gd","res://deathmatch/maps/filtering.gd","res://deathmatch/movement/quake.gd","res://deathmatch/movement/LICENSE.txt","res://deathmatch/voice/microphone.gd","res://deathmatch/modes/lobby_mirror.gd","res://deathmatch/modes/lobby_wall.gd","res://deathmatch/ui/choice.gd","res://addons/twovoip/twovoip.gdextension","res://addons/twovoip/LICENSE.txt","res://deathmatch/network/loading.gd","res://deathmatch/network/loading_overlay.gd","res://deathmatch/projectile_targets.gd","res://deathmatch/lag_compensation.gd","res://deathmatch/maps/static_batch.gd","res://deathmatch/maps/librequake-props/flame.json","res://deathmatch/maps/librequake-props/LICENCE.txt","res://deathmatch/maps/librequake-props/CREDITS.txt","res://deathmatch/maps/librequake-props/SOURCES.json"]:
		if not FileAccess.file_exists(required) and not FileAccess.file_exists(required+".remap") and not ResourceLoader.exists(required):failures.append("Missing "+required)
	for required in ["deathmatch/avatars/hit_body.gd","deathmatch/maps/import_policy.gd","deathmatch/maps/previews.gd","deathmatch/maps/teleport_exit.gd","deathmatch/lighting/weapon_pool.gd","deathmatch/lighting/weapon_emission.gd","deathmatch/lighting/solid_tree.gd","deathmatch/lighting/weapon_light.gdshaderinc","deathmatch/audio/round_gong.wav"]:
		if not FileAccess.file_exists("res://"+required) and not ResourceLoader.exists("res://"+required):failures.append("Missing release feature: "+required)
	var config=load("res://deathmatch/server/config.gd")
	if config.DEFAULTS.has("sv_tb_heavy_ordnance") or config.RANGES.has("sv_tb_heavy_ordnance"):failures.append("Retired TB server setting")
	var walker=load("res://deathmatch/vehicles/ba2/controller.gd").new()
	if walker.PILOT_MAX_HEALTH!=200 or not walker.heavy_ordnance_only or walker.pilot_regeneration:failures.append("Incorrect fixed TB defaults")
	walker.free()
	if not ResourceLoader.exists("res://deathmatch/server/bot_population.gd"):failures.append("Missing dedicated bot population")
	print("PACKAGE_AUDIT ",JSON.stringify({"pack":args[0],"files":count,"failures":failures}));quit(0 if failures.is_empty() else 1)
