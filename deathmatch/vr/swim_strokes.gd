extends RefCounted
var native = ClassDB.instantiate("FPSVRInteraction") if preload("res://deathmatch/native/runtime.gd").available("FPSVRInteraction") and not OS.get_cmdline_user_args().has("--gdscript-vr-interactions") else null
## Tracking-space motion excludes virtual locomotion, turning and room rebasing.
var previous: Array[Vector3]=[]
var travel: Array[float]=[0.0,0.0]
var thrust:=Vector3.ZERO:
	get:return native.get_thrust() if native else thrust
var strength:=0.0:
	get:return native.get_strength() if native else strength
func reset() -> void:
	if native:native.swim_reset();return
	previous.clear();travel=[0.0,0.0];thrust=Vector3.ZERO;strength=0.0
func sample(head: Transform3D,left: Vector3,right: Vector3,dt: float,allowed: bool) -> Vector3:
	if native:return native.swim(head,left,right,dt,allowed)
	if not allowed or dt<=0 or dt>.1 or not head.is_finite() or not left.is_finite() or not right.is_finite():reset();return thrust
	var hands: Array[Vector3]=[left-head.origin,right-head.origin]
	if previous.is_empty():previous=hands;return thrust
	var forward: Vector3=-head.basis.z.normalized()
	var effort:=0.0
	for i in 2:
		var change: Vector3=hands[i]-previous[i]
		if change.length()>.25:reset();return thrust
		var pull: Vector3=-change/dt
		var ahead:=maxf(0,pull.dot(forward))
		var up:=maxf(0,pull.y)
		if maxf(ahead,up)>.15:
			travel[i]+=change.length()
			if travel[i]>=.035:effort+=maxf(ahead,up)
		else:travel[i]=0
	previous=hands
	# One modest arm stroke works; two arms share the same bounded speed budget.
	var desired:=clampf(effort*1.25,0,1)
	strength=lerpf(strength,desired,1-exp(-dt*(12.0 if desired>strength else 4.0)))
	thrust=forward*strength
	if thrust.length()<.01:thrust=Vector3.ZERO
	return thrust
