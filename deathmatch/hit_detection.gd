extends RefCounted
## Shared placeholder damage volumes, independent of cosmetic avatars and locomotion.
const PLAYER_RADIUS := .40 # Legacy capsule primitive (also used for buildings).
const PLAYER_REACH := 1.5 # Conservative horizontal bound, including prone limbs.
const Body = preload("res://deathmatch/avatars/hit_body.gd")
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

# Slab entry into a box. A sphere sweep uses rounded faces/edges/corners,
# rather than a larger rectangular box that would count empty corner space.
static func box_fraction(start: Vector3,end: Vector3,half: Vector3,radius: float=0.0) -> float:
	var motion:=end-start
	var enter:=0.0;var leave:=1.0
	for axis in 3:
		var extent: float=half[axis]+radius+.000001
		if absf(motion[axis])<1e-10:
			if absf(start[axis])>extent:return INF
		else:
			var a: float=(-extent-start[axis])/motion[axis]
			var b: float=(extent-start[axis])/motion[axis]
			enter=maxf(enter,minf(a,b));leave=minf(leave,maxf(a,b))
			if enter>leave:return INF
	if radius<=0:return enter
	# Distance to a box is piecewise quadratic. Split at its six face planes,
	# then solve the sphere-contact quadratic on each interval exactly.
	var cuts: Array[float]=[enter,leave]
	for axis in 3:
		if absf(motion[axis])<1e-10:continue
		for sign_side in [-1.0,1.0]:
			var t: float=(sign_side*half[axis]-start[axis])/motion[axis]
			if t>enter and t<leave:cuts.append(t)
	cuts.sort()
	if start.lerp(end,enter).distance_squared_to(start.lerp(end,enter).clamp(-half,half))<=radius*radius+1e-10:return enter
	for i in cuts.size()-1:
		var low:=cuts[i];var high:=cuts[i+1];var mid:=start.lerp(end,(low+high)*.5)
		var offset:=Vector3.ZERO;var velocity:=Vector3.ZERO
		for axis in 3:
			if absf(mid[axis])>half[axis]:
				offset[axis]=start[axis]-signf(mid[axis])*half[axis];velocity[axis]=motion[axis]
		var a:=velocity.length_squared();var b:=offset.dot(velocity);var c:=offset.length_squared()-radius*radius
		if a<1e-12:continue
		var discriminant:=b*b-a*c
		if discriminant<0:continue
		var contact:=(-b-sqrt(discriminant))/a
		if contact>=low-1e-7 and contact<=high+1e-7:return clampf(contact,low,high)
	return INF

static func player_fraction(start: Vector3,end: Vector3,height: float=1.65,yaw: float=0.0,radius: float=0.0) -> float:
	var inverse:=Basis(Vector3.UP,-yaw)
	start=inverse*start;end=inverse*end
	if not is_finite(box_fraction(start-Vector3.UP*.80,end-Vector3.UP*.80,Vector3(PLAYER_REACH,.90,PLAYER_REACH),radius)):return INF
	var first:=INF
	for part in Body.parts(height):
		var transform: Transform3D=part.pose.affine_inverse()
		first=minf(first,box_fraction(transform*start,transform*end,part.size*.5,radius))
	return first

static func player_axis(impact: Vector3,height: float,yaw: float) -> Vector3:
	# Cover rays reach the body axis at the struck part's height. This prevents
	# a shoulder protruding through thin cover from making its owner hittable.
	var basis:=Basis(Vector3.UP,yaw);var local:=basis.inverse()*impact
	var closest:=Vector3.ZERO;var distance:=INF
	for part in Body.parts(height):
		var pose: Transform3D=part.pose
		var point: Vector3=pose*((pose.affine_inverse()*local).clamp(-part.size*.5,part.size*.5))
		var gap:=local.distance_squared_to(point)
		if gap<distance:distance=gap;closest=pose.origin
	return Vector3(0,closest.y,0) # Keep protruding limbs behind cover when the body is behind it.

static func player_head(point: Vector3,height: float,yaw: float,radius: float=0.0) -> bool:
	var head: Dictionary=Body.parts(height)[1]
	var local: Vector3=head.pose.affine_inverse()*(Basis(Vector3.UP,-yaw)*point)
	return local.distance_squared_to(local.clamp(-head.size*.5,head.size*.5))<=radius*radius+1e-8

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
