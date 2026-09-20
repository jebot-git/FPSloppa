extends SceneTree
func _initialize() -> void:
	var path:=OS.get_cmdline_user_args()[0]
	var pending: Array=JSON.parse_string(FileAccess.get_file_as_string(path));var seen: Dictionary={}
	while not pending.is_empty():
		var relative: String=pending.pop_back()
		if seen.has(relative):continue
		seen[relative]=true
		if relative.get_extension() in ["scn","res","tres","tscn"]:
			for dependency in ResourceLoader.get_dependencies("res://"+relative):
				var resource: String=dependency.split("::")[-1]
				if resource.begins_with("res://"):pending.append(resource.trim_prefix("res://"))
		var imported:="res://"+relative+".import"
		if FileAccess.file_exists(imported):
			seen[relative+".import"]=true
			var config:=ConfigFile.new();config.load(imported)
			for target in config.get_value("deps","dest_files",[]):pending.append(str(target).trim_prefix("res://"))
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(seen.keys()));quit()
