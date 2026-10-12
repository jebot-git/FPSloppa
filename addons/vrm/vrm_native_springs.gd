@tool
extends RefCounted
## Convert imported VRM resources once; Godot owns integration and collisions.
static func value_at(values: PackedFloat64Array,index: int,fallback: float=1.0) -> float:
	return fallback if values.is_empty() else values[mini(index,values.size()-1)]

static func build(secondary: Node3D,skel: Skeleton3D) -> SpringBoneSimulator3D:
	var options: Node=secondary.get_parent() if secondary.get_parent() is VRMTopLevel else secondary
	var sim:=SpringBoneSimulator3D.new()
	sim.external_force=options.springbone_add_force
	sim.name="VRMNativeSprings";sim.active=false
	skel.add_child(sim)
	var colliders: Dictionary={}
	for spring in secondary.spring_bones:
		if spring==null or spring.joint_nodes.size()<2:continue
		var names: PackedStringArray=spring.joint_nodes
		var extended:=names[-1].is_empty()
		var last:=names.size()-2 if extended else names.size()-1
		var valid:=true
		for j in last+1:
			var bone:=skel.find_bone(names[j])
			if bone<0 or (j>0 and skel.get_bone_parent(bone)!=skel.find_bone(names[j-1])):valid=false;break
		if not valid:continue # Never turn unrelated roots into a fabricated chain.
		var index:=sim.setting_count
		sim.setting_count+=1
		sim.set_root_bone_name(index,names[0]);sim.set_end_bone_name(index,names[last])
		sim.set_extend_end_bone(index,extended)
		if extended:
			sim.set_end_bone_direction(index,SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
			sim.set_end_bone_length(index,.07)
		# Integrate in avatar-local space so uniform avatar fitting does not
		# distort native spring lengths. Explicit VRM centers remain supported.
		sim.set_center_from(index,SpringBoneSimulator3D.CENTER_FROM_NODE)
		sim.set_center_node(index,sim.get_path_to(skel))
		if options.override_springbone_center:
			if is_instance_valid(options.default_springbone_center):sim.set_center_node(index,sim.get_path_to(options.default_springbone_center))
		elif not spring.center_bone.is_empty() and skel.find_bone(spring.center_bone)>=0:
			sim.set_center_from(index,SpringBoneSimulator3D.CENTER_FROM_BONE)
			sim.set_center_bone_name(index,spring.center_bone)
		elif not spring.center_node.is_empty():
			var center:=secondary.get_node_or_null(spring.center_node)
			if center:sim.set_center_node(index,sim.get_path_to(center))
		sim.set_individual_config(index,true)
		for joint in sim.get_joint_count(index):
			sim.set_joint_stiffness(index,joint,maxf(0,spring.stiffness_scale*value_at(spring.stiffness_force,joint)))
			sim.set_joint_drag(index,joint,clampf(spring.drag_force_scale*value_at(spring.drag_force,joint),0,1))
			sim.set_joint_radius(index,joint,maxf(0,spring.hit_radius_scale*value_at(spring.hit_radius,joint)))
			sim.set_joint_gravity(index,joint,spring.gravity_scale*value_at(spring.gravity_power,joint)*options.springbone_gravity_multiplier)
			var gravity: Vector3=spring.gravity_dir_default if spring.gravity_dir.is_empty() else spring.gravity_dir[mini(joint,spring.gravity_dir.size()-1)]
			sim.set_joint_gravity_direction(index,joint,options.springbone_gravity_rotation*gravity)
		sim.set_enable_all_child_collisions(index,false)
		var paths: Array[NodePath]=[]
		for group in spring.collider_groups:
			if group==null:continue
			for source in group.colliders:
				if source==null:continue
				if not colliders.has(source):
					var collider: SpringBoneCollision3D=SpringBoneCollisionCapsule3D.new() if source.is_capsule else SpringBoneCollisionSphere3D.new()
					sim.add_child(collider)
					collider.radius=maxf(0,source.radius)
					if not source.bone.is_empty() and skel.find_bone(source.bone)>=0:collider.bone_name=source.bone
					var offset: Vector3=source.offset
					var rotation:=Quaternion.IDENTITY
					if source.is_capsule:
						var axis: Vector3=source.tail-source.offset
						collider.height=axis.length()+2*collider.radius
						offset=(source.offset+source.tail)*.5
						if axis.length_squared()>.000001:rotation=Quaternion(Vector3.UP,axis.normalized())
					# Native bone offsets are expressed in world metres; VRM
					# offsets are in the imported skeleton's units.
					var bone_scale:=skel.global_basis.get_scale()
					if collider.bone>=0:bone_scale=(skel.global_basis*skel.get_bone_global_rest(collider.bone).basis).get_scale()
					collider.position_offset=offset*bone_scale;collider.rotation_offset=rotation
					if not source.node_path.is_empty():
						var target:=secondary.get_node_or_null(source.node_path)
						if target:
							if collider.bone>=0:collider.bone=-1
							secondary.native_external_colliders.append([collider,target,Transform3D(Basis(rotation),offset)])
					if collider.bone<0 and source.node_path.is_empty():
						secondary.native_external_colliders.append([collider,secondary,Transform3D(Basis(rotation),offset)])
					colliders[source]=collider
				var path: NodePath=sim.get_path_to(colliders[source])
				if not paths.has(path):paths.append(path)
		if options.disable_colliders:paths.clear()
		sim.set_collision_count(index,paths.size())
		for i in paths.size():sim.set_collision_path(index,i,paths[i])
	return sim
