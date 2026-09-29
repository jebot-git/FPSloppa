extends SceneTree
func _initialize():
	for kind in ["lpc","hpc"]:
		var doc:=GLTFDocument.new();var state:=GLTFState.new()
		assert(doc.append_from_file("res://deathmatch/vehicles/tribes/"+kind+".glb",state)==OK)
		var scene:=doc.generate_scene(state)
		preload("res://deathmatch/maps/filtering.gd").new().apply(scene,2,true)
		var packed:=PackedScene.new();assert(packed.pack(scene)==OK)
		assert(ResourceSaver.save(packed,"res://deathmatch/vehicles/tribes/"+kind+".scn",ResourceSaver.FLAG_COMPRESS)==OK);scene.free()
		var icon:=Image.new();assert(icon.load_svg_from_string(FileAccess.get_file_as_string("res://deathmatch/ui/weapon_icons/st_"+kind+".svg"))==OK);icon.generate_mipmaps()
		assert(ResourceSaver.save(ImageTexture.create_from_image(icon),"res://deathmatch/vehicles/tribes/"+kind+"-icon.res",ResourceSaver.FLAG_COMPRESS)==OK)
	print("TRANSPORT_IMPORT_PASS");quit()
