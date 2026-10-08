extends RefCounted
const Library=preload("res://deathmatch/avatars/library.gd")
static func scan(directory: String) -> Array:
	var rows: Array=[];var seen: Dictionary={}
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension().to_lower()!="vrm":continue
		var path:=directory.path_join(filename);var info:=Library.inspect(path)
		if info.has("error"):continue
		var hash:=FileAccess.get_sha256(path)
		if seen.has(hash):continue
		seen[hash]=true;info.hash=hash;info.path=path;rows.append(info)
	rows.sort_custom(func(a,b):return str(a.title).naturalnocasecmp_to(str(b.title))<0)
	return rows
static func selected() -> String:
	var config:=ConfigFile.new()
	return str(config.get_value("avatar","selected","")) if config.load("user://avatars.cfg")==OK else ""
static func choose(hash: String) -> Error:
	if hash.is_empty():return OK
	if not Library.valid_hash(hash):return ERR_INVALID_PARAMETER
	var config:=ConfigFile.new();var error:=config.load("user://avatars.cfg")
	if error!=OK and error!=ERR_FILE_NOT_FOUND:return error
	config.set_value("avatar","selected",hash)
	return config.save("user://avatars.cfg")
