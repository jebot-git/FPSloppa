extends RefCounted
# Changes orientation only. The firing origin and all weapon rules remain shared.
var engaged:=false
var last_weapon:=-1
var blend:=0.0
func advance(delta:float) -> void:
	blend=move_toward(blend,1.0 if engaged else 0.0,delta/0.08)
static func supports(weapon:int,rules:String) -> bool:
	match rules:
		"cq":return weapon in [0,1,2,3,4,5,9,10,11,12,13,14,15,16]
		"cs16":return weapon in [3,4,5,6,7,8,9,11]
		"quake":return weapon in [2,3,4,5,6,7,8,9]
		"ut99":return weapon in [1,3,4,5,6,7,8,9,10]
		"tribes":return weapon in [0,1,2,3,4,5,6,7,8,11]
	return weapon in [1,3,4,5,6,7,8,9]
func reset() -> void:engaged=false;last_weapon=-1;blend=0.0
func solve(primary: Transform3D, support: Transform3D, weapon: int, holding: bool, valid: bool,rules: String="doom",smooth:bool=false) -> Transform3D:
	if weapon!=last_weapon:engaged=false;last_weapon=weapon;blend=0.0
	if not supports(weapon,rules) or not holding or not valid:engaged=false;blend=0.0;return primary
	var offset:=support.origin-primary.origin
	var distance:=offset.length()
	var forward:=-primary.basis.z
	var pistol:bool=rules=="cq" and weapon in [0,2,9]
	if not (rules in ["cs16","cq"] and engaged) and (distance<(.035 if pistol else .075 if rules in ["cs16","cq"] or engaged else .12) or distance>(.95 if engaged else .80) or offset.dot(forward)<(.02 if pistol else .06)):engaged=false;return primary
	var anchor:=Vector3.FORWARD*.32
	if rules=="tribes":anchor=Vector3(0,.035,-.25)*.65
	if rules in ["cs16","cq"]:
		if rules=="cq":anchor=preload("res://deathmatch/conquest/classes/models.gd").anchor(weapon,"support_anchor")*.65
		else:
			var models=preload("res://deathmatch/conquest/classes/reload_geometry.gd")
			anchor=(models.support(weapon)-models.grip(weapon))*.65
	if not engaged and offset.distance_to(primary.basis*anchor)>(.16 if rules in ["cs16","cq"] else .24):return primary
	engaged=true
	# A pistol support grip stabilizes the firing wrist; it must not rotate the
	# barrel towards the cupping hand below the weapon.
	if pistol:return primary
	if rules in ["cs16","cq"]:
		var target:=Basis(Quaternion((primary.basis*anchor).normalized(),offset.normalized()))*primary.basis if distance>.01 else primary.basis
		return Transform3D(primary.basis.slerp(target,blend) if smooth else target,primary.origin)
	var direction:=offset.normalized()
	var up:=primary.basis.y
	if absf(up.dot(direction))>.95:up=primary.basis.x
	var target:=Basis.looking_at(direction,up)
	return Transform3D(primary.basis.slerp(target,blend) if smooth else target,primary.origin)
