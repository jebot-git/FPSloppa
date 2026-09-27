extends RefCounted
# Changes orientation only. The firing origin and all weapon rules remain shared.
var engaged:=false
var last_weapon:=-1
func reset() -> void:engaged=false;last_weapon=-1
func solve(primary: Transform3D, support: Transform3D, weapon: int, holding: bool, valid: bool,rules: String="doom") -> Transform3D:
	if weapon!=last_weapon:engaged=false;last_weapon=weapon
	if (weapon in [0,1,2,10] if rules=="cs16" else weapon in [0,2]) or not holding or not valid:engaged=false;return primary
	var offset:=support.origin-primary.origin
	var distance:=offset.length()
	var forward:=-primary.basis.z
	if not (rules=="cs16" and engaged) and (distance<(.075 if rules=="cs16" else .12) or distance>.80 or offset.dot(forward)<.06):engaged=false;return primary
	var anchor:=Vector3.FORWARD*.32
	if rules=="cs16":
		var models=preload("res://deathmatch/counterstrike/models.gd")
		anchor=(models.support(weapon)-models.grip(weapon))*.65
	if not engaged and offset.distance_to(primary.basis*anchor)>(.16 if rules=="cs16" else .24):return primary
	engaged=true
	if rules=="cs16":return Transform3D(Basis(Quaternion((primary.basis*anchor).normalized(),offset.normalized()))*primary.basis,primary.origin) if distance>.01 else primary
	var direction:=offset.normalized()
	var up:=primary.basis.y
	if absf(up.dot(direction))>.95:up=primary.basis.x
	return Transform3D(Basis.looking_at(direction,up),primary.origin)
