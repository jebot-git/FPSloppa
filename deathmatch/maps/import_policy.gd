extends RefCounted
## Classification survives hash-based storage; filenames never become disk paths.
const MODES=["dm","tdm","ctf","koth","ig","if","ft","cc","tf","tb","as"]
const DEFAULT_MODES=["dm","tdm","ig","ft","if"]
static func source_name(value: String) -> String:
	var name:=value.replace("\\","/").get_file()
	return (name.get_basename() if name.get_extension().to_lower()=="bsp" else name).left(80)
static func modes(value: String) -> Array:
	var name:=source_name(value).to_lower()
	var prefix:=name.get_slice("_",0)
	return [prefix] if name.contains("_") and prefix in MODES else DEFAULT_MODES.duplicate()
static func metadata_path(directory: String,hash: String) -> String:return directory+"cache/"+hash+"-import.json"
static func save(directory: String,hash: String,name: String,title: String) -> Dictionary:
	var data:={"source_name":source_name(name),"title":title.left(60),"modes":modes(name),"imported":true}
	DirAccess.make_dir_recursive_absolute(directory+"cache")
	var path:=metadata_path(directory,hash);var temporary:=path+".%d.tmp"%Time.get_ticks_usec()
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if not file:return {"error":"Cannot save map classification."}
	file.store_string(JSON.stringify(data));file.close()
	if DirAccess.rename_absolute(temporary,path)!=OK:
		DirAccess.remove_absolute(temporary);return {"error":"Cannot publish map classification."}
	return data
static func read(directory: String,hash: String,fallback: String,title: String) -> Dictionary:
	var path:=metadata_path(directory,hash)
	if FileAccess.file_exists(path):
		var file:=FileAccess.open(path,FileAccess.READ)
		if file and file.get_length()<4096:
			var data=JSON.parse_string(file.get_as_text())
			if data is Dictionary and data.get("source_name") is String:
				return {"source_name":source_name(data.source_name),"title":str(data.get("title",title)).left(60),"modes":modes(data.source_name),"imported":true}
	return {"source_name":source_name(fallback),"title":title,"modes":modes(fallback),"imported":true}
static func spawn_error(path: String) -> String:
	var file:=FileAccess.open(path,FileAccess.READ)
	file.seek(4);var offset:=file.get_32();var length:=file.get_32();file.seek(offset)
	var text:=file.get_buffer(length).get_string_from_utf8()
	var regex:=RegEx.new();regex.compile('"classname"\\s*"(info_player_deathmatch|info_player_team1|info_player_team2|info_player_teamspawn|info_tb_spawn)"')
	return "Map requires at least two supported multiplayer spawns." if regex.search_all(text).size()<2 else ""
