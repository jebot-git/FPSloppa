extends RefCounted
## A shoulder anchor lengthens the two-hand aiming baseline. No target assistance,
## muzzle translation, controller snapping, or artificial recoil compensation.
const LONG_GUNS=[3,4,5,6,7,8,9,11]
var engaged:=false
var last_weapon:=-1
var blend:=0.0
func advance(delta:float) -> void:blend=move_toward(blend,1.0 if engaged else 0.0,delta/.08)
func reset():engaged=false;last_weapon=-1;blend=0.0
func solve(primary: Transform3D,support: Transform3D,head: Transform3D,weapon: int,left_handed: bool,valid: bool,rules:String="cs16",smooth:bool=false) -> Transform3D:
	if weapon!=last_weapon:engaged=false;last_weapon=weapon;blend=0.0
	if not valid or not preload("res://deathmatch/vr/aim_support.gd").supports(weapon,rules):engaged=false;return primary
	var look: Vector3=-head.basis.z;look.y=0
	if look.length_squared()<.001:engaged=false;return primary
	var yaw:=Basis.looking_at(look.normalized(),Vector3.UP)
	var shoulder: Vector3=head.origin+yaw*Vector3(-.18 if left_handed else .18,-.23,.10)
	var distance:=primary.origin.distance_to(shoulder)
	if distance>(.55 if engaged else .40):engaged=false;return primary
	var axis:=support.origin-shoulder
	if axis.length()<.22 or axis.dot(-primary.basis.z)<.12:engaged=false;return primary
	engaged=true
	var direction: Vector3=(-primary.basis.z).slerp(axis.normalized(),.72).normalized()
	var up: Vector3=primary.basis.y
	if absf(up.dot(direction))>.95:up=primary.basis.x
	var target:=Basis.looking_at(direction,up)
	return Transform3D(primary.basis.slerp(target,blend) if smooth else target,primary.origin)
