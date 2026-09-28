extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
func _initialize():
	var downloads: Array=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/avatars-cc0/downloads.json"))
	var manifest: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
	var results: Array=[]
	for row in downloads:
		var info:=Library.inspect("res://"+row.file);row.inspection=info
		if not info.has("error"):
			var destination: String="res://vrm/"+row.key.trim_prefix("avatar")+".vrm"
			assert(not FileAccess.file_exists(destination) or FileAccess.get_sha256(destination)==row.sha256)
			assert(DirAccess.copy_absolute("res://"+row.file,destination)==OK)
			row.destination=destination
			var record:={"hash":row.sha256,"path":destination,"size":row.bytes,"title":row.key.replace("_"," ").capitalize(),"author":"VRoid Project / pixiv","license":"CC0","version":"0.x"}
			var existing: Array=manifest.filter(func(entry):return entry.hash==row.sha256)
			if existing.is_empty():manifest.append(record)
		print("AVATAR ",row.key," ",JSON.stringify(info));results.append(row)
	FileAccess.open("res://test-results/avatars-cc0/inspection.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	FileAccess.open("res://deathmatch/avatars/models/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  ")+"\n")
	quit()
