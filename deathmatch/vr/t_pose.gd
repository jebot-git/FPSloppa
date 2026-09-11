extends RefCounted
## Hold a reasonably level T-pose, then lower arms before another calibration.
const HOLD_SECONDS:=1.1
const GRACE_SECONDS:=.20
var held:=0.0
var released:=0.0
var latched:=false
var cooldown:=0.0
var previous: Array[Vector3]=[]
var unstable:=0.0
func reset() -> void:
	held=0;released=0;unstable=0;previous.clear()
func sample(head: Transform3D,left: Vector3,right: Vector3,dt: float,allowed: bool) -> bool:
	cooldown=maxf(0,cooldown-dt)
	if not allowed or dt<=0 or dt>.1 or not head.is_finite() or not left.is_finite() or not right.is_finite():reset();return false
	var facing:=Basis(Vector3.UP,head.basis.get_euler().y).inverse()
	var l: Vector3=facing*(left-head.origin);var r: Vector3=facing*(right-head.origin)
	var pose: bool=head.origin.y>1.15 and head.basis.y.dot(Vector3.UP)>.88 and l.x<-.32 and r.x>.32 and l.x> -1.15 and r.x<1.15 and r.x-l.x>.95 and absf(l.z)<.45 and absf(r.z)<.45 and l.y>-.52 and l.y<.08 and r.y>-.52 and r.y<.08 and absf(l.y-r.y)<.30
	var points: Array[Vector3]=[head.origin,l,r]
	var steady:=not previous.is_empty()
	if steady:
		for i in 3:
			# A small deadband absorbs millimetre-scale tracker noise at high refresh.
			if maxf(0,points[i].distance_to(previous[i])-.012)/dt>.65:steady=false
	previous=points
	if not pose:
		released+=dt
		if released>GRACE_SECONDS:held=0
		if released>=.55:latched=false
		return false
	released=0
	if latched or cooldown>0:held=0;return false
	if not steady:
		unstable+=dt
		if unstable>GRACE_SECONDS:held=0
		return false
	unstable=0
	held+=dt
	if held<HOLD_SECONDS:return false
	held=0;latched=true;cooldown=5.0
	return true
