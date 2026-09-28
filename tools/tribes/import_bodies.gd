extends SceneTree
var textures: Dictionary={}
func _initialize():
	var extension=preload("res://addons/vrm/vrm_extension.gd").new();GLTFDocument.register_gltf_document_extension(extension,true)
	for key in (["light","medium","heavy"] if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()):
		assert(key in ["light","medium","heavy"])
		var doc:=GLTFDocument.new();var state:=GLTFState.new();state.set_additional_data("vrm/head_hiding_method",0)
		assert(doc.append_from_file("res://tools/tribes/refined/body_"+key+".vrm",state)==OK)
		var node=doc.generate_scene(state);assert(node!=null);finish(node)
		node.set_meta("asset_sources","res://deathmatch/weapons/tribes/SOURCES.md")
		node.set_meta("undersuit_author","KEIV")
		node.set_meta("undersuit_license","VRoid Hub: attribution required; non-commercial; see SOURCES.md")
		var packed:=PackedScene.new();assert(packed.pack(node)==OK);assert(ResourceSaver.save(packed,"res://deathmatch/weapons/tribes/body_"+key+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
		print("VRM_BODY_IMPORTED ",key);node.free()
	GLTFDocument.unregister_gltf_document_extension(extension);quit()

func finish(node: Node):
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat=node.get_active_material(i)
			if not mat is StandardMaterial3D:continue
			if mat.albedo_texture:
				var key: String="armour-suit" if mat.resource_name.begins_with("MEC-VAL") else "armour-finish"
				if not textures.has(key):
					var img: Image=mat.albedo_texture.get_image()
					assert(img.generate_mipmaps()==OK)
					var path:="res://deathmatch/weapons/tribes/"+key+".res"
					var existing=load(path) if ResourceLoader.exists(path) else null
					if existing is ImageTexture and existing.get_image().get_data()==img.get_data():
						textures[key]=existing
					else:
						var texture:=ImageTexture.create_from_image(img)
						assert(ResourceSaver.save(texture,path,ResourceSaver.FLAG_COMPRESS)==OK)
						texture.take_over_path(path);textures[key]=texture
				mat.albedo_texture=textures[key]
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			mat.cull_mode=BaseMaterial3D.CULL_BACK
	for child in node.get_children():finish(child)
