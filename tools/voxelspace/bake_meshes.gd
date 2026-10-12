extends SceneTree
const IO=preload("res://addons/openscad_import/mesh_io.gd")
func _initialize() -> void:
	var boxes:=IO.palette("res://tools/voxelspace/assets/factory.palette.json")
	var rows: Array=[]
	for variant in ["blender_planar","blender_lod1","blender_lod2","greedy","culled","medium","proxy"]:
		var mesh:=IO.read_json("res://test-results/factory-optimization/factory_"+variant+".json",boxes)
		ResourceSaver.save(mesh,"res://tools/voxelspace/assets/factory_"+variant+".res")
		rows.append({"variant":variant,"triangles":mesh.surface_get_array_index_len(0)/3,"vertices":mesh.surface_get_array_len(0)})
	print("BAKED_MESHES ",JSON.stringify(rows));quit()
