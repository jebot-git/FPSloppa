extends RefCounted
## Correlated aim drift: individual precision, changing focus, no per-frame dice.
var rng:=RandomNumberGenerator.new()
var precision:=0.
var response:=0.
var lead:=0.
var phase:=0.
var started:=0.
var segment_start:=0.
var segment_end:=0.
var previous:=Vector2.ZERO
var next:=Vector2.ZERO
func _init(seed_value:int=1,now:float=0.) -> void:
	rng.seed=seed_value
	precision=deg_to_rad(rng.randf_range(.7,1.15))
	response=rng.randf_range(8.,10.)
	lead=rng.randf_range(.6,.85)
	phase=rng.randf_range(0,TAU)
	started=now;segment_start=now;segment_end=now
	next=deviation()
func deviation() -> Vector2:
	return Vector2(clampf(rng.randfn(),-2,2),clampf(rng.randfn(),-2,2)*.7)
func reaction() -> float:return rng.randf_range(.28,.52)
func offset(now:float,distance:float,motion:float) -> Vector2:
	# Idle objective guards can go minutes without aiming. Resume locally
	# instead of generating every unused drift segment in one physics tick.
	if now-segment_end>1.:
		segment_start=now;segment_end=now+rng.randf_range(.35,.8)
		previous=next;next=deviation()
	while now>=segment_end:
		segment_start=segment_end;segment_end+=rng.randf_range(.35,.8)
		previous=next;next=deviation()
	var fraction:=smoothstep(0.,1.,(now-segment_start)/(segment_end-segment_start))
	var focus:=lerpf(.65,1.65,.5+.5*sin((now-started)*1.7+phase))
	var scale:=precision*focus*lerpf(1.,1.35,clampf(motion/9.4,0,1))*distance/(distance+5.)
	return (previous.lerp(next,fraction)*scale).limit_length(deg_to_rad(3.5))
func point(origin:Vector3,target:Vector3,now:float,motion:float) -> Vector3:
	var direction:=target-origin
	var distance:=direction.length()
	var right:=direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx():right=Vector3.RIGHT
	var up:=right.cross(direction.normalized())
	var error:=offset(now,distance,motion)
	return target+(right*tan(error.x)+up*tan(error.y))*distance
