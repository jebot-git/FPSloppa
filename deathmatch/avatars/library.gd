extends Node
## Content-addressed, self-contained UT99 vertex avatar library. Gameplay never derives collision from it.
# Dedicated servers validate containers without creating render resources.
var visual_loader:Script
func _init() -> void:
	if not OS.has_feature("dedicated_server"):
		visual_loader=load("res://deathmatch/avatars/visual_loader.gd")
const MAX_BYTES := 25_000_000
const Paths=preload("res://deathmatch/assets/paths.gd")
static var CACHE: String:
	get: return Paths.folder("ut99")
var entries: Dictionary = {}
var scenes: Dictionary = {}
var scene_used:Dictionary={}
var scene_instances:Dictionary={}
var scene_clock:=0
const INACTIVE_SCENES=4
func touch_scene(hash:String) -> void:
	scene_clock+=1;scene_used[hash]=scene_clock
func track_instance(hash:String,rig:Node) -> void:
	if not scene_instances.has(hash):scene_instances[hash]=[]
	scene_instances[hash].append(weakref(rig));touch_scene(hash)
func prune_scenes(keep:String="") -> void:
	var inactive:=[]
	for hash in scenes:
		var live:Array=scene_instances.get(hash,[]).filter(func(reference):return is_instance_valid(reference.get_ref()))
		if live.is_empty():scene_instances.erase(hash)
		else:scene_instances[hash]=live
		if live.is_empty() and hash not in pinned and hash!=keep and hash!=selected:inactive.append(hash)
	inactive.sort_custom(func(a,b):return int(scene_used.get(a,0))<int(scene_used.get(b,0)))
	while inactive.size()>INACTIVE_SCENES:
		var hash:String=inactive.pop_front();scenes.erase(hash);scene_used.erase(hash)
func prepare_avatar(hash:String) -> bool:
	return visual_loader.prepare_avatar(self,hash) if visual_loader else false

var selected := ""
var last_error := ""
var launch_avatar_applied:=false
var pinned: Array = []
const CACHE_BUDGET := 1_000_000_000

var cache_prune_time:=0.0
func _process(delta:float) -> void:
	cache_prune_time+=delta
	if cache_prune_time>=2.0:cache_prune_time=0.0;prune_scenes()
func _ready() -> void:reload()
func reload() -> void:
	entries.clear();selected=""
	DirAccess.make_dir_recursive_absolute(CACHE)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
	if manifest is Array:
		for row in manifest:
			row=row.duplicate(true);row.path=Paths.resolve(row.path);row.size=int(row.size)
			if not FileAccess.file_exists(row.path) or FileAccess.get_sha256(row.path)!=row.hash:continue
			entries[row.hash] = row
			if selected.is_empty(): selected = row.hash
	for filename in DirAccess.get_files_at(CACHE):
		if filename.get_extension().to_lower()=="utavatar":register_file(CACHE+filename,false)
	if selected.is_empty() and not entries.is_empty():selected=entries.keys()[0]
	var config := ConfigFile.new()
	if config.load("user://ut99_avatars.cfg") == OK:
		for saved in config.get_value("avatar","imports",[]):
			if saved is String and valid_hash(saved) and FileAccess.file_exists(CACHE+saved+".utavatar"):
				register_file(CACHE+saved+".utavatar",false)
		var hash: String = config.get_value("avatar", "selected", selected)
		if valid_hash(hash) and not entries.has(hash) and FileAccess.file_exists(CACHE+hash+".utavatar"):
			register_file(CACHE+hash+".utavatar", false)
		if entries.has(hash): selected = hash

	# An explicit launcher choice wins over the shared saved avatar for this run.
	if not launch_avatar_applied:
		launch_avatar_applied=true
		var args:=OS.get_cmdline_user_args();var index:=args.find("--avatar")
		if index>=0 and index+1<args.size() and valid_hash(args[index+1]) and entries.has(args[index+1]):selected=args[index+1]

static func valid_hash(value: String) -> bool:
	if value.length() != 64: return false
	for c in value:
		if not c in "0123456789abcdef": return false
	return true

static func inspect(path:String) -> Dictionary:
	return preload("res://deathmatch/avatars/ut_format.gd").inspect(path)

func register_file(path: String, copy_to_cache: bool = true) -> String:
	var info := inspect(path)
	if info.has("error"):
		last_error = info.error
		return ""
	var hash := FileAccess.get_sha256(path)
	if copy_to_cache:
		var destination := CACHE+hash+".utavatar"
		if not FileAccess.file_exists(destination) and not reserve_cache(info.size):
			last_error = "Avatar cache is full (1 GB). Leave the match or choose a smaller model."
			return ""
		if path!=destination and DirAccess.copy_absolute(path,destination)!=OK:
			last_error = "Cannot save model to avatar cache."
			return ""
		path = destination
	info.path = path
	info.hash = hash
	entries[hash] = info
	last_error = ""
	return hash

func base_templates() -> Dictionary:
	var result:={}
	for hash in entries:
		var model:String=entries[hash].get("base_model","")
		if not model.is_empty() and entries[hash].path.begins_with("res://"):result[model]=hash
	return result
func register_skin(package:Dictionary,base_hash:String,group:String,face:String) -> String:
	if not entries.has(base_hash):last_error="Prepared base model is missing.";return ""
	var temporary:=CACHE+"skin-import-"+str(Time.get_ticks_usec())+".part"
	var result:=preload("res://deathmatch/avatars/skin_import.gd").build(package,entries[base_hash],group,face,temporary)
	if result.has("error"):last_error=result.error;DirAccess.remove_absolute(temporary);return ""
	var hash:=register_file(temporary)
	DirAccess.remove_absolute(temporary)
	return hash

func choose(hash: String) -> void:
	if not entries.has(hash): return
	selected = hash
	var config := ConfigFile.new()
	config.set_value("avatar","selected",hash)
	config.set_value("avatar","imports",entries.keys().filter(func(key): return entries[key].path.begins_with(CACHE)))
	config.save("user://ut99_avatars.cfg")

func create_avatar(hash: String) -> Node3D:
	if OS.has_feature("dedicated_server"):return null
	return visual_loader.create_avatar(self,hash) if visual_loader else null

func reserve_cache(required: int) -> bool:
	var total := 0
	# Persistent libraries are never evicted behind the server operator's back.
	for file_name in DirAccess.get_files_at(CACHE):
		if not file_name.ends_with(".utavatar"): continue
		var path := CACHE+file_name
		var file := FileAccess.open(path,FileAccess.READ)
		if not file: continue
		var size := file.get_length()
		total += size
	return total+required<=CACHE_BUDGET
