extends SceneTree
func _initialize():
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	assert(doc.append_from_file("res://tools/cs16/pouch/magazine_pouch.glb",state)==OK)
	var node:=doc.generate_scene(state)
	finish(node)
	var scene:=PackedScene.new();assert(scene.pack(node)==OK)
	assert(ResourceSaver.save(scene,"res://deathmatch/weapons/cs16/magazine_pouch.scn",ResourceSaver.FLAG_COMPRESS)==OK)
	node.free();print("POUCH_IMPORTED");quit()
func finish(node: Node):
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat=node.get_active_material(i) as StandardMaterial3D
			if not mat:continue
			if mat.albedo_texture:
				var img: Image=mat.albedo_texture.get_image();img.generate_mipmaps();mat.albedo_texture=ImageTexture.create_from_image(img)
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mat.cull_mode=BaseMaterial3D.CULL_BACK
	for child in node.get_children():finish(child)
