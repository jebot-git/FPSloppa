extends SceneTree
const DIRECTORY="res://deathmatch/tribes/props/"
var texture: ImageTexture
func _initialize():
	var image:=Image.load_from_file("res://deathmatch/vehicles/tribes/hull-atlas.png");image.generate_mipmaps();texture=ImageTexture.create_from_image(image)
	assert(ResourceSaver.save(texture,DIRECTORY+"finish.res",ResourceSaver.FLAG_COMPRESS)==OK);texture.take_over_path(DIRECTORY+"finish.res")
	var count:=0
	for file in DirAccess.get_files_at(DIRECTORY):
		if not file.ends_with(".glb"):continue
		var doc:=GLTFDocument.new();var state:=GLTFState.new();assert(doc.append_from_file(DIRECTORY+file,state)==OK)
		var imported=doc.generate_scene(state);var scene:=Node3D.new();scene.name=file.get_basename()
		for node in imported.find_children("*","Node3D",true,false):
			if not str(node.name).ends_with("_Body") and not str(node.name).ends_with("_Head"):continue
			clear_owners(node);node.get_parent().remove_child(node);scene.add_child(node);node.name="Head" if str(node.name).ends_with("_Head") else "Body"
			finish(node,scene)
		assert(scene.has_node("Body"));imported.free()
		var packed:=PackedScene.new();assert(packed.pack(scene)==OK);assert(ResourceSaver.save(packed,DIRECTORY+file.get_basename()+".scn",ResourceSaver.FLAG_COMPRESS)==OK);scene.free();count+=1
	print("ST_PROPS_IMPORTED ",count);quit()
func finish(node: Node,owner: Node):
	node.owner=owner
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat=node.mesh.surface_get_material(i)
			if mat.albedo_texture:mat.albedo_texture=texture
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for child in node.get_children():finish(child,owner)

func clear_owners(node: Node):
	node.owner=null
	for child in node.get_children():clear_owners(child)
