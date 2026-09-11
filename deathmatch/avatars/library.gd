extends Node
## Content-addressed, self-contained VRM library. Gameplay never derives collision from it.
const MAX_BYTES := 25_000_000
const Paths=preload("res://deathmatch/assets/paths.gd")
static var CACHE: String:
	get: return Paths.folder("vrm")
const Extension = preload("res://addons/vrm/vrm_extension.gd")
const Rig = preload("res://deathmatch/avatars/rig.gd")
var entries: Dictionary = {}
var scenes: Dictionary = {}
var selected := ""
var last_error := ""
var pinned: Array = []
const CACHE_BUDGET := 1_000_000_000

func _ready() -> void:reload()
func reload() -> void:
	entries.clear();scenes.clear();selected=""
	DirAccess.make_dir_recursive_absolute(CACHE)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
	if manifest is Array:
		for row in manifest:
			row=row.duplicate(true);row.path=Paths.resolve(row.path)
			if not FileAccess.file_exists(row.path) or FileAccess.get_sha256(row.path)!=row.hash:continue
			entries[row.hash] = row
			if selected.is_empty(): selected = row.hash
	for filename in DirAccess.get_files_at(CACHE):
		if filename.get_extension().to_lower()=="vrm":register_file(CACHE+filename,false)
	# Copy older local imports once; keep the original files intact.
	if DirAccess.dir_exists_absolute("user://avatars"):
		for filename in DirAccess.get_files_at("user://avatars"):
			if filename.ends_with(".vrm") and not FileAccess.file_exists(CACHE+filename):register_file("user://avatars/"+filename)
	if selected.is_empty() and not entries.is_empty():selected=entries.keys()[0]
	var config := ConfigFile.new()
	if config.load("user://avatars.cfg") == OK:
		for saved in config.get_value("avatar","imports",[]):
			if saved is String and valid_hash(saved) and FileAccess.file_exists(CACHE+saved+".vrm"):
				register_file(CACHE+saved+".vrm",false)
		var hash: String = config.get_value("avatar", "selected", selected)
		if valid_hash(hash) and not entries.has(hash) and FileAccess.file_exists(CACHE+hash+".vrm"):
			register_file(CACHE+hash+".vrm", false)
		if entries.has(hash): selected = hash

static func valid_hash(value: String) -> bool:
	if value.length() != 64: return false
	for c in value:
		if not c in "0123456789abcdef": return false
	return true

static func inspect(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return {"error":"Cannot open this file."}
	var size := file.get_length()
	if size > MAX_BYTES: return {"error":"VRM exceeds 25 MB (25,000,000 bytes)."}
	if size < 28: return {"error":"Not a valid binary VRM."}
	if file.get_32()!=0x46546c67 or file.get_32()!=2 or file.get_32()!=size: return {"error":"Invalid GLB header."}
	var json_size := file.get_32()
	if file.get_32()!=0x4e4f534a or json_size > 8_000_000 or json_size+28>size: return {"error":"Invalid VRM JSON chunk."}
	var doc = JSON.parse_string(file.get_buffer(json_size).get_string_from_utf8())
	if not doc is Dictionary: return {"error":"Invalid VRM metadata."}
	var bin_size := file.get_32()
	if file.get_32()!=0x004e4942 or file.get_position()+bin_size!=size: return {"error":"A self-contained binary VRM is required."}
	var binary_start := file.get_position()
	var structure_error := validate_structure(doc)
	if not structure_error.is_empty(): return {"error":structure_error}
	var ext: Dictionary = doc.get("extensions",{})
	var vrm: Dictionary = ext.get("VRMC_vrm",ext.get("VRM",{}))
	if not vrm.has("humanoid") or not vrm.humanoid.has("humanBones"): return {"error":"VRM 0.x / 1.0 humanoid metadata is required."}
	var bones: Dictionary = {}
	var human = vrm.humanoid.humanBones
	if human is Array:
		for b in human:
			if not b is Dictionary: return {"error":"Invalid humanoid mapping."}
			bones[b.get("bone","")] = b.get("node",-1)
	elif human is Dictionary:
		for key in human:
			if not human[key] is Dictionary: return {"error":"Invalid humanoid mapping."}
			bones[key] = human[key].get("node",-1)
	else: return {"error":"Invalid humanoid mapping."}
	var nodes: Array = doc.get("nodes",[])
	if nodes.size()>4096: return {"error":"Model has more than 4,096 nodes."}
	for key in ["hips","spine","head","leftUpperArm","leftLowerArm","leftHand","rightUpperArm","rightLowerArm","rightHand","leftUpperLeg","leftLowerLeg","leftFoot","rightUpperLeg","rightLowerLeg","rightFoot"]:
		if not bones.has(key) or not bones[key] is float and not bones[key] is int: return {"error":"Missing humanoid bone: "+key}
		if bones[key]<0 or bones[key]>=nodes.size(): return {"error":"Invalid humanoid bone: "+key}
	var buffers: Array = doc.get("buffers",[])
	if buffers.size()!=1 or buffers[0].has("uri") or buffers[0].get("byteLength",0)>bin_size: return {"error":"External buffers are not allowed."}
	var views: Array = doc.get("bufferViews",[])
	for view in views:
		if view.get("buffer",0)!=0 or view.get("byteOffset",0)<0 or view.get("byteLength",0)<0 or view.get("byteOffset",0)+view.get("byteLength",0)>bin_size: return {"error":"Invalid buffer bounds."}
	var elements := 0
	for accessor in doc.get("accessors",[]):
		var count := int(accessor.get("count",0))
		if count<0 or count>3_000_000: return {"error":"Model geometry is too complex."}
		elements += count
	if elements>12_000_000: return {"error":"Model geometry is too complex."}
	var images: Array = doc.get("images",[])
	if images.size()>64: return {"error":"Maximum 64 embedded textures."}
	var pixels := 0
	for img in images:
		if img.has("uri"): return {"error":"External / data URI textures are not allowed; embed textures in the VRM."}
		var index := int(img.get("bufferView",-1))
		if index<0 or index>=views.size(): return {"error":"Invalid embedded image."}
		var view: Dictionary = views[index]
		file.seek(binary_start+int(view.get("byteOffset",0)))
		var dimensions := image_dimensions(file.get_buffer(int(view.byteLength)))
		if dimensions.x<=0 or dimensions.y<=0 or dimensions.x>8192 or dimensions.y>8192: return {"error":"Use PNG/JPEG textures, at most 8192 × 8192."}
		pixels += dimensions.x*dimensions.y
	if pixels>64_000_000: return {"error":"Textures exceed 64 million total pixels."}
	var meta: Dictionary = vrm.get("meta",{})
	return {"size":size,"title":str(meta.get("name",meta.get("title",path.get_file().get_basename()))).left(60),"author":str(meta.get("authors",meta.get("author","Unknown"))).left(120),"license":str(meta.get("licenseName",meta.get("licenseUrl","VRM 1.0 metadata"))),"version":"1.0" if ext.has("VRMC_vrm") else "0.x"}

static func image_dimensions(data: PackedByteArray) -> Vector2i:
	if data.size()>24 and data.slice(0,8).hex_encode()=="89504e470d0a1a0a":
		return Vector2i(be32(data,16),be32(data,20))
	if data.size()>4 and data[0]==255 and data[1]==216:
		var p := 2
		while p+8<data.size():
			if data[p]!=255: return Vector2i.ZERO
			var marker := int(data[p+1])
			p += 2
			if marker==255: p-=1; continue
			if marker in [216,217]: continue
			var length := int(data[p])*256+int(data[p+1])
			if length<2 or p+length>data.size(): return Vector2i.ZERO
			if marker in [192,193,194]: return Vector2i(int(data[p+5])*256+int(data[p+6]),int(data[p+3])*256+int(data[p+4]))
			p += length
	return Vector2i.ZERO

static func be32(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset])<<24)+(int(data[offset+1])<<16)+(int(data[offset+2])<<8)+int(data[offset+3])

func register_file(path: String, copy_to_cache: bool = true) -> String:
	var info := inspect(path)
	if info.has("error"):
		last_error = info.error
		return ""
	var hash := FileAccess.get_sha256(path)
	if copy_to_cache:
		var destination := CACHE+hash+".vrm"
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

func choose(hash: String) -> void:
	if not entries.has(hash): return
	selected = hash
	var config := ConfigFile.new()
	config.set_value("avatar","selected",hash)
	config.set_value("avatar","imports",entries.keys().filter(func(key): return entries[key].path.begins_with(CACHE)))
	config.save("user://avatars.cfg")

func create_avatar(hash: String) -> Node3D:
	if not entries.has(hash): return null
	if not scenes.has(hash):
		var gltf := GLTFDocument.new()
		var extensions: Array = [Extension.new(),preload("res://addons/vrm/1.0/VRMC_node_constraint.gd").new(),preload("res://addons/vrm/1.0/VRMC_springBone.gd").new(),preload("res://addons/vrm/1.0/VRMC_materials_mtoon.gd").new(),preload("res://addons/vrm/1.0/VRMC_materials_hdr_emissiveMultiplier.gd").new(),preload("res://addons/vrm/1.0/VRMC_vrm.gd").new()]
		for extension in extensions: GLTFDocument.register_gltf_document_extension(extension,true)
		var state := GLTFState.new()
		state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
		# Keep separate full and head-hidden mesh variants for remote/local views.
		state.set_additional_data("vrm/head_hiding_method",3)
		state.set_additional_data("vrm/first_person_layers",1<<19)
		state.set_additional_data("vrm/third_person_layers",1)
		var error := gltf.append_from_file(entries[hash].path,state,8)
		var model: Node3D = gltf.generate_scene(state) if error==OK else null
		for extension in extensions: GLTFDocument.unregister_gltf_document_extension(extension)
		if not model:
			last_error = "The VRM plugin could not load this model."
			return null
		var packed := PackedScene.new()
		packed.pack(model)
		model.free()
		# Keep only a few decoded models; original files remain available on disk.
		if scenes.size()>=4: scenes.erase(scenes.keys()[0])
		scenes[hash] = packed
	var rig := Rig.new()
	rig.name = "VRMAvatar"
	var model: Node3D = scenes[hash].instantiate()
	rig.add_child(model)
	if not rig.configure(model):
		rig.free()
		last_error = "Humanoid skeleton could not be normalized."
		return null
	if DisplayServer.get_name()!="headless":preload("res://deathmatch/maps/filtering.gd").new().apply(rig)
	return rig

static func validate_structure(doc: Dictionary) -> String:
	for key in ["nodes","buffers","bufferViews","accessors","images","meshes","skins","textures","materials","animations","scenes"]:
		if not doc.get(key,[]) is Array: return "Invalid VRM array: "+key
		for item in doc.get(key,[]):
			if not item is Dictionary: return "Invalid VRM object in "+key
	if not doc.get("extensions",{}) is Dictionary: return "Invalid extensions."
	for key in ["VRM","VRMC_vrm"]:
		if doc.get("extensions",{}).has(key):
			var vrm = doc.extensions[key]
			if not vrm is Dictionary or not vrm.get("meta",{}) is Dictionary or not vrm.get("humanoid",{}) is Dictionary: return "Invalid VRM metadata."
	var nodes: Array = doc.get("nodes",[])
	var parents: Dictionary = {}
	for i in range(nodes.size()):
		if not nodes[i].get("children",[]) is Array: return "Invalid node children."
		for child in nodes[i].get("children",[]):
			if not child is float or child!=floor(child) or child<0 or child>=nodes.size() or parents.has(int(child)): return "Invalid node hierarchy."
			parents[int(child)] = i
	for i in range(nodes.size()):
		var visited: Dictionary = {}
		var cursor := i
		while parents.has(cursor):
			if visited.has(cursor): return "Cyclic node hierarchy."
			visited[cursor] = true
			cursor = parents[cursor]
	for mesh in doc.get("meshes",[]):
		if not mesh.get("primitives",[]) is Array: return "Invalid mesh primitives."
		for primitive in mesh.get("primitives",[]):
			if not primitive is Dictionary or not primitive.get("attributes",{}) is Dictionary: return "Invalid mesh attributes."
	return ""

func reserve_cache(required: int) -> bool:
	var total := 0
	# Persistent libraries are never evicted behind the server operator's back.
	for file_name in DirAccess.get_files_at(CACHE):
		if not file_name.ends_with(".vrm"): continue
		var path := CACHE+file_name
		var file := FileAccess.open(path,FileAccess.READ)
		if not file: continue
		var size := file.get_length()
		total += size
	return total+required<=CACHE_BUDGET
