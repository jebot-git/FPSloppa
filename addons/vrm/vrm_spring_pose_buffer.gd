extends RefCounted
## A spring step reads a stable body pose. Resolve spring parent transforms here
## instead of forcing Skeleton3D to propagate its dirty hierarchy after every joint.
var skeleton: Skeleton3D
var parents:=PackedInt32Array()
var children: Array=[]
var local_poses: Array[Transform3D]=[]
var global_poses: Array[Transform3D]=[]
var valid:=PackedByteArray()
var relevant: Array[int]=[]
func setup(sk: Skeleton3D,springs: Array) -> void:
	skeleton=sk
	var count:=sk.get_bone_count()
	parents.resize(count);children.resize(count);local_poses.resize(count);global_poses.resize(count);valid.resize(count)
	for i in count:parents[i]=sk.get_bone_parent(i);children[i]=[]
	relevant.clear()
	for spring in springs:
		for verlet in spring.verlets:
			var index: int=verlet.bone_idx
			while index>=0 and not index in relevant:
				relevant.append(index);index=parents[index]
	for i in relevant:
		if parents[i]>=0:children[parents[i]].append(i)
func begin() -> void:
	valid.fill(0)
	for i in relevant:local_poses[i]=skeleton.get_bone_pose(i)
func global_pose(index: int) -> Transform3D:
	if index<0:return Transform3D.IDENTITY
	if not valid[index]:
		global_poses[index]=global_pose(parents[index])*local_poses[index]
		valid[index]=1
	return global_poses[index]
func invalidate(index: int) -> void:
	valid[index]=0
	for child in children[index]:invalidate(child)
func set_global_pose(index: int,pose: Transform3D) -> void:
	var local:=global_pose(parents[index]).affine_inverse()*pose
	local_poses[index]=local
	invalidate(index)
	global_poses[index]=pose;valid[index]=1
	# Same decomposition as Skeleton3D.set_bone_global_pose, but no global read.
	skeleton.set_bone_pose(index,local)
