extends Node
## Locally derived scenes only. Network/upload inputs remain validated VRM bytes.
# Initialize MToon's shared shader include on the main thread. First use through
# a threaded scene load leaks a RefCounted in Godot 4.7.2's shader-include path.
const MTOON_SHADER=preload("res://addons/Godot-MToon-Shader/mtoon.gdshader")
const FORMAT_VERSION=1
const MAX_FILE_BYTES=128_000_000
const DISK_BUDGET=512_000_000
const MAX_REQUESTS=2
const ROOT="user://avatar-runtime-cache/"
static var fingerprint_value:=""
var directory:=ROOT
var disk_budget:=DISK_BUDGET
var requests:Dictionary={}
var completed:Dictionary={}
var rejected:Dictionary={}
var writer:=Thread.new()
var snapshot:PackedScene
var write_queue:Array=[]
var writing_path:=""
var stats:={"hits":0,"misses":0,"writes":0,"failures":0,"snapshot_ms":0.0,"save_ms":0.0,"skipped_writes":0}

static func fingerprint() -> String:
	if not fingerprint_value.is_empty():return fingerprint_value
	var files:Array[String]=[]
	for folder in ["res://addons/vrm","res://addons/Godot-MToon-Shader"]:collect_files(folder,files)
	files.append_array(["res://deathmatch/avatars/surface_compiler.gd","res://deathmatch/avatars/rest_bounds.gd","res://deathmatch/avatars/visual_loader.gd","res://deathmatch/maps/filtering.gd"])
	files.sort()
	var parts:=[str(FORMAT_VERSION),Engine.get_version_info().string,Engine.get_version_info().hash,str(OS.has_feature("double")),str(ProjectSettings.get_setting("application/config/version",""))]
	for path in files:
		parts.append(path+":"+file_fingerprint(path))
	fingerprint_value="|".join(parts).sha256_text()
	return fingerprint_value
static func file_fingerprint(path:String) -> String:
	var actual=path if FileAccess.file_exists(path) else path+".remap"
	var digest:=FileAccess.get_sha256(actual)
	# Exported projects may contain bytecode behind a stable .gd.remap path.
	# Hash its target too, so rebuilding a plugin invalidates old derived scenes.
	if actual.ends_with(".remap"):
		var remap:=ConfigFile.new()
		if remap.load(actual)==OK:
			var target:String=remap.get_value("remap","path","")
			if not target.is_empty():digest+=FileAccess.get_sha256(target)
	return digest
static func collect_files(folder:String,files:Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd","gdc","gdshader","gdshaderinc","tres","res","remap"]:files.append(folder.path_join(file))
	for child in DirAccess.get_directories_at(folder):collect_files(folder.path_join(child),files)
func path_for(hash:String,compiled:bool) -> String:
	return directory.path_join((hash+fingerprint()+str(compiled)+str(DisplayServer.get_name()=="headless")).sha256_text()+".scn")
func enabled(hash:String) -> bool:
	return is_inside_tree() and not OS.get_cmdline_user_args().has("--no-avatar-disk-cache") and hash.length()==64 and hash.is_valid_hex_number(false)
# Returns pending/ready/miss. Never calls threaded_get until loading has finished.
func request(hash:String,compiled:bool) -> Dictionary:
	if not enabled(hash):return {"status":"miss"}
	var path:=path_for(hash,compiled)
	if rejected.has(path):return {"status":"miss"}
	if completed.has(path):
		var packed=completed[path];completed.erase(path);stats.hits+=1
		return {"status":"ready","scene":packed}
	if not requests.has(path):
		var file:=FileAccess.open(path,FileAccess.READ)
		if not file:return {"status":"miss"}
		var size:=file.get_length();var magic:=file.get_buffer(4).get_string_from_ascii();file.close()
		if size<64 or size>MAX_FILE_BYTES or magic not in ["RSCC","RSRC"]:
			rejected[path]=true;DirAccess.remove_absolute(path);stats.failures+=1;return {"status":"miss"}
		if requests.size()>=MAX_REQUESTS:return {"status":"pending"}
		if ResourceLoader.load_threaded_request(path,"PackedScene",false,ResourceLoader.CACHE_MODE_IGNORE)!=OK:
			rejected[path]=true;stats.failures+=1;return {"status":"miss"}
		requests[path]=true
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed=ResourceLoader.load_threaded_get(path);requests.erase(path)
			if packed is PackedScene and packed.can_instantiate():
				stats.hits+=1;return {"status":"ready","scene":packed}
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:return {"status":"pending"}
	requests.erase(path);rejected[path]=true;stats.failures+=1
	DirAccess.remove_absolute(path)
	return {"status":"miss"}
func finish_sync(hash:String,compiled:bool) -> PackedScene:
	var path:=path_for(hash,compiled)
	if not requests.has(path):return null
	var packed=ResourceLoader.load_threaded_get(path)
	requests.erase(path)
	if packed is PackedScene and packed.can_instantiate():stats.hits+=1;return packed
	rejected[path]=true;stats.failures+=1;DirAccess.remove_absolute(path)
	return null
func reject(hash:String,compiled:bool) -> void:
	var path:=path_for(hash,compiled)
	rejected[path]=true;completed.erase(path);stats.failures+=1
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
func store(hash:String,compiled:bool,packed:PackedScene) -> void:
	if not enabled(hash):return
	_poll_writer()
	var path:=path_for(hash,compiled)
	if FileAccess.file_exists(path) or writing_path==path:return
	for job in write_queue:
		if job.path==path:return
	if write_queue.size()>=2:stats.skipped_writes+=1;return
	# Runtime configuration edits shared materials. Give the writer an isolated
	# resource graph before any instance can mutate those imported resources.
	var start:=Time.get_ticks_usec()
	var frozen:PackedScene=copy_for_save(packed,{})
	stats.snapshot_ms=(Time.get_ticks_usec()-start)/1000.0
	write_queue.append({"scene":frozen,"path":path})
	_start_writer()
func _start_writer() -> void:
	if writer.is_started() or write_queue.is_empty():return
	var job:Dictionary=write_queue.pop_front();snapshot=job.scene;writing_path=job.path
	if writer.start(save_scene.bind(snapshot,writing_path,disk_budget))!=OK:
		snapshot=null;writing_path="";stats.failures+=1
func _process(_delta:float) -> void:
	_poll_writer()
	# Cancelled previews must not occupy the limited load slots indefinitely.
	for path in requests.keys():
		var status:=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:continue
		var packed=ResourceLoader.load_threaded_get(path) if status==ResourceLoader.THREAD_LOAD_LOADED else null
		requests.erase(path)
		if packed is PackedScene and packed.can_instantiate():completed[path]=packed
		else:rejected[path]=true;stats.failures+=1;DirAccess.remove_absolute(path)
	while completed.size()>MAX_REQUESTS:completed.erase(completed.keys()[0])
func _poll_writer() -> void:
	if writer.is_started() and not writer.is_alive():
		var result:Dictionary=writer.wait_to_finish()
		stats.save_ms=result.ms
		stats.writes+=int(result.ok);stats.failures+=int(not result.ok)
		if result.ok:rejected.erase(result.path)
		snapshot=null;writing_path=""
	_start_writer()
func _exit_tree() -> void:
	# Queued derived entries are optional; finish only the write already running.
	write_queue.clear()
	# Finish owned writes before releasing resources / shutting down the renderer.
	if writer.is_started():writer.wait_to_finish()
	snapshot=null
	# ResourceLoader has no cancellation API; retain ownership until outstanding
	# requests finish. This wait is shutdown-only, never a frame-path operation.
	for path in requests:ResourceLoader.load_threaded_get(path)
	requests.clear()
	completed.clear()
# Keep immutable texture/shader payloads shared; duplicating ImageTextures
# forces costly GPU readbacks. Mutable materials and plugin resources are copied.
static func copy_for_save(value,seen:Dictionary):
	if value is Texture2D or value is Shader or value is ShaderInclude or value is Script or value is Image:return value
	if value is Resource:
		if seen.has(value):return seen[value]
		var copy:Resource=value.duplicate(false);seen[value]=copy
		for property in value.get_property_list():
			if not property.usage & PROPERTY_USAGE_STORAGE or property.name in ["script","resource_path"]:continue
			var child=value.get(property.name)
			if child is Resource or child is Array or child is Dictionary:copy.set(property.name,copy_for_save(child,seen))
		return copy
	if value is Array:
		var copy:Array=value.duplicate()
		for i in copy.size():copy[i]=copy_for_save(copy[i],seen)
		return copy
	if value is Dictionary:
		var copy:Dictionary=value.duplicate()
		for key in copy:copy[key]=copy_for_save(copy[key],seen)
		return copy
	return value
static func save_scene(packed:PackedScene,path:String,budget:int) -> Dictionary:
	var start:=Time.get_ticks_usec()
	var folder:=path.get_base_dir();DirAccess.make_dir_recursive_absolute(folder)
	var temp:=path.trim_suffix(".scn")+".tmp-"+str(OS.get_process_id())+"-"+str(OS.get_thread_caller_id())+"-"+str(start)+".scn"
	var error:=ResourceSaver.save(packed,temp,ResourceSaver.FLAG_COMPRESS)
	var size:=0
	if error==OK:
		var file:=FileAccess.open(temp,FileAccess.READ);size=file.get_length() if file else 0
		if size<64 or size>mini(MAX_FILE_BYTES,budget):error=ERR_OUT_OF_MEMORY
	if error==OK:
		var total:=size;var entries:=[]
		for name in DirAccess.get_files_at(folder):
			if not name.ends_with(".scn") or ".tmp-" in name:continue
			var old:=folder.path_join(name);var file:=FileAccess.open(old,FileAccess.READ)
			if file:entries.append({"path":old,"size":file.get_length(),"time":FileAccess.get_modified_time(old)});total+=file.get_length()
		entries.sort_custom(func(a,b):return a.time<b.time)
		for row in entries:
			if total<=budget:break
			if DirAccess.remove_absolute(row.path)==OK:total-=row.size
		if total>budget:error=ERR_OUT_OF_MEMORY
		else:error=DirAccess.rename_absolute(temp,path)
	if error!=OK and FileAccess.file_exists(temp):DirAccess.remove_absolute(temp)
	return {"ok":error==OK,"ms":(Time.get_ticks_usec()-start)/1000.0,"bytes":size,"path":path}
