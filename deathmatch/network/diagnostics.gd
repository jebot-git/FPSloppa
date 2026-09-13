extends RefCounted
## Small client-side connection journal; no voice, chat, passwords or avatar poses.
static func record(stage: String,data: Dictionary={}) -> void:
	var path:="user://client-network.jsonl"
	if FileAccess.file_exists(path) and preload("res://deathmatch/network/disk_worker.gd").size(path)>1024*1024:
		var old:=ProjectSettings.globalize_path(path+".1")
		if FileAccess.file_exists(old):DirAccess.remove_absolute(old)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path),old)
	var file:=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file:
		file.seek_end();file.store_line(JSON.stringify({"utc":Time.get_datetime_string_from_system(true)+"Z","stage":stage,"data":data}));file.close()
