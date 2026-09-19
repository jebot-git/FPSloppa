extends RefCounted
## Preserve authored exits unless a nearby portal or wall obstructs departure.
const RADIUS=.30
const CLEARANCE=.08
static func yaw(data: Dictionary) -> float:
	var degrees:=float(data.get("angle",0))
	var angles:=str(data.get("angles","")).split_floats(" ",false)
	if angles.size()==3:degrees=angles[1]
	return wrapf(deg_to_rad(degrees),-PI,PI) if is_finite(degrees) else 0.
static func query(position: Vector3,height: float) -> PhysicsShapeQueryParameters3D:
	var result:=PhysicsShapeQueryParameters3D.new()
	var shape:=CapsuleShape3D.new();shape.radius=RADIUS;shape.height=height
	result.shape=shape;result.transform.origin=position+Vector3.UP*(height*.5+.005)
	result.collision_mask=1;result.margin=.001
	return result
static func resolve(runtime,authored: Dictionary,height: float=1.65) -> Dictionary:
	var space: PhysicsDirectSpaceState3D=runtime.game.get_world_3d().direct_space_state
	var position: Vector3=authored.position
	var probe:=query(position,height)
	# Players are intentionally excluded: the normal telefrag rule handles them.
	if not space.intersect_shape(probe,1).is_empty():return {}
	var facing: float=authored.yaw
	probe.motion=Vector3.FORWARD.rotated(Vector3.UP,facing)*3.
	var distance: float=space.cast_motion(probe)[0]*3.
	if distance<1.0:
		# Only repair an immediately obstructed heading; do not rotate valid exits
		# toward whichever distant corridor happens to be longest.
		for turn in [PI,PI/2,-PI/2,PI/4,-PI/4,PI*3/4,-PI*3/4]:
			probe.motion=Vector3.FORWARD.rotated(Vector3.UP,float(authored.yaw)+turn)*3.
			var available: float=space.cast_motion(probe)[0]*3.
			if available>distance+.25:facing=float(authored.yaw)+turn;distance=available
	var forward:=Vector3.FORWARD.rotated(Vector3.UP,facing)
	var body:=AABB(position-Vector3(RADIUS,0,RADIUS),Vector3(RADIUS*2,height,RADIUS*2))
	var advance:=0.
	for region in runtime.regions:
		if region.kind!="trigger_teleport":continue
		for shape in region.area.get_children():
			if not shape is CollisionShape3D or not shape.shape is BoxShape3D or shape.disabled:continue
			# Use the actual trigger box frame; a world AABB overestimates the
			# depth of a diagonal portal and can push a player unnecessarily far.
			var inverse: Transform3D=shape.global_transform.affine_inverse()
			var local_body: AABB=inverse*body
			var bounds:=AABB(-shape.shape.size*.5,shape.shape.size)
			# Floor pads have no horizontal front plane.
			if bounds.size.y<.75 or not bounds.grow(.75).intersects(local_body):continue
			var local_forward:=inverse.basis*forward
			var half:=bounds.size*.5
			var front: float=absf(local_forward.x)*half.x+absf(local_forward.z)*half.z
			advance=maxf(advance,front+RADIUS+CLEARANCE-local_forward.dot(inverse*position))
	if advance>0:
		if advance>2.5:return {}
		probe.motion=forward*advance
		if space.cast_motion(probe)[0]<1.:return {}
		position+=probe.motion
		if not space.intersect_shape(query(position,height),1).is_empty():return {}
	return {"position":position,"yaw":wrapf(facing,-PI,PI)}
static func rig_yaw(exit_yaw: float,pose: Dictionary) -> float:
	# XR tracking is relative to the rig. Rotate the rig so the physical head,
	# including fully tracked body setups, faces the authored world direction.
	var head_turn:=0.
	if pose.has("head"):
		var forward: Vector3=-pose.head.basis.z
		if Vector2(forward.x,forward.z).length_squared()>.0001:head_turn=atan2(-forward.x,-forward.z)
	return wrapf(exit_yaw-head_turn,-PI,PI)
