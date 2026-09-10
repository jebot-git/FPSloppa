extends RefCounted
# Changes orientation only. The firing origin and all weapon rules remain shared.
var engaged:=false
var last_weapon:=-1
func reset() -> void:engaged=false;last_weapon=-1
func solve(primary: Transform3D, support: Transform3D, weapon: int, holding: bool, valid: bool) -> Transform3D:
	if weapon!=last_weapon:engaged=false;last_weapon=weapon
	if weapon in [0,2] or not holding or not valid:engaged=false;return primary
	var offset:=support.origin-primary.origin
	var distance:=offset.length()
	var forward:=-primary.basis.z
	if distance<.12 or distance>.80 or offset.dot(forward)<.06:engaged=false;return primary
	if not engaged and offset.distance_to(forward*.32)>.24:return primary
	engaged=true
	var direction:=offset.normalized()
	var up:=primary.basis.y
	if absf(up.dot(direction))>.95:up=primary.basis.x
	return Transform3D(Basis.looking_at(direction,up),primary.origin)
