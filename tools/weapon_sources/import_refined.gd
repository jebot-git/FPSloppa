extends SceneTree
func _initialize():
	var kinds: Array=Array(OS.get_cmdline_user_args())
	if kinds.is_empty():kinds=["axe","impact_hammer","barrel_sleeve","scope_housing","tf_flamethrower","sniper","sentry_gatling"]
	for kind in kinds:
		var doc:=GLTFDocument.new();var state:=GLTFState.new()
		assert(doc.append_from_file("res://tools/weapon_sources/refined/"+kind+".glb",state)==OK)
		var node:=doc.generate_scene(state);var scene:=PackedScene.new()
		if kind=="axe":
			var alignment: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/weapon_sources/refined/axe-alignment.json"))
			var edge: Array=alignment.cutting_edge
			node.set_meta("cutting_edge",Vector3(edge[0],edge[1],edge[2]));node.set_meta("grip",Vector3.ZERO)
		mipmaps(node)
		assert(scene.pack(node)==OK)
		assert(ResourceSaver.save(scene,"res://deathmatch/weapons/experimental/"+kind+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
		node.free()
	print("REFINED_IMPORT_OK");quit()

func mipmaps(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat=node.get_active_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture:
				var img: Image=mat.albedo_texture.get_image()
				if not img.has_mipmaps():img.generate_mipmaps();mat.albedo_texture=ImageTexture.create_from_image(img)
				mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for child in node.get_children():mipmaps(child)
