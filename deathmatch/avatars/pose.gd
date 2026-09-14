extends SkeletonModifier3D
## Analytical two-bone IK. Targets are in arena metres, solved in skeleton space.
var rig
var rest: Dictionary = {}
var bone_ids: Dictionary={}
var floor_tick:=0.0
var solve_tick:=0.0
var cached_poses: Dictionary={}
var floor_heights: Dictionary={}
const Death = preload("res://deathmatch/avatars/death_pose.gd")
var death_start: Dictionary={}
var death_cache: Dictionary={}
var death_hip_height:=.92
func reset_death() -> void:
	death_start.clear();death_cache.clear();solve_tick=0.0
	# Retain the last live pose for entry; discard a corpse pose on respawn.
	if rig and not rig.dead:cached_poses.clear();floor_heights.clear()

func collapse(sk: Skeleton3D) -> void:
	if not death_cache.is_empty():
		for index in death_cache:
			sk.set_bone_pose_rotation(index,death_cache[index][0])
			sk.set_bone_pose_position(index,death_cache[index][1])
		return
	if death_start.is_empty():
		for i in sk.get_bone_count():
			death_start[i]=cached_poses.get(i,[sk.get_bone_pose_rotation(i),sk.get_bone_pose_position(i)])
			sk.set_bone_pose_rotation(i,death_start[i][0]);sk.set_bone_pose_position(i,death_start[i][1])
		death_hip_height=clampf(rig.to_local(sk.to_global(sk.get_bone_global_pose(bone(sk,"Hips")).origin)).y,.22,rig.neutral_hip_height)
	for i in sk.get_bone_count():sk.reset_bone_pose(i)
	var pose := Death.sample(rig.death_time,death_hip_height)
	var hips := bone(sk,"Hips")
	var parent := sk.get_bone_parent(hips)
	var target: Vector3=sk.to_local(rig.to_global(pose.pelvis))
	if parent>=0:target=sk.get_bone_global_pose(parent).affine_inverse()*target
	sk.set_bone_pose_position(hips,target)
	orient(sk,hips,rig.global_basis*pose.basis*reference_basis(sk,hips))
	for side in ["Left","Right"]:
		var key: String = side.to_lower()
		var sign_side := -1.0 if side=="Left" else 1.0
		var release: float=pose.release
		var foot := Vector3(sign_side*.13,.12,0).lerp(pose[key+"_foot"],release)
		var hand := Vector3(sign_side*.38,.82,-.22).lerp(pose[key+"_hand"],release)
		solve(sk,side+"UpperLeg",side+"LowerLeg",side+"Foot",rig.to_global(foot),rig.to_global(pose[key+"_knee"]))
		solve(sk,side+"UpperArm",side+"LowerArm",side+"Hand",rig.to_global(hand),rig.to_global(pose[key+"_elbow"]))
		for ending in ["Foot","Hand"]:
			var index := bone(sk,side+ending)
			orient(sk,index,rig.global_basis*Basis(Vector3.FORWARD,sign_side*.32)*reference_basis(sk,index))
		for finger in ["Thumb","Index","Middle","Ring","Little"]:
			for joint in ["Proximal","Intermediate","Distal"]:
				var index := bone(sk,side+finger+joint)
				if index>=0:sk.set_bone_pose_rotation(index,sk.get_bone_rest(index).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,.18))
	var head := bone(sk,"Head")
	orient(sk,head,rig.global_basis*pose.basis*Basis.from_euler(Vector3(.15,.30,-.22))*reference_basis(sk,head))
	var blend := smoothstep(0.0,.30,rig.death_time)
	for i in sk.get_bone_count():
		sk.set_bone_pose_rotation(i,death_start[i][0].slerp(sk.get_bone_pose_rotation(i),blend))
		sk.set_bone_pose_position(i,death_start[i][1].lerp(sk.get_bone_pose_position(i),blend))
		if rig.death_time>=Death.SETTLE_TIME:death_cache[i]=[sk.get_bone_pose_rotation(i),sk.get_bone_pose_position(i)]
func bone(sk: Skeleton3D, name_here: String) -> int:
	if not bone_ids.has(name_here): bone_ids[name_here]=sk.find_bone(name_here)
	return bone_ids[name_here]

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if not sk or not rig:return
	if rig.dead:
		collapse(sk)
		return
	floor_tick-=_delta
	var sample_floor:=floor_tick<=0
	if sample_floor: floor_tick=.08
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
	var body: Dictionary=rig.xr_pose.get("body",{}) if not rig.dead else {}
	var hips:=bone(sk,"Hips")
	var offset:=Vector3.ZERO
	if not rig.xr_pose.is_empty():
		offset=rig.global_basis.inverse()*rig.tracking_transform().basis*(rig.xr_pose.head.origin-Vector3(0,1.65,0))
		offset=Vector3(offset.x*.45,clampf(offset.y,-.90,.1),offset.z*.45)
	else:
		offset.y=rig.collider_height-1.65
	if rig.gait.prone_blend>0:
		offset=offset.lerp(Vector3(0,.30-rig.neutral_hip_height,.35),rig.gait.prone_blend)
	if not body.has("hips"):
		offset.y+=rig.gait.bob-rig.gait.landing*.5
		var local_offset: Vector3=sk.global_basis.inverse()*rig.global_basis*offset
		sk.set_bone_pose_position(hips,sk.get_bone_rest(hips).origin+local_offset)
		if rig.gait.prone_blend>0:
			orient(sk,hips,rig.global_basis*Basis(Vector3.RIGHT,-PI*.43*rig.gait.prone_blend)*reference_basis(sk,hips))
	if body.has("hips"):
		var target: Transform3D=rig.tracking_transform()*rig.fit_tracked_hips(body.hips)
		var parent:=sk.get_bone_parent(hips)
		var local: Vector3=sk.to_local(target.origin)
		if parent>=0: local=sk.get_bone_global_pose(parent).affine_inverse()*local
		sk.set_bone_pose_position(hips,local)
		orient(sk,hips,target.basis*reference_basis(sk,hips))
	if body.has("chest"):
		orient(sk,bone(sk,"Chest"),rig.tracking_transform().basis*body.chest.basis*reference_basis(sk,bone(sk,"Chest")))
	for side in ["Left","Right"]:
		var sign_x := -1.0 if side=="Left" else 1.0
		var foot_idx := bone(sk,side+"Foot")
		if foot_idx<0 or bone(sk,side+"UpperLeg")<0:continue
		var neutral: Vector3 = rig.to_local(sk.to_global(rest[foot_idx].origin))
		var foot: Vector3=Vector3(sign_x*.13,neutral.y,neutral.z)+rig.gait.offsets[side.to_lower()]
		if rig.preview_mode<0 and rig.is_inside_tree() and sample_floor and rig.grounded:
			var world_foot: Vector3 = rig.to_global(foot)
			var query := PhysicsRayQueryParameters3D.create(world_foot+Vector3.UP*.4,world_foot-Vector3.UP*.5,1)
			var hit: Dictionary = rig.get_world_3d().direct_space_state.intersect_ray(query)
			floor_heights[side]=rig.to_local(hit.position).y+neutral.y if not hit.is_empty() else neutral.y
		if rig.grounded and floor_heights.has(side): foot.y=maxf(foot.y,floor_heights[side])
		var foot_world: Vector3=rig.to_global(foot)
		var hip_world:Vector3=sk.to_global(sk.get_bone_global_pose(bone(sk,side+"UpperLeg")).origin)
		var knee_world: Vector3=hip_world+rig.global_basis*Vector3(sign_x*.08,0,-.65)
		if body.has(side.to_lower()+"_foot"):
			foot_world=(rig.tracking_transform()*rig.fit_tracked_foot(side.to_lower(),body[side.to_lower()+"_foot"])).origin
			foot_world+=rig.global_basis*rig.gait.offsets[side.to_lower()]*rig.gait.assist_weight*.6
		elif rig.gait.prone_blend>.5:
			knee_world=hip_world+rig.global_basis*Vector3(sign_x*.25,-.3,.45)
		if body.has("hips") and not body.has(side.to_lower()+"_knee"):
			knee_world=leg_pole(body,side.to_lower(),hip_world,rig.tracking_transform())
		if body.has(side.to_lower()+"_knee"):
			knee_world=(rig.tracking_transform()*body[side.to_lower()+"_knee"]).origin
			knee_world+=rig.global_basis*rig.gait.offsets[side.to_lower()]*rig.gait.assist_weight*.5
		solve(sk,side+"UpperLeg",side+"LowerLeg",side+"Foot",foot_world,knee_world)
		var foot_parent := sk.get_bone_parent(foot_idx)
		sk.set_bone_pose_rotation(foot_idx,((sk.get_bone_global_pose(foot_parent).basis.inverse() if foot_parent>=0 else Basis.IDENTITY)*rest[foot_idx].basis).get_rotation_quaternion())
		if body.has(side.to_lower()+"_foot"):
			orient(sk,foot_idx,rig.tracking_transform().basis*body[side.to_lower()+"_foot"].basis*reference_basis(sk,foot_idx))
		var hand := bone(sk,side+"Hand")
		if hand<0:continue
		if not rig.xr_pose.is_empty():
			var target: Transform3D=rig.tracking_transform()*rig.xr_pose[side.to_lower()]
			var optical:=body.has(side.to_lower()+"_hand")
			if optical: target=rig.tracking_transform()*body[side.to_lower()+"_hand"]
			else: target.origin+=target.basis.y*.06 # Grip is at the palm, IK ends at the wrist.
			var elbow: Vector3=rig.to_global(Vector3(sign_x*.65,.85,.05))
			if body.has(side.to_lower()+"_elbow"): elbow=(rig.tracking_transform()*body[side.to_lower()+"_elbow"]).origin
			solve(sk,side+"UpperArm",side+"LowerArm",side+"Hand",target.origin,elbow)
			var parent:=sk.get_bone_parent(hand)
			# OpenXR grip -Z runs little-finger to thumb; it is not the aim/finger axis.
			# Humanoid hands use +Y along fingers and +Z toward the palm.
			var palm_basis: Basis=target.basis if optical else target.basis*controller_hand_basis(side=="Left")
			var desired: Basis=sk.global_basis.orthonormalized().inverse()*palm_basis
			sk.set_bone_pose_rotation(hand,((sk.get_bone_global_pose(parent).basis.orthonormalized().inverse() if parent>=0 else Basis.IDENTITY)*desired).get_rotation_quaternion())
		else:
			# Pistols use separate grips; other weapons retain the supporting hand.
			var grip: Vector3=preload("res://deathmatch/art.gd").desktop_hand(side=="Left",rig.aim_pitch,rig.offhand_recoil if side=="Left" and rig.weapon_id==2 else rig.recoil,rig.weapon_id==2)
			grip.y-=1.65-rig.collider_height
			solve(sk,side+"UpperArm",side+"LowerArm",side+"Hand",rig.to_global(grip),rig.to_global(Vector3(sign_x*.65,.8-(1.65-rig.collider_height)*.65,-.1)))
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
		if rig.xr_pose.is_empty():
			if rig.gait.prone_blend>.01:orient(sk,head,rig.global_basis*Basis(Vector3.RIGHT,rig.aim_pitch*.55)*reference_basis(sk,head))
			else:sk.set_bone_pose_rotation(head,q*Quaternion(Vector3.RIGHT,rig.aim_pitch*.55))
		else:
			var target: Basis=rig.tracking_transform().basis*rig.xr_pose.head.basis*Basis(Vector3.UP,PI)
			var parent:=sk.get_bone_parent(head)
			sk.set_bone_pose_rotation(head,((sk.get_bone_global_pose(parent).basis.orthonormalized().inverse() if parent>=0 else Basis.IDENTITY)*sk.global_basis.orthonormalized().inverse()*target).get_rotation_quaternion())

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
	# Optional humanoid bones (notably Chest) can be absent from a valid VRM.
	if index<0 or index>=sk.get_bone_count():return Basis.IDENTITY
	var frame:Basis=rig.global_basis if rig.dead else rig.tracking_transform().basis
	return frame.orthonormalized().inverse()*sk.global_basis.orthonormalized()*sk.get_bone_global_rest(index).basis.orthonormalized()

static func controller_hand_basis(left_hand: bool) -> Basis:
	var sign_side:=1.0 if left_hand else -1.0
	return Basis(Vector3.BACK*sign_side,Vector3.DOWN,Vector3.RIGHT*sign_side)

static func leg_pole(body: Dictionary,side: String,hip: Vector3,frame: Transform3D) -> Vector3:
	var pelvis:Basis=frame.basis*body.hips.basis
	var forward:Vector3=-pelvis.z;forward.y=0
	if forward.length()<.1:forward=-frame.basis.z;forward.y=0
	forward=forward.normalized()
	var foot=body.get(side+"_foot")
	if foot is Transform3D:
		var toe:Vector3=-(frame.basis*foot.basis).z;toe.y=0
		if toe.length()>.1:
			var angle:=forward.signed_angle_to(toe.normalized(),Vector3.UP)
			forward=forward.rotated(Vector3.UP,clampf(angle,-PI/6,PI/6)*.5)
	return hip+forward*.65+forward.cross(Vector3.UP)*(-.06 if side=="left" else .06)
