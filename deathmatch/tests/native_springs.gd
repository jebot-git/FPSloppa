extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func synthetic() -> void:
	for scale in [.5,1.0,2.0]:
		var model:=Node3D.new();root.add_child(model);model.scale=Vector3.ONE*scale
		var sk:=Skeleton3D.new();sk.name="Skeleton";model.add_child(sk)
		for i in 3:
			sk.add_bone(["Root","Hair","Tip"][i])
			if i>0:sk.set_bone_parent(i,i-1)
			sk.set_bone_rest(i,Transform3D(Basis.IDENTITY,Vector3.UP*.2));sk.reset_bone_pose(i)
		var spring:=VRMSpringBone.new();spring.joint_nodes=PackedStringArray(["Hair","Tip"])
		spring.stiffness_force=PackedFloat64Array([.5]);spring.drag_force=PackedFloat64Array([.4]);spring.gravity_power=PackedFloat64Array([1.0]);spring.gravity_dir_default=Vector3.RIGHT
		var collider:=VRMCollider.new();collider.bone="Root";collider.offset=Vector3(.1,0,0);collider.radius=.02
		var group:=VRMColliderGroup.new();group.colliders=[collider];spring.collider_groups=[group]
		var secondary:=VRMSecondary.new();secondary.skeleton=NodePath("../Skeleton");secondary.spring_bones=[spring];model.add_child(secondary)
		var sim: SpringBoneSimulator3D=secondary.native_simulator
		var trace: Dictionary={"frames":0,"angle":0.0}
		sim.modification_processed.connect(func():trace.frames+=1;trace.angle=maxf(trace.angle,sk.get_bone_pose_rotation(1).angle_to(Quaternion.IDENTITY)))
		for i in 20:await process_frame
		check(trace.frames>0 and trace.angle>.01,"Native engine actually animates spring joints at scale "+str(scale))
		var collision: SpringBoneCollision3D=sim.get_child(0)
		var expected: Vector3=sk.to_global(sk.get_bone_global_pose(0)*collider.offset)
		check(collision.global_position.distance_to(expected)<.0001,"Native collider preserves VRM offset at scale "+str(scale))
		check(is_equal_approx(sim.get_joint_stiffness(0,0),.5) and is_equal_approx(sim.get_joint_drag(0,0),.4),"Per-joint spring parameters survive conversion")
		model.free()
func run():
	await synthetic()
	var world:=Node3D.new();root.add_child(world)
	var library=load("res://deathmatch/avatars/library.gd").new();root.add_child(library)
	check(not library.entries.is_empty(),"Bundled avatar fixtures available")
	for hash in library.entries:
		var rig=library.create_avatar(hash);check(rig!=null,"Load "+library.entries[hash].title)
		if rig==null:continue
		world.add_child(rig);rig.preview_mode=0
		for secondary in rig.secondary_nodes:
			check(secondary.native_simulator is SpringBoneSimulator3D and secondary.spring_chain_count()>0,"Native simulator has imported chains")
			check(secondary.spring_bones_internal.is_empty() and secondary.internal_modifier_node==null,"No scripted Verlet simulation is initialized")
			check(secondary.spring_chain_count()==secondary.spring_bones.size(),"Every authored spring chain is retained")
			check(secondary.native_simulator.get_index()>rig.solver.get_index(),"Springs run after body IK")
		for i in 10:
			rig.position.x+=.01;await process_frame
		for secondary in rig.secondary_nodes:
			check(secondary.native_simulator.active,"Native simulation runs")
			VRMSecondary.springs_enabled=false;secondary.update_native_state()
			check(not secondary.native_simulator.active,"Graphics toggle stops native simulation")
			VRMSecondary.springs_enabled=true;secondary.update_native_state()
			secondary.set_local_body(true);check(not secondary.native_simulator.active,"First-person body keeps tracked bones authoritative")
			secondary.set_local_body(false);check(secondary.native_simulator.active,"Returning to remote view restores simulation")
			rig.hide();secondary.update_native_state();check(not secondary.native_simulator.active,"Hidden models stop simulation");rig.show()
			secondary.update_native_state();var resets: int=secondary.animation_resets
			rig.position.x+=10;secondary.update_native_state();check(secondary.animation_resets>resets,"Teleport resets spring history")
		for i in rig.skeleton.get_bone_count():
			if not rig.skeleton.get_bone_pose(i).is_finite():failures.append("Nonfinite bone "+str(i))
		rig.free()
	library.free();world.free();print("NATIVE_SPRINGS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
