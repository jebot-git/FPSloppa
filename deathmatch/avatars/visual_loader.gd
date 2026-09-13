extends RefCounted
const Extension=preload("res://addons/vrm/vrm_extension.gd")
const Rig=preload("res://deathmatch/avatars/rig.gd")
static func create_avatar(library: Node,hash: String) -> Node3D:
	if not library.entries.has(hash): return null
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
			return null
		var packed := PackedScene.new()
		# Cache once with the decoded scene, shared by every player using this VRM.
		# Current poses, IK, first-person head hiding and animation never set its size.
		var bounds=preload("res://deathmatch/avatars/rest_bounds.gd")
		model.set_meta(bounds.CACHE_KEY,bounds.measure(model))
		packed.pack(model)
		model.free()
		# Keep only a few decoded models; original files remain available on disk.
		if library.scenes.size()>=4: library.scenes.erase(library.scenes.keys()[0])
		library.scenes[hash] = packed
	var rig := Rig.new()
	rig.name = "VRMAvatar"
	var model: Node3D = library.scenes[hash].instantiate()
	rig.add_child(model)
	if not rig.configure(model):
		rig.free()
		library.last_error = "Humanoid skeleton could not be normalized."
		return null
	if DisplayServer.get_name()!="headless":preload("res://deathmatch/maps/filtering.gd").new().apply(rig)
	return rig

