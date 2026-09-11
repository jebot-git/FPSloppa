extends RefCounted
## Common damage capsule, independent of avatar shape and movement collision.
const PLAYER_RADIUS := .40
const PLAYER_BOTTOM := .40
const PLAYER_TOP := 1.40

static func sphere_fraction(start: Vector3, motion: Vector3, center: Vector3, radius: float) -> float:
	var offset := start-center
	var c := offset.length_squared()-radius*radius
	if c<=0: return 0.0
	var a := motion.length_squared()
	if a<1e-12: return INF
	var b := offset.dot(motion)
	var discriminant := b*b-a*c
	if discriminant<0: return INF
	var t := (-b-sqrt(discriminant))/a
	return t if t>=0 and t<=1 else INF

static func capsule_fraction(start: Vector3, end: Vector3, radius: float = PLAYER_RADIUS,top: float=PLAYER_TOP) -> float:
	# Conservative bounds on the whole relative-motion segment. Most projectile /
	# player pairs are far apart; reject them before the sphere roots and cylinder
	# solve. Test both endpoints so a fast crossing can never be culled as distant.
	var bound:=radius+.000001
	if minf(start.x,end.x)>bound or maxf(start.x,end.x)<-bound: return INF
	if minf(start.z,end.z)>bound or maxf(start.z,end.z)<-bound: return INF
	if minf(start.y,end.y)>top+bound or maxf(start.y,end.y)<PLAYER_BOTTOM-bound: return INF
	var motion := end-start
	var closest := Vector3(0,clampf(start.y,PLAYER_BOTTOM,top),0)
	if start.distance_squared_to(closest)<=radius*radius: return 0.0
	var first := minf(sphere_fraction(start,motion,Vector3.UP*PLAYER_BOTTOM,radius),sphere_fraction(start,motion,Vector3.UP*top,radius))
	var a := motion.x*motion.x+motion.z*motion.z
	if a>1e-12:
		var b := start.x*motion.x+start.z*motion.z
		var c := start.x*start.x+start.z*start.z-radius*radius
		var discriminant := b*b-a*c
		if discriminant>=0:
			var t := (-b-sqrt(discriminant))/a
			var height := start.y+motion.y*t
			if t>=0 and t<=1 and height>=PLAYER_BOTTOM and height<=top: first=minf(first,t)
	return first

static func world_fraction(space: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3, radius: float) -> float:
	if radius<=0:
		var ray := PhysicsRayQueryParameters3D.create(start,end,1)
		ray.hit_from_inside=true
		var wall := space.intersect_ray(ray)
		return start.distance_to(wall.position)/maxf(start.distance_to(end),.00001) if not wall.is_empty() else INF
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius=radius
	query.shape=sphere
	query.transform=Transform3D(Basis.IDENTITY,start)
	query.collision_mask=1
	query.margin=.001
	# cast_motion ignores initial overlaps; catch a muzzle already touching a wall.
	if not space.intersect_shape(query,1).is_empty(): return 0.0
	query.motion=end-start
	var fractions := space.cast_motion(query)
	return fractions[0] if fractions[0]<1.0 else INF
