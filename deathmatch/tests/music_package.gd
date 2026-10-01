extends SceneTree
## Run this external script with --main-pack CLIENT.pck from a clean directory.
func _initialize():
	var kept: Array=[];var failures: Array=[]
	for name in DirAccess.get_files_at("res://deathmatch/audio/music"):
		if name.ends_with(".ogg") or name.ends_with(".ogg.remap") or name.ends_with(".ogg.import"):
			kept.append(name.trim_suffix(".remap").trim_suffix(".import"))
	kept.sort()
	if kept!=["dead_air.ogg","please_hold.ogg","tower_defense_climax.ogg"]:failures.append("Unexpected bundled music: "+str(kept))
	if DirAccess.dir_exists_absolute("res://bgm"):failures.append("External bgm folder imported into PCK")
	for name in ["player.gd","catalog.gd","climax.gd"]:
		if not ResourceLoader.exists("res://deathmatch/audio/music/"+name):failures.append("Missing "+name)
	var music=load("res://deathmatch/audio/music/player.gd")
	var cue=music.load_track(music.WIN_TRACK)
	if not cue or not cue.loop or absf(cue.get_length()-75)>.05 or not is_equal_approx(cue.loop_offset,music.WIN_LOOP_OFFSET):failures.append("Exported climax cue does not decode/loop correctly")
	print("MUSIC_PACKAGE ",JSON.stringify({"tracks":kept,"failures":failures}));quit(0 if failures.is_empty() else 1)
