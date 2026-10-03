extends RefCounted
## Strip torso/head triangles from the local mesh, preserving arms, legs,
## materials and blend shapes. Never mutate the shared third-person resource.
static var cache: Dictionary={}
static func hidden_bone(sk: Skeleton3D,bone: int,hand: String="",shoulders: bool=false) -> bool:
	while bone>=0:
		var name: String=sk.get_bone_name(bone)
		if not hand.is_empty() and name==hand.capitalize()+"Hand":return true
		if shoulders and name in ["LeftShoulder","RightShoulder"]:return true
		if name in ["LeftShoulder","RightShoulder","LeftUpperArm","RightUpperArm"]:return false
		if name in ["Spine","Chest","UpperChest","Neck","Head"]:return true
		bone=sk.get_bone_parent(bone)
	return false
static func masked(mesh: Mesh,skin: Skin,sk: Skeleton3D,hand: String="",shoulders: bool=false) -> Mesh:
	if not skin or not sk or not mesh is ArrayMesh:return mesh
	var key:=str(mesh.get_instance_id())+":"+str(skin.get_instance_id())+":"+hand+":"+str(shoulders)
	if cache.has(key):return cache[key]
	var hidden: Dictionary={}
	var upper_arms: Dictionary={}
	for i in skin.get_bind_count():
		var bone:=sk.find_bone(skin.get_bind_name(i)) if skin.get_bind_name(i)!=&"" else skin.get_bind_bone(i)
		if bone<0 or bone>=sk.get_bone_count():continue
		if hidden_bone(sk,bone,hand,shoulders):hidden[i]=true
		var name: String=sk.get_bone_name(bone)
		if shoulders and name in ["LeftUpperArm","RightUpperArm"]:
			var elbow:=sk.find_bone(name.replace("UpperArm","LowerArm"))
			if elbow<0:continue
			var start:=sk.get_bone_global_rest(bone).origin
			var axis:=sk.get_bone_global_rest(elbow).origin-start
			if axis.length_squared()>.0001:upper_arms[i]={"start":start,"axis":axis/axis.length_squared()}
	if hidden.is_empty() and upper_arms.is_empty():cache[key]=mesh;return mesh
	var out:=ArrayMesh.new();out.blend_shape_mode=mesh.blend_shape_mode
	var surfaces: Array[int]=[]
	for i in mesh.get_blend_shape_count():out.add_blend_shape(mesh.get_blend_shape_name(i))
	for surface in mesh.get_surface_count():
		var arrays: Array=mesh.surface_get_arrays(surface).duplicate()
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
		if bones!=null and weights!=null and not bones.is_empty() and mesh.surface_get_primitive_type(surface)==Mesh.PRIMITIVE_TRIANGLES:
			var rejected:=PackedByteArray();rejected.resize(vertices.size())
			var stride: int=bones.size()/vertices.size()
			for v in vertices.size():
				var weight:=0.0
				for j in stride:
					var bind: int=bones[v*stride+j]
					if hidden.has(bind):weight+=weights[v*stride+j]
					elif upper_arms.has(bind):
						# Heavy pauldrons follow the proximal upper arm as well as
						# the shoulder. Measure in rest space so VRM scaling works.
						var arm: Dictionary=upper_arms[bind]
						if (vertices[v]-arm.start).dot(arm.axis)<.8:weight+=weights[v*stride+j]
				rejected[v]=1 if weight>.05 else 0
			var source: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if source.is_empty():source=PackedInt32Array(range(vertices.size()))
			var indices:=PackedInt32Array()
			for i in range(0,source.size()-2,3):
				if not rejected[source[i]] and not rejected[source[i+1]] and not rejected[source[i+2]]:
					indices.append(source[i]);indices.append(source[i+1]);indices.append(source[i+2])
			if indices.is_empty():continue
			arrays[Mesh.ARRAY_INDEX]=indices
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(surface),arrays,mesh.surface_get_blend_shape_arrays(surface),{},mesh.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(out.get_surface_count()-1,mesh.surface_get_material(surface))
		var source_surfaces: Array=mesh.get_meta("full_body_surfaces",[])
		surfaces.append(source_surfaces[surface] if not source_surfaces.is_empty() else surface)
	out.set_meta("full_body_surfaces",surfaces)
	var result: Mesh=out if out.get_surface_count()>0 else null
	cache[key]=result
	return result
static func apply(node: MeshInstance3D,sk: Skeleton3D,enabled: bool,hand: String=""):
	if not node.has_meta("full_body_mesh"):
		node.set_meta("full_body_mesh",node.mesh)
		var materials: Array[Material]=[]
		for i in node.get_surface_override_material_count():materials.append(node.get_surface_override_material(i))
		node.set_meta("full_body_overrides",materials)
	var source_mesh: Mesh=node.get_meta("full_body_mesh")
	var head_only: bool=node.get_meta("tribes_head_only",false)
	if head_only:source_mesh=preload("res://deathmatch/tribes/head_mesh.gd").keep(source_mesh,node.skin,sk,node.get_meta("tribes_original_hands",[]))
	if not source_mesh:node.hide();return
	if enabled:
		var replacement:=masked(source_mesh,node.skin,sk,hand,node.get_meta("first_person_hide_shoulders",false))
		if replacement:node.mesh=replacement
		else:node.hide();return
	else:node.mesh=source_mesh
	var originals: Array=node.get_meta("full_body_overrides")
	var mapping: Array=node.mesh.get_meta("full_body_surfaces",[]) if node.mesh else []
	for i in node.get_surface_override_material_count():
		var source: int=mapping[i] if (enabled or head_only) and not mapping.is_empty() else i
		node.set_surface_override_material(i,originals[source] if source<originals.size() else null)
