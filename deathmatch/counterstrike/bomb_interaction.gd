extends RefCounted
## Shared fictional keypad/cutter contact geometry in metres. No client-chosen
## world positions or completed progress are accepted by the authority.
const TOUCH:=.041
const WIRES=[Vector3(-.075,.182,.055),Vector3(0,.182,.055),Vector3(.075,.182,.055)]
const HOLD=Transform3D(Basis(Vector3.RIGHT,-.35),Vector3(0,.015,-.23))
static func key_point(digit: int) -> Vector3:
	return Vector3(0,-.119,.084) if digit==0 else Vector3(((digit-1)%3-1)*.067,.034-floorf((digit-1)/3.0)*.051,.084)
static func key_at(point: Vector3) -> int:
	for digit in 10:
		var offset:=point-key_point(digit)
		if absf(offset.x)<.028 and absf(offset.y)<.022 and absf(offset.z)<TOUCH:return digit
	return -1
static func wire_at(point: Vector3) -> int:
	for i in 3:
		if point.distance_to(WIRES[i])<.045:return i
	return -1
static func holster(pose: Dictionary) -> Vector3:
	var head: Transform3D=pose.get("head",Transform3D.IDENTITY)
	var yaw: float=preload("res://deathmatch/vr/body_basis.gd").head_yaw(pose)
	return head.origin+Basis(Vector3.UP,yaw)*Vector3(-.17 if pose.get("left_handed",false) else .17,-.65,-.12)
static func carried(pose: Dictionary) -> Transform3D:
	var head: Transform3D=pose.get("head",Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)))
	var yaw: float=preload("res://deathmatch/vr/body_basis.gd").head_yaw(pose)
	return Transform3D(Basis(Vector3.UP,yaw+PI),head.origin+Basis(Vector3.UP,yaw)*Vector3(0,-.38,-.24))
static func primary(pose: Dictionary) -> Transform3D:return pose.get("left" if pose.get("left_handed",false) else "right",Transform3D.IDENTITY)
static func held(pose: Dictionary) -> Transform3D:return pose.get("weapon",primary(pose))*HOLD
static func fingertip(pose: Dictionary) -> Vector3:return pose.get("offhand_weapon",Transform3D.IDENTITY)*Vector3(0,0,-.055)
static func cutter_tip(pose: Dictionary) -> Vector3:return pose.get("weapon",primary(pose))*Vector3(0,0,-.18)
