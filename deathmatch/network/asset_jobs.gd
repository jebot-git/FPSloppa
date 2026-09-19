extends RefCounted
## Pure disk/metadata work: never accesses the scene tree or shared resources.
const Maps=preload("res://deathmatch/maps/loader.gd")
const Models=preload("res://deathmatch/avatars/library.gd")
static func publish(path: String,destination: String,hash: String) -> Error:
	if path==destination or FileAccess.file_exists(destination) and FileAccess.get_sha256(destination)==hash:return OK
	# Multiple local clients can share a cache. Never expose a truncated canonical
	# file while another process is copying an already verified download into it.
	var temporary:=destination+".%d.%d.%d.tmp"%[OS.get_process_id(),Time.get_ticks_usec(),randi()]
	var error:=DirAccess.copy_absolute(path,temporary)
	if error==OK:error=DirAccess.rename_absolute(temporary,destination)
	if FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
	return error
static func map_file(path: String,hash: String,title: String,directory: String,source_name: String="") -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=hash:return {"error":"Map checksum failed."}
	var error:=Maps.validate(path)
	if not error.is_empty():return {"error":error}
	var spawn_error:=Maps.ImportPolicy.spawn_error(path)
	if not spawn_error.is_empty():return {"error":spawn_error}
	var id:="custom_"+hash
	var destination:=directory+id+".bsp"
	DirAccess.make_dir_recursive_absolute(directory+"cache")
	if publish(path,destination,hash)!=OK:return {"error":"Cannot save map."}
	var metadata:=Maps.ImportPolicy.save(directory,hash,source_name,title)
	if metadata.has("error"):return metadata
	var entry:={"id":id,"path":destination,"scene":directory+"cache/"+hash+".scn","sha256":hash,"size":preload("res://deathmatch/network/disk_worker.gd").size(destination)}
	entry.merge(metadata);return entry

static func model_file(path: String,hash: String,directory: String,copy: bool=true) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=hash:return {"error":"Model checksum failed."}
	var info:=Models.inspect(path)
	if info.has("error"):return info
	var destination:=directory+hash+".vrm" if copy else path
	if copy and not FileAccess.file_exists(destination) and not room(directory,"vrm",info.size,Models.CACHE_BUDGET):return {"error":"Avatar cache is full (1 GB)."}
	DirAccess.make_dir_recursive_absolute(directory)
	if publish(path,destination,hash)!=OK:return {"error":"Cannot save model."}
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
