extends RefCounted
## Contact comes from the visible index finger, not the controller's aim ray.
## Cache an authored tip bone or the distal skin's end once per hand/model.
var tips: Dictionary={}
var glove_side:=""
func resolve(model: Node,sk: Skeleton3D,left: bool) -> Dictionary:
	var key: String=str(sk.get_instance_id())+str(left)
	if tips.has(key):return tips[key]
	var side:="Left" if left else "Right"
	var bone:=sk.find_bone("Index_Tip_"+("L" if left else "R"))
	var offset:=Vector3.ZERO
	if bone<0:
		bone=sk.find_bone(side+"IndexDistal")
		var previous:=sk.find_bone(side+"IndexIntermediate")
		if bone<0 or previous<0:return {}
		var rest:=sk.get_bone_global_rest(bone)
		var direction:=rest.basis.inverse()*(rest.origin-sk.get_bone_global_rest(previous).origin).normalized()
		direction=direction.normalized()
		var vertices: Array[Vector3]=[]
		var furthest:=0.0
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			if not mesh.skin or not mesh.mesh is ArrayMesh:continue
			var binds: Dictionary={}
			for b in mesh.skin.get_bind_count():
				var target: int=sk.find_bone(mesh.skin.get_bind_name(b)) if mesh.skin.get_bind_name(b)!=&"" else mesh.skin.get_bind_bone(b)
				if target==bone:binds[b]=mesh.skin.get_bind_pose(b)
			if binds.is_empty():continue
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
				if indices==null or weights==null or points.is_empty():continue
				var stride: int=indices.size()/points.size()
				for v in points.size():
					for b in stride:
						if weights[v*stride+b]>=.4 and binds.has(indices[v*stride+b]):
							var point: Vector3=binds[indices[v*stride+b]]*points[v]
							vertices.append(point);furthest=maxf(furthest,point.dot(direction))
			if vertices.size()>4096:break
		var count:=0
		for point in vertices:
			if point.dot(direction)>=furthest-.002:offset+=point;count+=1
		if count>0:offset/=count
		else:offset=direction*rest.origin.distance_to(sk.get_bone_global_rest(previous).origin)*.7
	if tips.size()>64:tips.clear()
	tips[key]={"bone":bone,"offset":offset}
	return tips[key]
func world_tip(model: Node,sk: Skeleton3D,left: bool) -> Vector3:
	var tip:=resolve(model,sk,left)
	return sk.global_transform*(sk.get_bone_global_pose(tip.bone)*tip.offset) if not tip.is_empty() else Vector3.INF
func sample(rig: Node,pose: Dictionary) -> Vector3:
	glove_side=""
	var de=rig.game.match_mode.defusal;var mine: int=rig.game.multiplayer.get_unique_id()
	if not de.enabled() or not pose.has("offhand_weapon") or not (de.carrier==mine and de.held or de.planted and de.role(mine)==1):return Vector3.INF
	var left: bool=not rig.left_handed;var side:="left" if left else "right"
	var controller: XRController3D=rig.get(side)
	var actor=rig.game.fighters.get(mine)
	var point:=Vector3.INF
	if actor and actor.local_body_visible and is_instance_valid(actor.avatar) and actor.avatar.get("skeleton") is Skeleton3D:
		var avatar=actor.avatar;var previous: Dictionary=avatar.xr_pose
		if previous.has(side):
			point=world_tip(avatar,avatar.skeleton,left)
			# Carry the last evaluated finger pose with the current controller, so
			# skeletal update ordering does not add a frame of positional lag.
			var prior: Transform3D=avatar.tracking_transform()*previous[side]
			point=controller.global_transform*(prior.affine_inverse()*point)
	if not point.is_finite() and rig.hand_animators.size()==2:
		var i:=0 if left else 1
		# XR Tools moves its top-level glove on physics ticks. Bring it to the
		# current palm before reading/depicting a precise fingertip contact.
		rig.hand_models[i]._physics_process(0.0)
		point=world_tip(rig.hand_models[i],rig.hand_animators[i].get_skeleton(),left)
		glove_side=side
	if not point.is_finite():return Vector3.INF
	point=rig.global_transform.affine_inverse()*point
	return point if point.distance_to(pose[side].origin)<=.25 else Vector3.INF

func present(rig: Node,actor: Node):
	var side: String=glove_side if actor.local_body_visible else ""
	if is_instance_valid(actor.avatar) and actor.avatar.has_method("set_keypad_glove"):actor.avatar.set_keypad_glove(side)
	for i in rig.hand_models.size():rig.hand_models[i].visible=not actor.local_body_visible or side==("left" if i==0 else "right")
