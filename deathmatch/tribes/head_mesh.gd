extends RefCounted
## Retain the original face, neck, hair and usable hands, including blend shapes.
static var cache: Dictionary={}
static func head_bone(sk: Skeleton3D,bone: int,hands: Array=[]) -> bool:
	while bone>=0:
		if sk.get_bone_name(bone) in ["Head","Neck"] or sk.get_bone_name(bone) in hands:return true
		bone=sk.get_bone_parent(bone)
	return false
static func has_hand(mesh: Mesh,skin: Skin,sk: Skeleton3D,hand: String) -> bool:
	if not mesh is ArrayMesh or not skin:return false
	var binds: Dictionary={}
	for i in skin.get_bind_count():
		var bone:=sk.find_bone(skin.get_bind_name(i)) if skin.get_bind_name(i)!=&"" else skin.get_bind_bone(i)
		while bone>=0:
			if sk.get_bone_name(bone)==hand:binds[i]=true;break
			bone=sk.get_bone_parent(bone)
	for surface in mesh.get_surface_count():
		var a:=mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var bones=a[Mesh.ARRAY_BONES];var weights=a[Mesh.ARRAY_WEIGHTS]
		if bones==null or weights==null or bones.is_empty():continue
		var allowed:=PackedByteArray();allowed.resize(vertices.size());var stride: int=bones.size()/vertices.size()
		for v in vertices.size():
			var weight:=0.0
			for j in stride:
				if binds.has(bones[v*stride+j]):weight+=weights[v*stride+j]
			allowed[v]=int(weight>.15)
		var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(vertices.size()))
		for i in range(0,indices.size()-2,3):
			if allowed[indices[i]] and allowed[indices[i+1]] and allowed[indices[i+2]]:return true
	return false
static func keep(mesh: Mesh,skin: Skin,sk: Skeleton3D,hands: Array=[]) -> Mesh:
	if not mesh is ArrayMesh or not skin or not sk:return null
	var key:=str(mesh.get_instance_id())+":"+str(skin.get_instance_id())+":"+str(hands)
	if cache.has(key):return cache[key]
	var kept: Dictionary={}
	for i in skin.get_bind_count():
		var b:=sk.find_bone(skin.get_bind_name(i)) if skin.get_bind_name(i)!=&"" else skin.get_bind_bone(i)
		if b>=0 and b<sk.get_bone_count() and head_bone(sk,b,hands):kept[i]=true
	var out:=ArrayMesh.new();out.blend_shape_mode=mesh.blend_shape_mode
	for i in mesh.get_blend_shape_count():out.add_blend_shape(mesh.get_blend_shape_name(i))
	var mapping: Array[int]=[]
	for surface in mesh.get_surface_count():
		var arrays: Array=mesh.surface_get_arrays(surface).duplicate()
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
		if bones==null or weights==null or bones.is_empty() or mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:continue
		var allowed:=PackedByteArray();allowed.resize(vertices.size());var stride: int=bones.size()/vertices.size()
		for v in vertices.size():
			var weight:=0.0
			for j in stride:
				if kept.has(bones[v*stride+j]):weight+=weights[v*stride+j]
			allowed[v]=1 if weight>.15 else 0
		var source: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(vertices.size()))
		var indices:=PackedInt32Array()
		for i in range(0,source.size()-2,3):
			if allowed[source[i]] and allowed[source[i+1]] and allowed[source[i+2]]:indices.append_array(source.slice(i,i+3))
		if indices.is_empty():continue
		arrays[Mesh.ARRAY_INDEX]=indices
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,mesh.surface_get_blend_shape_arrays(surface),{},mesh.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(out.get_surface_count()-1,mesh.surface_get_material(surface));mapping.append(surface)
	out.set_meta("full_body_surfaces",mapping)
	var result: Mesh=out if out.get_surface_count()>0 else null
	cache[key]=result;return result
