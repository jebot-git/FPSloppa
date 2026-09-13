extends RefCounted
## Measure the skinned rest pose, not the pre-skin vertex coordinates.
## Runs once per decoded model; never depends on the current IK/crouch pose.
const CACHE_KEY:="arena_rest_bounds_v1"

static func measure(root: Node3D) -> AABB:
	var transforms:Dictionary={}
	collect(root,Transform3D.IDENTITY,transforms)
	var result:=AABB()
	for node in transforms:
		if not node is MeshInstance3D or not node.mesh:continue
		var bounds:=mesh_bounds(node,transforms)
		if bounds.size.length_squared()>0:result=bounds if result.size.length_squared()==0 else result.merge(bounds)
	return result

static func collect(node: Node3D, transform_here: Transform3D, transforms: Dictionary) -> void:
	transforms[node]=transform_here
	for child in node.get_children():
		if child is Node3D:collect(child,transform_here*child.transform,transforms)

static func mesh_bounds(node: MeshInstance3D, transforms: Dictionary) -> AABB:
	var mesh_transform:Transform3D=transforms[node]
	var skin:Skin=node.skin
	var sk:Skeleton3D=node.get_node_or_null(node.skeleton) as Skeleton3D if not node.skeleton.is_empty() else null
	if not skin or not sk or not transforms.has(sk):return mesh_transform*node.get_aabb()
	var palette:Array[Transform3D]=[]
	for bind in skin.get_bind_count():
		var name_here:=skin.get_bind_name(bind)
		var bone:=sk.find_bone(name_here) if not name_here.is_empty() else skin.get_bind_bone(bind)
		if bone<0 or bone>=sk.get_bone_count():return AABB()
		palette.append(sk.get_bone_global_rest(bone)*skin.get_bind_pose(bind))
	var sk_transform:Transform3D=transforms[sk]
	var minimum:=Vector3(INF,INF,INF)
	var maximum:=Vector3(-INF,-INF,-INF)
	for surface in node.mesh.get_surface_count():
		var arrays:=node.mesh.surface_get_arrays(surface)
		if arrays.is_empty() or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:continue
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones=arrays[Mesh.ARRAY_BONES]
		var weights=arrays[Mesh.ARRAY_WEIGHTS]
		var skinned:bool=bones is PackedInt32Array and weights is PackedFloat32Array and not vertices.is_empty()
		var count:int=bones.size()/vertices.size() if skinned else 0
		if skinned and (count not in [4,8] or bones.size()!=vertices.size()*count or weights.size()!=bones.size()):return AABB()
		for index in vertices.size():
			var vertex:=vertices[index]
			var point:Vector3=mesh_transform*vertex
			if skinned:
				var posed:=vertex
				for influence in count:
					var offset:=index*count+influence
					var weight:float=weights[offset]
					if weight<=0:continue
					var bind:int=bones[offset]
					if bind<0 or bind>=palette.size() or not is_finite(weight):return AABB()
					posed+=(palette[bind]*vertex-vertex)*weight
				point=sk_transform*posed
			if not point.is_finite():return AABB()
			minimum=minimum.min(point);maximum=maximum.max(point)
	return AABB(minimum,maximum-minimum) if minimum.is_finite() else AABB()
