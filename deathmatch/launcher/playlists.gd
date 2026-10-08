extends RefCounted
## Owned M3U8 files reference hidden, numbered copies. The game's catalog sorts
## by basename even for M3U entries, so numbering makes editor order authoritative.
const Catalog=preload("res://deathmatch/audio/music/catalog.gd")
static func stem(scope: String,target: String,climax: bool) -> String:
	var value:=target.to_lower()
	if scope=="global":value="launcher_global"
	elif scope=="mode" and not value in Catalog.MODES:return ""
	elif scope=="map" and (value.is_empty() or value!=value.validate_filename() or value.begins_with(".") or value.contains("/") or value.contains("\\")):return ""
	elif scope not in ["mode","map"]:return ""
	return ("win_" if climax else "")+value+("" if scope=="global" else "_launcher")
static func read_index(folder: String) -> Dictionary:
	var path:=folder.path_join(".launcher-playlists.json")
	if not FileAccess.file_exists(path):return {}
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
static func write_text(path: String,text: String) -> Error:
	var temporary:=path+".%d.tmp"%OS.get_process_id()
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if not file:return FileAccess.get_open_error()
	file.store_string(text);var error:=file.get_error();file.close()
	if error==OK:error=DirAccess.rename_absolute(temporary,path)
	if FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
	return error
static func save(folder: String,scope: String,target: String,climax: bool,tracks: Array,progress: Callable=Callable(),cancelled: Callable=Callable(),titles: Array=[]) -> Dictionary:
	var name:=stem(scope,target,climax)
	if name.is_empty() or tracks.is_empty() or tracks.size()>256:return {"error":"Choose a scope and 1–256 Ogg Vorbis tracks."}
	var index:=read_index(folder);var destination:=folder.path_join(name+".m3u8")
	if FileAccess.file_exists(destination) and not index.has(name):return {"error":"An existing playlist uses that name. Rename it before saving here."}
	for path in tracks:
		if cancelled.is_valid() and cancelled.call():return {"error":"Cancelled."}
		if not path is String or path.get_extension().to_lower()!="ogg" or not FileAccess.file_exists(path):return {"error":"Track is missing or is not an OGG file: "+str(path)}
		if AudioStreamOggVorbis.load_from_file(path)==null:return {"error":"Cannot decode Ogg Vorbis track: "+path.get_file()}
	var relative:=".launcher-tracks/"+name+"-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	var directory:=folder.path_join(relative)
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return {"error":"Cannot create the music folder."}
	var lines: Array[String]=["#EXTM3U","# FPSloppa launcher; numbered copies preserve playback order."]
	var saved: Array=[]
	for i in tracks.size():
		if cancelled.is_valid() and cancelled.call():cleanup(directory);return {"error":"Cancelled."}
		var filename:="%04d.ogg"%(i+1)
		var dest:=directory.path_join(filename)
		if DirAccess.copy_absolute(tracks[i],dest)!=OK:
			cleanup(directory);return {"error":"Could not copy "+tracks[i].get_file()}
		lines.append(relative+"/"+filename)
		saved.append({"path":dest,"title":titles[i] if titles.size()==tracks.size() else tracks[i].get_file()})
		if progress.is_valid():progress.call(i+1,tracks.size(),tracks[i].get_file())
	var old: Dictionary=index.get(name,{})
	if cancelled.is_valid() and cancelled.call():cleanup(directory);return {"error":"Cancelled."}
	var record:={"scope":scope,"target":target,"climax":climax,"tracks":saved,"directory":directory}
	# Record ownership before publishing; preserve earlier records if publishing fails.
	index[name]=record
	if write_text(folder.path_join(".launcher-playlists.json"),JSON.stringify(index,"  "))!=OK:
		cleanup(directory);return {"error":"Could not save playlist metadata."}
	if write_text(destination,"\n".join(lines)+"\n")!=OK:
		if old.is_empty():index.erase(name)
		else:index[name]=old
		write_text(folder.path_join(".launcher-playlists.json"),JSON.stringify(index,"  "))
		cleanup(directory);return {"error":"Could not publish playlist."}
	# Old audio stays available: another running client may still be playing it.
	return {"path":destination,"tracks":saved.size(),"message":"Saved "+name+".m3u8 · restart the game to rescan music."}
static func cleanup(directory: String) -> void:
	for file in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
