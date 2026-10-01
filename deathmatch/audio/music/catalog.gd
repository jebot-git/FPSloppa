extends RefCounted
## Local client files only. Map names are checked before their mode prefix.
const MODES=preload("res://deathmatch/modes/match.gd").NAMES
const MAX_FILES:=4096
const MAX_PLAYLIST_BYTES:=1048576
var groups: Dictionary={}
var maps: Array[String]=[]
var count:=0
func scope(stem: String,container: bool=false) -> String:
	stem=stem.to_lower()
	var prefix:=""
	if stem.begins_with("win_"):
		prefix="win:";stem=stem.trim_prefix("win_")
	for map in maps:
		if stem==map or not container and stem.begins_with(map+"_"):return prefix+"map:"+map
	for mode in MODES:
		if stem==mode or not container and stem.begins_with(mode+"_"):return prefix+"mode:"+mode
	return "" if container else prefix+"global"
func scan(folder: String,map_names: Array) -> void:
	groups.clear();maps.clear();count=0
	for value in map_names:
		var key:=str(value).get_file().to_lower().trim_suffix(".bsp")
		if not key.is_empty() and key not in maps:maps.append(key)
	maps.sort_custom(func(a,b):return a.length()>b.length() if a.length()!=b.length() else a<b)
	var directory:=DirAccess.open(folder)
	if not directory:return
	for name in directory.get_files():
		if name.begins_with("."):continue
		add_file(folder.path_join(name),scope(name.get_basename()))
	for name in directory.get_directories():
		var key:=scope(name,true)
		if not key.is_empty():add_folder(folder.path_join(name),key,0)
	for key in groups:
		groups[key].sort_custom(func(a,b):
			var order: int=a.get_file().naturalnocasecmp_to(b.get_file())
			return a<b if order==0 else order<0)
func add_folder(path: String,key: String,depth: int) -> void:
	if depth>8 or count>=MAX_FILES:return
	var directory:=DirAccess.open(path)
	if not directory:return
	for name in directory.get_files():
		if not name.begins_with("."):add_file(path.path_join(name),key)
	for name in directory.get_directories():
		if not name.begins_with(".") and not directory.is_link(name):add_folder(path.path_join(name),key,depth+1)
func add_file(path: String,key: String) -> void:
	if count>=MAX_FILES:return
	# Prefixes inside a mode/map folder retain the inherited scope.
	if path.get_file().to_lower().begins_with("win_") and not key.begins_with("win:"):key="win:"+key
	match path.get_extension().to_lower():
		"ogg":add_track(path,key)
		"m3u","m3u8":
			var file:=FileAccess.open(path,FileAccess.READ)
			if not file or file.get_length()>MAX_PLAYLIST_BYTES:return
			for raw in file.get_as_text().trim_prefix("\ufeff").split("\n"):
				var line:=raw.strip_edges()
				if line.is_empty() or line.begins_with("#") or "://" in line:continue
				line=line.trim_prefix('"').trim_suffix('"').replace("\\","/")
				if line.get_extension().to_lower()!="ogg":continue
				add_track(line if line.is_absolute_path() else path.get_base_dir().path_join(line),key)
func add_track(path: String,key: String) -> void:
	path=ProjectSettings.globalize_path(path).simplify_path()
	if count>=MAX_FILES or not FileAccess.file_exists(path):return
	if not groups.has(key):groups[key]=[]
	if path not in groups[key]:groups[key].append(path);count+=1
func choose(mode: String,map: String,climax: bool=false) -> Dictionary:
	for key in ["map:"+map.get_file().to_lower().trim_suffix(".bsp"),"mode:"+mode.to_lower(),"global"]:
		if climax:key="win:"+key
		if groups.has(key) and not groups[key].is_empty():return {"key":key,"tracks":groups[key].duplicate()}
	return {"key":"silent","tracks":[]}
