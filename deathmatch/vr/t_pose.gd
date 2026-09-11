extends RefCounted
## Hold a reasonably level T-pose, then lower arms before another calibration.
const HOLD_SECONDS:=1.4
var held:=0.0
var released:=0.0
var latched:=false
var cooldown:=0.0
var previous: Array[Vector3]=[]
func reset() -> void:
	held=0;released=0;previous.clear()
func sample(head: Transform3D,left: Vector3,right: Vector3,dt: float,allowed: bool) -> bool:
	cooldown=maxf(0,cooldown-dt)
	if not allowed or dt<=0 or dt>.1 or not head.is_finite() or not left.is_finite() or not right.is_finite():reset();return false
	var facing:=Basis(Vector3.UP,head.basis.get_euler().y).inverse()
	var l: Vector3=facing*(left-head.origin);var r: Vector3=facing*(right-head.origin)
	var pose: bool=head.origin.y>1.25 and head.basis.y.dot(Vector3.UP)>.94 and l.x<-.4 and r.x>.4 and l.x>-.95 and r.x<.95 and absf(l.z)<.25 and absf(r.z)<.25 and l.y>-.4 and l.y<-.07 and r.y>-.4 and r.y<-.07 and absf(l.y-r.y)<.16
	var points: Array[Vector3]=[head.origin,left,right]
	var steady:=not previous.is_empty()
	if steady:
		for i in 3:
			if points[i].distance_to(previous[i])/dt>.25:steady=false
	previous=points
	if not pose:
		held=0;released+=dt
		if released>=.7:latched=false
		return false
	released=0
	if latched or cooldown>0 or not steady:held=0;return false
	held+=dt
	if held<HOLD_SECONDS:return false
	held=0;latched=true;cooldown=5.0
	return true
