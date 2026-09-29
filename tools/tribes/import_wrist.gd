extends SceneTree
## Bake Blender casings to engine-native scenes; runtime never imports GLB files.
func _initialize():
	for kind in ["pda","camera"]:
		var path: String="res://deathmatch/tribes/wrist/"+kind
		var document:=GLTFDocument.new();var state:=GLTFState.new()
		assert(document.append_from_file(path+".glb",state)==OK)
		var scene:=document.generate_scene(state);var packed:=PackedScene.new()
		# The casing palette is authored in sRGB vertex colours. GLTFDocument's
		# direct import does not enable them on the generated material by itself.
		for node in scene.find_children("*","MeshInstance3D",true,false):
			node.name="Mount" if str(node.name).ends_with("_Mount") else "Case"
			for i in node.mesh.get_surface_count():
				var material=node.mesh.surface_get_material(i)
				material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true
		assert(packed.pack(scene)==OK);assert(ResourceSaver.save(packed,path+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
		print("ST_WRIST_IMPORTED ",kind);scene.free()
	quit()
