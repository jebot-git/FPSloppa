extends RefCounted
const Extension=preload("res://addons/vrm/vrm_extension.gd")
static var compile_surfaces:=true # Test tools may isolate the original imported representation.
const Rig=preload("res://deathmatch/avatars/rig.gd")
static func prepare_avatar(library: Node,hash: String,wait:bool=false) -> bool:
	if not library.entries.has(hash): return false
	if library.scenes.has(hash):library.touch_scene(hash);return true
	library.last_error=""
	var compiled:=compile_surfaces and not OS.get_cmdline_user_args().has("--unmerged-avatar-surfaces")
	var cache=library.runtime_cache()
	var cached:Dictionary=cache.request(hash,compiled)
	if cached.status=="pending":
		if not wait:return false
		var packed=cache.finish_sync(hash,compiled)
		if packed:library.disk_scenes[hash]=true;library.remember_scene(hash,packed);return true
	elif cached.status=="ready":
		library.disk_scenes[hash]=true;library.remember_scene(hash,cached.scene);return true
	if not library.scenes.has(hash):
		var gltf := GLTFDocument.new()
		var extensions: Array = [Extension.new(),preload("res://addons/vrm/1.0/VRMC_node_constraint.gd").new(),preload("res://addons/vrm/1.0/VRMC_springBone.gd").new(),preload("res://addons/vrm/1.0/VRMC_materials_mtoon.gd").new(),preload("res://addons/vrm/1.0/VRMC_materials_hdr_emissiveMultiplier.gd").new(),preload("res://addons/vrm/1.0/VRMC_vrm.gd").new()]
		for extension in extensions: GLTFDocument.register_gltf_document_extension(extension,true)
		var state := GLTFState.new()
		state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
		# Keep separate full and head-hidden mesh variants for remote/local views.
		state.set_additional_data("vrm/head_hiding_method",3)
		state.set_additional_data("vrm/first_person_layers",1<<19)
		state.set_additional_data("vrm/third_person_layers",1)
		var error := gltf.append_from_file(library.entries[hash].path,state,8)
		var model: Node3D = gltf.generate_scene(state) if error==OK else null
		for extension in extensions: GLTFDocument.unregister_gltf_document_extension(extension)
		if not model:
			library.last_error = "The VRM plugin could not load this model."
			return false
		if compiled:
			model.set_meta("arena_surface_compile",preload("res://deathmatch/avatars/surface_compiler.gd").compile(model))
		var packed := PackedScene.new()
		# Cache once with the decoded scene, shared by every player using this VRM.
		# Current poses, IK, first-person head hiding and animation never set its size.
		var bounds=preload("res://deathmatch/avatars/rest_bounds.gd")
		model.set_meta(bounds.CACHE_KEY,bounds.measure(model))
		# Prepare mipmaps once before serialization. Reopened scenes then avoid
		# repeating texture readbacks/mipmap generation during rig creation.
		if DisplayServer.get_name()!="headless":preload("res://deathmatch/maps/filtering.gd").new().apply(model)
		var packed_error:=packed.pack(model)
		model.free()
		if packed_error!=OK:library.last_error="Could not prepare the avatar scene.";return false
		cache.stats.misses+=1
		cache.store(hash,compiled,packed)
		library.remember_scene(hash,packed)
	return true
static func create_avatar(library: Node,hash: String) -> Node3D:
	if not prepare_avatar(library,hash,true):return null
	var rig := Rig.new()
	rig.avatar_hash=hash
	rig.name = "VRMAvatar"
	var model = library.scenes[hash].instantiate()
	rig.add_child(model)
	if not model is Node3D or not rig.configure(model):
		rig.free()
		if library.disk_scenes.has(hash):
			library.disk_scenes.erase(hash);library.scenes.erase(hash)
			library.runtime_cache().reject(hash,compile_surfaces and not OS.get_cmdline_user_args().has("--unmerged-avatar-surfaces"))
			return create_avatar(library,hash)
		library.last_error = "Humanoid skeleton could not be normalized."
		return null
	if DisplayServer.get_name()!="headless":preload("res://deathmatch/maps/filtering.gd").new().apply(rig)
	library.track_instance(hash,rig)
	return rig
