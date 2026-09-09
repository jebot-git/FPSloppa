extends SceneTree
const Library = preload("res://deathmatch/avatars/library.gd")
var failures := 0
func check(condition: bool, label: String) -> void:
	print("AVATAR_CHECK ",label," ","PASS" if condition else "FAIL")
	if not condition: failures+=1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var library := Library.new()
	root.add_child(library)
	check(library.entries.size()>=3,"three bundled VRMs")
	for path in OS.get_cmdline_user_args():
		check(not library.register_file(path,false).is_empty(),"additional VRM fixture")
	for hash in library.entries:
		var entry: Dictionary = library.entries[hash]
		var info := Library.inspect(entry.path)
		print("INSPECT ",entry.title,": ",info)
		check(not info.has("error"),"validate "+entry.title)
		check(FileAccess.get_sha256(entry.path)==hash,"SHA256 "+entry.title)
		var avatar := library.create_avatar(hash)
		check(avatar!=null,"runtime import "+entry.title)
		if avatar:
			root.add_child(avatar)
			avatar.preview_mode=2
			await process_frame
			await process_frame
			print("SKELETON ",avatar.skeleton.name," bones=",avatar.skeleton.get_bone_count()," scale=",avatar.scale_factor)
			check(avatar.motion.has_animation("idle") and avatar.motion.has_animation("walk") and avatar.motion.has_animation("run"),"retargeted animations")
			check(avatar.solver is SkeletonModifier3D,"IK modifier")
			check(absf(avatar.mesh_bounds(avatar.model,Transform3D.IDENTITY).size.y-1.70)<.01,"normalized visual height")
			avatar.solver._process_modification_with_delta(.016)
			var hand: int = avatar.skeleton.find_bone("RightHand")
			var grip: Vector3 = avatar.to_local(avatar.skeleton.to_global(avatar.skeleton.get_bone_global_pose(hand).origin))
			check(grip.distance_to(Vector3(.13,1.15,-.30))<.15,"hand IK reaches weapon grip")
			var fighter = preload("res://deathmatch/fighter.gd").new()
			fighter.setup(1,"Test",Color.WHITE)
			root.add_child(fighter)
			var shape: CapsuleShape3D = fighter.get_child(0).shape
			check(is_equal_approx(shape.radius,.30) and is_equal_approx(shape.height,1.65),"unified collision capsule")
			fighter.free()
			for i in range(avatar.skeleton.get_bone_count()):
				if not avatar.skeleton.get_bone_global_pose(i).origin.is_finite(): failures+=1
			avatar.free()
	var file := FileAccess.open("user://oversize.vrm",FileAccess.WRITE)
	file.seek(Library.MAX_BYTES)
	file.store_8(0)
	file.close()
	check(Library.inspect("user://oversize.vrm").has("error"),"reject >25 MB before parsing")
	DirAccess.remove_absolute("user://oversize.vrm")
	check(not Library.valid_hash("../../anything"),"reject unsafe asset keys")
	check(Library.inspect("res://deathmatch/arena.gd").has("error"),"reject non-VRM")
	check(Library.validate_structure({"nodes":[{"children":[1.0]},{"children":[0.0]}]}).contains("Cyclic"),"reject cyclic skeleton graph")
	check(not Library.validate_structure({"extensions":{"VRM":[]}}).is_empty(),"reject malformed VRM extension types")
	check(not Library.validate_structure({"nodes":[{"children":[99.0]}]}).is_empty(),"reject out-of-range joints")
	library.free()
	print("AVATAR_TESTS_DONE failures=",failures)
	quit(1 if failures else 0)
