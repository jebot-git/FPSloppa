extends RefCounted
# Converted AD brushwork is static. Batch opaque baked surfaces; keep collisions
# and entity nodes intact and discard only zero-area imported triangles.
static func apply(root: Node3D) -> void:
	var buckets: Dictionary={}
	var stack: Array=[[root,Transform3D.IDENTITY]]
	var removed:=0
	while not stack.is_empty():
		var pair: Array=stack.pop_back();var node: Node=pair[0];var transform: Transform3D=pair[1]
		if node!=root and node is Node3D:transform=transform*node.transform
		for child in node.get_children():stack.append([child,transform])
		if not node is MeshInstance3D or not node.mesh:continue
		var handled:=true
		for surface in node.mesh.get_surface_count():
			var material=node.get_active_material(surface)
			if not material is ShaderMaterial or material.shader!=preload("res://deathmatch/maps/baked_light.gdshader"):handled=false;break
		if not handled:
			var cleaned:=ArrayMesh.new()
			for surface in node.mesh.get_surface_count():
				var arrays: Array=node.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var old: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				if old.is_empty():
					for i in vertices.size():old.append(i)
				var indices:=PackedInt32Array()
				for at in range(0,old.size(),3):
					var a:=vertices[old[at]];var b:=vertices[old[at+1]];var c:=vertices[old[at+2]]
					if (b-a).cross(c-a).length_squared()<1e-8:removed+=1;continue
					indices.append_array(old.slice(at,at+3))
				if indices.is_empty():continue
				arrays[Mesh.ARRAY_INDEX]=indices
				cleaned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				cleaned.surface_set_material(cleaned.get_surface_count()-1,node.get_active_material(surface))
			node.mesh=cleaned if cleaned.get_surface_count()>0 else null
			continue
		for surface in node.mesh.get_surface_count():
			var material: ShaderMaterial=node.get_active_material(surface)
			var texture: Texture2D=material.get_shader_parameter("base_texture")
			var key: int=texture.get_instance_id() if texture else material.get_instance_id()
			if not buckets.has(key):
				var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(material);buckets[key]=tool
			var tool: SurfaceTool=buckets[key]
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var uv2: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for i in vertices.size():indices.append(i)
			for at in range(0,indices.size(),3):
				var a:=transform*vertices[indices[at]];var b:=transform*vertices[indices[at+1]];var c:=transform*vertices[indices[at+2]]
				if not a.is_finite() or not b.is_finite() or not c.is_finite() or (b-a).cross(c-a).length_squared()<1e-8 or a.distance_squared_to(b)<1e-8 or b.distance_squared_to(c)<1e-8 or c.distance_squared_to(a)<1e-8:removed+=1;continue
				for j in 3:
					var i:=indices[at+j]
					tool.set_normal((transform.basis.inverse().transposed()*normals[i]).normalized())
					tool.set_uv(uv[i]);tool.set_uv2(uv2[i]);tool.add_vertex(transform*vertices[i])
		node.mesh=null
	for tool: SurfaceTool in buckets.values():
		var mesh:=tool.commit()
		if not mesh or mesh.get_surface_count()==0:continue
		# Drop sub-millimetre slivers that collapse during engine triangle welding.
		var arrays:=mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var old_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if old_indices.is_empty():
			for i in vertices.size():old_indices.append(i)
		var indices:=PackedInt32Array()
		for at in range(0,old_indices.size(),3):
			var a:=vertices[old_indices[at]];var b:=vertices[old_indices[at+1]];var c:=vertices[old_indices[at+2]]
			if (b-a).cross(c-a).length_squared()<1e-8 or a.distance_squared_to(b)<1e-8 or b.distance_squared_to(c)<1e-8 or c.distance_squared_to(a)<1e-8:removed+=1;continue
			indices.append_array(old_indices.slice(at,at+3))
		if indices.is_empty():continue
		arrays[Mesh.ARRAY_INDEX]=indices
		var material:=mesh.surface_get_material(0)
		mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE);mesh.surface_set_material(0,material)
		var node:=MeshInstance3D.new();node.name="StaticBatch";node.mesh=mesh;root.add_child(node,true);node.owner=root
	root.set_meta("discarded_degenerate_triangles",removed)
