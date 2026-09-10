## Frozen 0.5v (cec9edd) narrow-phase reference; keep unoptimized for equivalence checks.
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

static func capsule_fraction(start: Vector3, end: Vector3, radius: float = PLAYER_RADIUS) -> float:
	var motion := end-start
	var closest := Vector3(0,clampf(start.y,PLAYER_BOTTOM,PLAYER_TOP),0)
	if start.distance_squared_to(closest)<=radius*radius: return 0.0
	var first := minf(sphere_fraction(start,motion,Vector3.UP*PLAYER_BOTTOM,radius),sphere_fraction(start,motion,Vector3.UP*PLAYER_TOP,radius))
	var a := motion.x*motion.x+motion.z*motion.z
	if a>1e-12:
		var b := start.x*motion.x+start.z*motion.z
		var c := start.x*start.x+start.z*start.z-radius*radius
		var discriminant := b*b-a*c
		if discriminant>=0:
			var t := (-b-sqrt(discriminant))/a
			var height := start.y+motion.y*t
			if t>=0 and t<=1 and height>=PLAYER_BOTTOM and height<=PLAYER_TOP: first=minf(first,t)
	return first
