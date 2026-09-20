extends Node
## VRM is the only remotely supplied asset. Geometry and gameplay stay server-owned.
const Library=preload("res://deathmatch/avatars/library.gd")
var library:=Library.new()
var base:=""
var pending: Dictionary={}
var failed: Dictionary={}
var render_failed: Dictionary={}
func _ready() -> void:add_child(library)
func setup(url: String) -> void:base=url.trim_suffix("/")
func upload(path: String,auth: Dictionary) -> String:
	if base.is_empty():return "Content service is not configured"
	var inspected:=Library.inspect(path)
	if inspected.has("error"):return inspected.error
	var request:=HTTPRequest.new();add_child(request);request.timeout=35;request.body_size_limit=8192
	var headers:=PackedStringArray(["Content-Type: application/octet-stream","X-CQ-ID: "+str(auth.actor),"X-CQ-Secret: "+str(auth.resume)])
	var error:=request.request_raw(base+"/vrm",headers,HTTPClient.METHOD_POST,FileAccess.get_file_as_bytes(path))
	if error!=OK:request.queue_free();return "VRM upload could not start"
	var result: Array=await request.request_completed;request.queue_free()
	if result[0]!=HTTPRequest.RESULT_SUCCESS or result[1]!=200:return "VRM upload rejected or temporarily unavailable"
	library.register_file(path)
	return ""
func fetch(hash: String) -> void:
	if failed.has(hash) and Time.get_ticks_msec()>=int(failed[hash]):failed.erase(hash)
	if base.is_empty() or not Library.valid_hash(hash) or library.entries.has(hash) or pending.has(hash) or failed.has(hash) or pending.size()>=2:return
	pending[hash]=true
	var request:=HTTPRequest.new();add_child(request);request.timeout=120;request.body_size_limit=Library.MAX_BYTES
	var error:=request.request(base+"/vrm/"+hash+".vrm")
	if error!=OK:request.queue_free();pending.erase(hash);failed[hash]=Time.get_ticks_msec()+5000;return
	var result: Array=await request.request_completed;request.queue_free();pending.erase(hash)
	if result[0]!=HTTPRequest.RESULT_SUCCESS or result[1]!=200:failed[hash]=Time.get_ticks_msec()+5000;return
	var data: PackedByteArray=result[3]
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(data)
	if digest.finish().hex_encode()!=hash or not library.reserve_cache(data.size()):failed[hash]=Time.get_ticks_msec()+30000;return
	var path: String=Library.CACHE+hash+".vrm"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if not file:failed[hash]=Time.get_ticks_msec()+30000;return
	file.store_buffer(data);file.close()
	if library.register_file(path,false).is_empty():DirAccess.remove_absolute(path);failed[hash]=Time.get_ticks_msec()+30000
func create(hash: String) -> Node3D:
	if not library.entries.has(hash):fetch(hash);return null
	if Time.get_ticks_msec()<int(render_failed.get(hash,0)):return null
	var model:=library.create_avatar(hash)
	if model==null:render_failed[hash]=Time.get_ticks_msec()+30000
	return model
