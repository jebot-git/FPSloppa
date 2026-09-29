extends SceneTree
## Generate dimensioned casing blanks for tools/tribes/wrist_model.py in Blender.
func _initialize():
	for row in [["pda",Vector2(.26,.18)],["camera",Vector2(.26,.14625)]]:
		var node:=MeshInstance3D.new();node.name="WristCase";node.mesh=preload("res://tools/tribes/wrist_geometry.gd").new().build_housing(row[1])
		var document:=GLTFDocument.new();var state:=GLTFState.new()
		assert(document.append_from_scene(node,state)==OK)
		assert(document.write_to_filesystem(state,"res://tools/tribes/wrist-sources/base-"+row[0]+".glb")==OK)
		print("WRIST_BLANK ",row[0]," vertices=",node.mesh.surface_get_array_len(0));node.free()
	quit()
