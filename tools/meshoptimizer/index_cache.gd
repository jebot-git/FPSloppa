extends RefCounted
## Experimental post-decode index-only optimization. Godot's SurfaceTool calls
## its built-in meshoptimizer. No vertex, skin, morph or LOD remapping is needed.
const Materials=preload("res://deathmatch/avatars/surface_compiler.gd")
static func optimize(source: ArrayMesh) -> ArrayMesh:
	var surfaces: Array=source.get("_surfaces").duplicate(true);var changed:=false
	for surface in source.get_surface_count():
		if source.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES or not Materials.safe_material(source.surface_get_material(surface)):continue
		var row: Dictionary=surfaces[surface];var count: int=row.get("index_count",0)
		if count==0:continue
		var stride: int=row.index_data.size()/count
		if stride not in [2,4]:continue
		var tool:=SurfaceTool.new();tool.create_from(source,surface);tool.optimize_indices_for_cache()
		var indices: PackedInt32Array=tool.commit_to_arrays()[Mesh.ARRAY_INDEX]
		var bytes:=PackedByteArray();bytes.resize(count*stride)
		for i in count:
			if stride==2:bytes.encode_u16(i*2,indices[i])
			else:bytes.encode_u32(i*4,indices[i])
		changed=changed or bytes!=row.index_data;row.index_data=bytes
	if not changed:return source
	var result: ArrayMesh=source.duplicate();result.set("_surfaces",surfaces);return result
static func model(root: Node) -> Dictionary:
	var meshes: Dictionary={};var changed:=0
	for instance in root.find_children("*","MeshInstance3D",true,false):
		if not instance.mesh is ArrayMesh:continue
		if not meshes.has(instance.mesh):meshes[instance.mesh]=optimize(instance.mesh)
		var result=meshes[instance.mesh]
		if result!=instance.mesh:changed+=1;instance.mesh=result
	return {"unique_meshes":meshes.size(),"changed_instances":changed}
