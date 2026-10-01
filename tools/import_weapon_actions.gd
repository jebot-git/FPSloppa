extends SceneTree
func _initialize():
	var folder:='res://deathmatch/audio/weapon-actions'
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(folder+'/manifest.json'))
	for row in manifest.files:
		var sound:=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(folder+'/'+row.name+'.wav'))
		assert(sound!=null and not sound.stereo)
		if row.loop:
			sound.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.loop_begin=0;sound.loop_end=sound.data.size()/2
		assert(ResourceSaver.save(sound,folder+'/'+row.name+'.res',ResourceSaver.FLAG_COMPRESS)==OK)
	print('WEAPON_ACTION_IMPORT ',manifest.files.size());quit()
