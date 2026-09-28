extends SceneTree
func _initialize():
	var names: Array=["explosion","bounce"]
	for w in 12:names.append("weapon_"+str(w))
	for name in names:
		var data:=FileAccess.get_file_as_bytes("res://tools/tribes/refined/"+name+".wav")
		var audio:=AudioStreamWAV.load_from_buffer(data,{"compress/mode":2})
		assert(audio!=null);assert(ResourceSaver.save(audio,"res://deathmatch/audio/tribes/"+name+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	quit()
