extends RefCounted
## Keep the firing point on the player's side of world geometry without moving tracking.
const Hit=preload("res://deathmatch/hit_detection.gd")
static func solve(space: PhysicsDirectSpaceState3D,chest: Vector3,hand: Vector3,muzzle: Vector3,radius: float) -> Dictionary:
	var result: Dictionary={"blocked":true,"origin":hand,"clipped":false}
	if not chest.is_finite() or not hand.is_finite() or not muzzle.is_finite():return result
	var ray:=PhysicsRayQueryParameters3D.create(chest,hand,1);ray.hit_from_inside=true
	if not space.intersect_ray(ray).is_empty():return result
	# A hand can be clear while a projectile-sized sphere around it touches a wall.
	# Approach it from the clear torso side before sweeping toward the muzzle.
	var anchor:=chest
	var fraction:=Hit.world_fraction(space,chest,hand,radius)
	if fraction==0.0:return result
	anchor=backoff(chest,hand,fraction)
	fraction=Hit.world_fraction(space,anchor,muzzle,radius)
	if fraction==0.0:return result
	result.origin=backoff(anchor,muzzle,fraction)
	result.blocked=false;result.clipped=result.origin.distance_to(muzzle)>.002
	return result
static func backoff(start: Vector3,end: Vector3,fraction: float) -> Vector3:
	if not is_finite(fraction):return end
	return start.lerp(end,maxf(0,fraction-.01/maxf(start.distance_to(end),.0001)))
