extends RefCounted
static func setup(tree: SceneTree,world: Node3D,camera: Camera3D,count: int) -> Array[Vector3]:
	var level: Node3D=load("res://maps/cache/qsrc_dm6-lightmap1-bc7.scn").instantiate();world.add_child(level)
	assert(level.get_meta("bsp_source_sha256","")==FileAccess.get_sha256("res://maps/qsrc_dm6.bsp"))
	for i in 3:await tree.physics_frame
	var space:=world.get_world_3d().direct_space_state
	var candidates: Array[Vector3]=[]
	var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8
	for y in [0.0,4.0,7.0]:
		for x in range(2,69,2):
			for z in range(-62,3,2):
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,y+2,z),Vector3(x,y-1,z),1))
				if hit.is_empty() or hit.normal.y<.9:continue
				var p: Vector3=hit.position+Vector3.UP*.03
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform.origin=p+Vector3.UP*.91;query.collision_mask=1
				if not space.intersect_shape(query,1).is_empty():continue
				if candidates.any(func(q):return q.distance_to(p)<1.8):continue
				candidates.append(p)
	var best: Array[Vector3]=[];var eye:=Vector3.ZERO;var facing:=0.0
	# Select a clear standing viewpoint with enough visible floor for a crowded scene.
	for index in range(0,candidates.size(),8):
		camera.position=candidates[index]+Vector3.UP*1.6
		var visible: Array[Vector3]=[]
		for p in candidates:
			if p.distance_to(camera.position)<4:continue
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(camera.position,p+Vector3.UP*1.3,1)).is_empty():visible.append(p)
		for angle in 8:
			camera.rotation=Vector3(0,angle*TAU/8,0)
			var subset: Array[Vector3]=[]
			for p in visible:
				if camera.is_position_in_frustum(p+Vector3.UP):subset.append(p)
			if subset.size()>best.size():best=subset;eye=camera.position;facing=camera.rotation.y
	camera.position=eye;camera.rotation=Vector3(0,facing,0)
	print("DM6_PLACEMENTS candidates=",candidates.size()," visible=",best.size()," camera=",eye," yaw=",facing)
	if best.size()<count:push_error("Not enough visible clear DM6 placements");tree.quit(2);return []
	best.sort_custom(func(a,b):return camera.position.distance_squared_to(a)<camera.position.distance_squared_to(b))
	var positions: Array[Vector3]=[]
	for i in count:positions.append(best[int(i*float(best.size())/count)])
	return positions
