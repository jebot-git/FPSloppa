extends RefCounted
## Render-only recoil. Raw controller poses continue to drive authority/gestures.
var pitch:=0.0
var yaw:=0.0
var back:=0.0
var target:=Vector2.ZERO
var target_back:=0.0
var start_angles:=Vector2.ZERO
var start_back:=0.0
var pending:=false
var elapsed:=1.0
const RISE:=.025
const HOLD:=.12
func reset():
	pitch=0.0;yaw=0.0;back=0.0;target=Vector2.ZERO;target_back=0.0
	start_angles=Vector2.ZERO;start_back=0.0;pending=false;elapsed=1.0
func shot(slot: int,supported: bool,direction: Vector3=Vector3.ZERO):
	var strength: float=[0,2.8,3.0,5.0,3.6,1.4,2.3,1.8,2.0,4.5,4.0,1.2][clampi(slot,0,11)]
	var penalty: float=1.0 if supported or slot in [1,2,10] else 2.0
	target=Vector2(minf(deg_to_rad(12),pitch+deg_to_rad(strength)*penalty),0.0)
	if not direction.is_zero_approx():
		# The authority supplies the upcoming shot's direction in sight space.
		var ray:=direction.normalized()
		target=Vector2(asin(clampf(ray.y,-1,1)),atan2(-ray.x,-ray.z))
	target_back=minf(.04,back+.009*penalty)
	start_angles=Vector2(pitch,yaw);start_back=back;pending=true;elapsed=0.0
func update(delta: float):
	# Present the shot/flash at the old pose for one frame before kicking.
	if pending:pending=false;return
	var previous:=elapsed;elapsed+=delta
	if elapsed<HOLD:
		var weight:=smoothstep(0.0,RISE,elapsed)
		var angles:=start_angles.lerp(target,weight)
		pitch=angles.x;yaw=angles.y;back=lerpf(start_back,target_back,weight)
	else:
		if previous<HOLD:pitch=target.x;yaw=target.y;back=target_back
		var recovery:=elapsed-maxf(previous,HOLD)
		pitch*=exp(-18.0*recovery);yaw*=exp(-18.0*recovery);back*=exp(-22.0*recovery)
func apply(pose: Transform3D) -> Transform3D:
	return Transform3D(pose.basis*Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch),pose.origin+pose.basis.z*back)
