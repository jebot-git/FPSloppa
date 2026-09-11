extends SceneTree
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var library=load("res://deathmatch/avatars/library.gd").new()
	root.add_child(library)
	var body:=Node3D.new()
	root.add_child(body)
	for hash in library.entries:
		var avatar=library.create_avatar(hash)
		body.add_child(avatar)
		var pose=load("res://deathmatch/vr/poses.gd").neutral()
		pose.head.origin.y=1.3
		pose.left.origin=Vector3(-.3,.95,-.3)
		pose.right.origin=Vector3(.3,.95,-.3)
		pose.weapon=pose.right
		avatar.target_xr_pose=pose
		await process_frame
		await process_frame
		avatar.solver._process_modification_with_delta(.016)
		for side in ["Left","Right"]:
			var bone: int=avatar.skeleton.find_bone(side+"Hand")
			var pos: Vector3=avatar.skeleton.to_global(avatar.skeleton.get_bone_global_pose(bone).origin)
			check(pos.distance_to(pose[side.to_lower()].origin)<.17,library.entries[hash].title+" crouched "+side+" tracking IK")
		avatar.hurt(Vector3.RIGHT,30)
		check(avatar.pain>.5,"Avatar receives hit flinch")
		var palm: Vector3=avatar.gun.to_global(preload("res://deathmatch/art.gd").GRIPS[avatar.weapon_id])
		check(palm.distance_to(pose.weapon.origin)<.001,"Visible VR weapon grip follows tracked hand")
		avatar.set_first_person(true)
		pose.left.basis=Basis.from_euler(Vector3(.3,.6,.4));pose.right.basis=pose.left.basis
		avatar.xr_pose=pose
		avatar.solver._process_modification_with_delta(.016)
		for side in ["Left","Right"]:
			var sk:Skeleton3D=avatar.skeleton
			var wrist:int=sk.find_bone(side+"Hand")
			var actual:Basis=sk.global_basis.orthonormalized()*sk.get_bone_global_pose(wrist).basis.orthonormalized()
			var grip:Basis=pose[side.to_lower()].basis
			check(actual.y.dot(-grip.y)>.99 and actual.z.dot(grip.x*(1 if side=="Left" else -1))>.99,"Controller grip axes orient "+side+" palm correctly")
			var finger:int=sk.find_bone(side+"IndexIntermediate")
			var curl:Quaternion=sk.get_bone_rest(finger).basis.get_rotation_quaternion().inverse()*sk.get_bone_pose_rotation(finger)
			check(curl.is_equal_approx(Quaternion(Vector3.RIGHT,.8)),"Rotated "+side+" wrist keeps finger bend in local frame")
		pose.body={"left_hand":Transform3D(Basis.from_euler(Vector3(.2,-.4,.7)),pose.left.origin)}
		avatar.xr_pose=pose;avatar.solver._process_modification_with_delta(.016)
		var optical:Basis=avatar.skeleton.global_basis.orthonormalized()*avatar.skeleton.get_bone_global_pose(avatar.skeleton.find_bone("LeftHand")).basis.orthonormalized()
		check(optical.is_equal_approx(pose.body.left_hand.basis),"Native optical wrist keeps humanoid bone axes")
		for angle in [0.0,PI/2,-PI/2]:
			var yaw:=Basis(Vector3.UP,angle)
			pose.body={"hips":Transform3D(yaw,Vector3(0,.72,0)),"left_foot":Transform3D(yaw,yaw*Vector3(-.15,.08,0)),"right_foot":Transform3D(yaw,yaw*Vector3(.15,.08,0))}
			avatar.xr_pose=pose;avatar.solver._process_modification_with_delta(.016)
			for side in ["Left","Right"]:
				var sk:Skeleton3D=avatar.skeleton
				var hip:Vector3=sk.to_global(sk.get_bone_global_pose(sk.find_bone(side+"UpperLeg")).origin)
				var knee:Vector3=sk.to_global(sk.get_bone_global_pose(sk.find_bone(side+"LowerLeg")).origin)
				check((knee-hip).dot(-yaw.z)>-.015,library.entries[hash].title+" "+side+" knee bends toward pelvis forward at yaw "+str(angle))
		avatar.free()
	body.free()
	library.free()
	print("VR_IK_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
