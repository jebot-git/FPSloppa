extends SceneTree
func _initialize():
	DirAccess.make_dir_recursive_absolute("res://deathmatch/audio/cs16")
	for cue in ["mag_out","mag_in","rack_back","rack_close","empty_lock","snip"]:
		var stream:=AudioStreamWAV.load_from_file("res://tools/cs16/reload_audio/"+cue+".wav")
		assert(stream!=null)
		assert(ResourceSaver.save(stream,"res://deathmatch/audio/cs16/"+cue+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	quit()
