extends RefCounted
const MAX_SPEED:=26.0
const GRAVITY:=20.0
static func launch(hand_velocity: Vector3) -> Vector3:
	if not hand_velocity.is_finite():return Vector3.ZERO
	var bounded:=hand_velocity.limit_length(12)
	# Preserve gentle drops; a modest arm stroke can reach across a room.
	var gain:=lerpf(1.0,2.4,clampf((bounded.length()-.65)/1.35,0,1))
	return (bounded*gain).limit_length(MAX_SPEED)
static func arc(space: PhysicsDirectSpaceState3D,start: Vector3,velocity: Vector3,duration: float) -> PackedVector3Array:
	var result:=PackedVector3Array([start])
	# Reuse one sweep query across the preview; only its transform/motion change.
	var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.12
	query.shape=sphere;query.collision_mask=1;query.margin=.001;query.transform=Transform3D(Basis.IDENTITY,start)
	if not space.intersect_shape(query,1).is_empty():return result
	for i in ceili(minf(duration,2.0)*30):
		velocity.y-=GRAVITY/30.0
		var end:=start+velocity/30.0
		query.transform.origin=start;query.motion=end-start
		var sweep:=space.cast_motion(query)
		var fraction: float=sweep[0] if sweep[0]<1.0 else INF
		if fraction<=1:
			result.append(start.lerp(end,maxf(0,fraction)));break
		start=end
		result.append(start)
	return result
