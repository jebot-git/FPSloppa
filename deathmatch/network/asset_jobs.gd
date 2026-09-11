extends RefCounted
## Pure disk/metadata work: never accesses the scene tree or shared resources.
const Maps=preload("res://deathmatch/maps/loader.gd")
const Models=preload("res://deathmatch/avatars/library.gd")
static func map_file(path: String,hash: String,title: String,directory: String) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=hash:return {"error":"Map checksum failed."}
	var error:=Maps.validate(path)
	if not error.is_empty():return {"error":error}
	var file:=FileAccess.open(path,FileAccess.READ)
	file.seek(4);var start:=file.get_32();var length:=file.get_32();file.seek(start)
	var entities:=file.get_buffer(length).get_string_from_utf8();file.close()
	if entities.count('"info_player_deathmatch"')<2:return {"error":"Map requires at least two deathmatch spawns."}
	var id:="custom_"+hash
	var destination:=directory+id+".bsp"
	DirAccess.make_dir_recursive_absolute(directory+"cache")
	if path!=destination and DirAccess.copy_absolute(path,destination)!=OK:return {"error":"Cannot save map."}
	return {"id":id,"title":title,"path":destination,"scene":directory+"cache/"+hash+".scn","sha256":hash,"size":preload("res://deathmatch/network/disk_worker.gd").size(destination)}

static func model_file(path: String,hash: String,directory: String,copy: bool=true) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=hash:return {"error":"Model checksum failed."}
	var info:=Models.inspect(path)
	if info.has("error"):return info
	var destination:=directory+hash+".vrm" if copy else path
	if copy and not FileAccess.file_exists(destination) and not room(directory,"vrm",info.size,Models.CACHE_BUDGET):return {"error":"Avatar cache is full (1 GB)."}
	DirAccess.make_dir_recursive_absolute(directory)
	if path!=destination and DirAccess.copy_absolute(path,destination)!=OK:return {"error":"Cannot save model."}
	info.hash=hash;info.path=destination
	return info

static func room(directory: String,extension: String,required: int,limit: int) -> bool:
	var total:=required
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension()!=extension:continue
		var file:=FileAccess.open(directory+filename,FileAccess.READ)
		if file:total+=file.get_length()
	return total<=limit

static func verify_models(entries: Array) -> Array:
	var invalid: Array=[]
	for entry in entries:
		if preload("res://deathmatch/network/disk_worker.gd").size(entry.path)!=entry.size or FileAccess.get_sha256(entry.path)!=entry.hash:invalid.append(entry.hash)
	return invalid
