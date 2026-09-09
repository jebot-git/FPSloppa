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
		check(avatar.gun.global_position.distance_to(pose.weapon.origin)<.03,"Visible VR weapon follows tracked hand")
		avatar.free()
	body.free()
	library.free()
	print("VR_IK_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
