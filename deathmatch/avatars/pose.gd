extends SkeletonModifier3D
## Analytical two-bone IK. Targets are in arena metres, solved in skeleton space.
var rig
var rest: Dictionary = {}
var bone_ids: Dictionary={}
var floor_tick:=0.0
var solve_tick:=0.0
var cached_poses: Dictionary={}
var floor_heights: Dictionary={}
func bone(sk: Skeleton3D, name_here: String) -> int:
	if not bone_ids.has(name_here): bone_ids[name_here]=sk.find_bone(name_here)
	return bone_ids[name_here]

func _process_modification_with_delta(_delta: float) -> void:
	floor_tick-=_delta
	var sample_floor:=floor_tick<=0
	if sample_floor: floor_tick=.08
	var sk := get_skeleton()
	if not sk or not rig: return
	var camera:=get_viewport().get_camera_3d()
	var distance: float=rig.global_position.distance_to(camera.global_position) if camera else 0.0
	solve_tick-=_delta
	if not rig.first_person and solve_tick>0 and not cached_poses.is_empty():
		for index in cached_poses:
			sk.set_bone_pose_rotation(index,cached_poses[index][0])
			sk.set_bone_pose_position(index,cached_poses[index][1])
		return
	solve_tick=0.0 if rig.first_person else 1.0/15.0 if distance>18 else 1.0/30.0 if distance>6 else 0.0
	if rest.is_empty():
		for i in range(sk.get_bone_count()): rest[i] = sk.get_bone_global_rest(i)
	# AnimationPlayer owns hip breathing / gait bob. Reset solved bones each frame.
	for name in ["Hips","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm","LeftHand","RightHand","Head","Chest"]:
		var index := bone(sk,name)
		if index>=0: sk.set_bone_pose_rotation(index,sk.get_bone_rest(index).basis.get_rotation_quaternion())
	if not rig.xr_pose.is_empty():
		var hips:=bone(sk,"Hips")
		var offset: Vector3=rig.xr_pose.head.origin-Vector3(0,1.65,0)
		offset=Vector3(offset.x*.45,clampf(offset.y,-.55,.1),offset.z*.45)
		var local_offset: Vector3=sk.global_basis.inverse()*rig.get_parent().global_basis*offset
		sk.set_bone_pose_position(hips,sk.get_bone_rest(hips).origin+local_offset)
	var body: Dictionary=rig.xr_pose.get("body",{}) if not rig.dead else {}
	if body.has("hips"):
		var hips:=bone(sk,"Hips")
		var target: Transform3D=rig.get_parent().global_transform*body.hips
		var parent:=sk.get_bone_parent(hips)
		var local: Vector3=sk.to_local(target.origin)
		if parent>=0: local=sk.get_bone_global_pose(parent).affine_inverse()*local
		sk.set_bone_pose_position(hips,local)
		orient(sk,hips,target.basis*reference_basis(sk,hips))
	if body.has("chest"):
		orient(sk,bone(sk,"Chest"),rig.get_parent().global_basis*body.chest.basis*reference_basis(sk,bone(sk,"Chest")))
	var direction: Vector3 = rig.movement.normalized()
	if direction.length()<.1: direction = Vector3.FORWARD
	var stride := clampf(rig.speed/9.4,0.0,1.0)*.30
	for side in ["Left","Right"]:
		var sign_x := -1.0 if side=="Left" else 1.0
		var theta: float = (rig.phase+(0.5 if side=="Right" else 0.0))*TAU
		var foot_idx := bone(sk,side+"Foot")
		var neutral: Vector3 = rig.to_local(sk.to_global(rest[foot_idx].origin))
		var foot := Vector3(sign_x*.13,neutral.y,neutral.z)+direction*cos(theta)*stride
		foot.y += maxf(0,sin(theta))*.15*minf(rig.speed/4.0,1.0)
		if rig.preview_mode<0 and rig.is_inside_tree() and sample_floor:
			var world_foot: Vector3 = rig.to_global(foot)
			var query := PhysicsRayQueryParameters3D.create(world_foot+Vector3.UP*.4,world_foot-Vector3.UP*.5,1)
			var hit: Dictionary = rig.get_world_3d().direct_space_state.intersect_ray(query)
			floor_heights[side]=rig.to_local(hit.position).y+neutral.y if not hit.is_empty() else neutral.y
		if floor_heights.has(side): foot.y=maxf(foot.y,floor_heights[side])
		var foot_world: Vector3=rig.to_global(foot)
		var knee_world: Vector3=rig.to_global(Vector3(sign_x*.16,.7,-.65))
		if body.has(side.to_lower()+"_foot"): foot_world=(rig.get_parent().global_transform*body[side.to_lower()+"_foot"]).origin
		if body.has(side.to_lower()+"_knee"): knee_world=(rig.get_parent().global_transform*body[side.to_lower()+"_knee"]).origin
		solve(sk,side+"UpperLeg",side+"LowerLeg",side+"Foot",foot_world,knee_world)
		var foot_parent := sk.get_bone_parent(foot_idx)
		sk.set_bone_pose_rotation(foot_idx,(sk.get_bone_global_pose(foot_parent).basis.inverse()*rest[foot_idx].basis).get_rotation_quaternion())
		if body.has(side.to_lower()+"_foot"):
			orient(sk,foot_idx,rig.get_parent().global_basis*body[side.to_lower()+"_foot"].basis*reference_basis(sk,foot_idx))
		var hand := bone(sk,side+"Hand")
		if not rig.xr_pose.is_empty():
			var target: Transform3D=rig.get_parent().global_transform*rig.xr_pose[side.to_lower()]
			var optical:=body.has(side.to_lower()+"_hand")
			if optical: target=rig.get_parent().global_transform*body[side.to_lower()+"_hand"]
			else: target.origin+=target.basis.y*.06 # Grip is at the palm, IK ends at the wrist.
			var elbow: Vector3=rig.to_global(Vector3(sign_x*.65,.85,.05))
			if body.has(side.to_lower()+"_elbow"): elbow=(rig.get_parent().global_transform*body[side.to_lower()+"_elbow"]).origin
			solve(sk,side+"UpperArm",side+"LowerArm",side+"Hand",target.origin,elbow)
			var parent:=sk.get_bone_parent(hand)
			# OpenXR grip -Z runs little-finger to thumb; it is not the aim/finger axis.
			# Humanoid hands use +Y along fingers and +Z toward the palm.
			var palm_basis: Basis=target.basis if optical else target.basis*controller_hand_basis(side=="Left")
			var desired: Basis=sk.global_basis.orthonormalized().inverse()*palm_basis
			sk.set_bone_pose_rotation(hand,(sk.get_bone_global_pose(parent).basis.orthonormalized().inverse()*desired).get_rotation_quaternion())
		else:
			# Pistols use separate grips; other weapons retain the supporting hand.
			var grip: Vector3=preload("res://deathmatch/art.gd").desktop_hand(side=="Left",rig.aim_pitch,rig.offhand_recoil if side=="Left" and rig.weapon_id==2 else rig.recoil,rig.weapon_id==2)
			solve(sk,side+"UpperArm",side+"LowerArm",side+"Hand",rig.to_global(grip),rig.to_global(Vector3(sign_x*.65,.8,-.1)))
			var middle := bone(sk,side+"MiddleProximal")
			if middle>=0:
				var finger_direction := sk.get_bone_global_pose(middle).origin-sk.get_bone_global_pose(hand).origin
				var forward: Vector3 = sk.global_basis.inverse()*rig.global_basis*Basis(Vector3.RIGHT,rig.aim_pitch)*Vector3.FORWARD
				rotate_bone_toward(sk,hand,finger_direction,forward)
		for finger in ["Thumb","Index","Middle","Ring","Little"]:
			for joint in ["Proximal","Intermediate","Distal"]:
				var index := bone(sk,side+finger+joint)
				if index<0: continue
				sk.set_bone_pose_rotation(index,sk.get_bone_rest(index).basis.get_rotation_quaternion())
				var curl:=.8
				if body.has(side.to_lower()+"_curls"):
					curl=body[side.to_lower()+"_curls"][["Thumb","Index","Middle","Ring","Little"].find(finger)]*1.25
				# Bend in each finger's own rest frame, so rotating the wrist cannot twist the fingers.
				sk.set_bone_pose_rotation(index,sk.get_bone_rest(index).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,curl))
	var head := bone(sk,"Head")
	if head>=0:
		var q := sk.get_bone_rest(head).basis.get_rotation_quaternion()
		if rig.xr_pose.is_empty(): sk.set_bone_pose_rotation(head,q*Quaternion(Vector3.RIGHT,rig.aim_pitch*.55))
		else:
			var target: Basis=rig.get_parent().global_basis*rig.xr_pose.head.basis*Basis(Vector3.UP,PI)
			var parent:=sk.get_bone_parent(head)
			sk.set_bone_pose_rotation(head,(sk.get_bone_global_pose(parent).basis.orthonormalized().inverse()*sk.global_basis.orthonormalized().inverse()*target).get_rotation_quaternion())

	for index in bone_ids.values():
		if index>=0: cached_poses[index]=[sk.get_bone_pose_rotation(index),sk.get_bone_pose_position(index)]

func solve(sk: Skeleton3D, upper: String, lower: String, end: String, target_world: Vector3, pole_world: Vector3) -> void:
	var a := bone(sk,upper)
	var b := bone(sk,lower)
	var c := bone(sk,end)
	if a<0 or b<0 or c<0: return
	var origin := sk.get_bone_global_pose(a).origin
	var middle := sk.get_bone_global_pose(b).origin
	var tip := sk.get_bone_global_pose(c).origin
	var l1 := origin.distance_to(middle)
	var l2 := middle.distance_to(tip)
	if minf(l1,l2)<.0001: return
	var target := sk.to_local(target_world)
	var direction := (target-origin).normalized()
	if direction.length()<.5: return
	var distance := clampf(origin.distance_to(target),absf(l1-l2)+.001,l1+l2-.001)
	var pole := sk.to_local(pole_world)-origin
	var perpendicular := (pole-direction*pole.dot(direction)).normalized()
	if perpendicular.length()<.5: perpendicular = direction.cross(Vector3.RIGHT).normalized()
	var along := (l1*l1-l2*l2+distance*distance)/(2*distance)
	var height := sqrt(maxf(0,l1*l1-along*along))
	var elbow := origin+direction*along+perpendicular*height
	rotate_bone_toward(sk,a,middle-origin,elbow-origin)
	middle = sk.get_bone_global_pose(b).origin
	tip = sk.get_bone_global_pose(c).origin
	rotate_bone_toward(sk,b,tip-middle,origin+direction*distance-middle)

func rotate_bone_toward(sk: Skeleton3D, index: int, source: Vector3, destination: Vector3) -> void:
	if source.length_squared()<.000001 or destination.length_squared()<.000001: return
	var global_basis := sk.get_bone_global_pose(index).basis.orthonormalized()
	var change := Quaternion(source.normalized(),destination.normalized())
	var parent := sk.get_bone_parent(index)
	var parent_basis := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(index,(parent_basis.inverse()*Basis(change)*global_basis).get_rotation_quaternion())

func orient(sk: Skeleton3D,index: int,world_basis: Basis) -> void:
	if index<0: return
	var parent:=sk.get_bone_parent(index)
	var parent_basis:=sk.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(index,(parent_basis.inverse()*sk.global_basis.orthonormalized().inverse()*world_basis.orthonormalized()).get_rotation_quaternion())

func reference_basis(sk: Skeleton3D,index: int) -> Basis:
	# Preserve each retargeted bone's authored axis convention (feet differ from hips).
	return rig.get_parent().global_basis.orthonormalized().inverse()*sk.global_basis.orthonormalized()*sk.get_bone_global_rest(index).basis.orthonormalized()

static func controller_hand_basis(left_hand: bool) -> Basis:
	var sign_side:=1.0 if left_hand else -1.0
	return Basis(Vector3.BACK*sign_side,Vector3.DOWN,Vector3.RIGHT*sign_side)
