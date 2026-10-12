extends SceneTree
const IO=preload("res://addons/openscad_import/mesh_io.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var boxes:=IO.palette("res://tools/voxelspace/assets/factory.palette.json")
	var combiner:=CSGCombiner3D.new();combiner.calculate_tangents=false;root.add_child(combiner)
	var start:=Time.get_ticks_usec()
	for item in boxes:
		var shape:=CSGBox3D.new();shape.size=Vector3(item[1][0],item[1][1],item[1][2]);shape.position=Vector3(item[0][0],item[0][1],item[0][2]);combiner.add_child(shape)
	await process_frame;await process_frame
	var native:=combiner.bake_static_mesh()
	var source_triangles:=0;var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
	for s in native.get_surface_count():
		var arrays:=native.surface_get_arrays(s);var offset:=vertices.size();vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
		var source_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else []
		if source_indices.is_empty():
			for i in arrays[Mesh.ARRAY_VERTEX].size():indices.append(offset+i)
		else:
			for i in source_indices:indices.append(offset+i)
		# Native CSG uses Godot's clockwise winding. Normalize to the outward
		# normals used by the OpenSCAD reader before baking face colors.
		var source_vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var base_index:=indices.size()-(source_indices.size() if not source_indices.is_empty() else source_vertices.size())
		for i in range(base_index,indices.size(),3):
			var a:=indices[i]-offset;var b:=indices[i+1]-offset;var c:=indices[i+2]-offset
			if (source_vertices[b]-source_vertices[a]).cross(source_vertices[c]-source_vertices[a]).dot(source_normals[a])<0:
				var old:=indices[i+1];indices[i+1]=indices[i+2];indices[i+2]=old
		source_triangles+=arrays[Mesh.ARRAY_VERTEX].size()/3 if source_indices.is_empty() else source_indices.size()/3
	var mesh:=IO.from_triangles(vertices,indices,boxes)
	ResourceSaver.save(mesh,"res://tools/voxelspace/assets/factory_native_csg.res")
	var report:={"native_csg_triangles":source_triangles,"native_csg_surfaces":native.get_surface_count(),"static_draw_surfaces":mesh.get_surface_count(),"native_bake_ms":(Time.get_ticks_usec()-start)/1000.0}
	combiner.free()
	var open_scad:=IO.read_off("res://test-results/factory-optimization/factory-union.off",boxes)
	ResourceSaver.save(open_scad,"res://tools/voxelspace/assets/factory_openscad.res")
	report.openscad_triangles=open_scad.surface_get_array_index_len(0)/3
	FileAccess.open("res://test-results/factory-optimization/csg-bake.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CSG_BAKE ",JSON.stringify(report));await process_frame;quit()
