extends RefCounted
## Render-only recoil. Raw controller poses continue to drive authority/gestures.
var pitch:=0.0
var back:=0.0
func reset():pitch=0.0;back=0.0
func shot(slot: int,supported: bool):
	var strength: float=[0,2.8,3.0,5.0,3.6,1.4,2.3,1.8,2.0,4.5,4.0,1.2][clampi(slot,0,11)]
	var penalty: float=1.0 if supported or slot in [1,2,10] else 2.0
	pitch=minf(deg_to_rad(12),pitch+deg_to_rad(strength)*penalty)
	back=minf(.04,back+.009*penalty)
func update(delta: float):
	pitch*=exp(-18.0*delta);back*=exp(-22.0*delta)
func apply(pose: Transform3D) -> Transform3D:
	return Transform3D(pose.basis*Basis(Vector3.RIGHT,pitch),pose.origin+pose.basis.z*back)
