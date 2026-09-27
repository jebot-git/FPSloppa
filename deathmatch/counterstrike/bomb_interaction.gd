extends RefCounted
## Shared fictional keypad/cutter contact geometry in metres. No client-chosen
## world positions or completed progress are accepted by the authority.
const Hip=preload("res://deathmatch/vr/hip_mount.gd")
const CARRIED_SCALE:=.4
const CHEST_DROP:=.08
const KEY_SIZE=Vector3(.054,.040,.015) # Matches the authored Blender keycaps.
const FINGER_RADIUS:=.005
const FRONT:=.0845
const RELEASE_DEPTH:=.103
const WIRES=[Vector3(-.075,.182,.055),Vector3(0,.182,.055),Vector3(.075,.182,.055)]
const HOLD=Transform3D(Basis(Vector3.RIGHT,-.20),Vector3(-.115,.16,-.12))
static func hold_offset(left_handed: bool) -> Transform3D:
	var result:=HOLD
	if left_handed:result.origin.x=-result.origin.x
	return result
static func key_point(digit: int) -> Vector3:
	return Vector3(0,-.119,.084) if digit==0 else Vector3(((digit-1)%3-1)*.067,.034-floorf((digit-1)/3.0)*.051,.084)
static func key_at(point: Vector3) -> int:
	for digit in 10:
		if key_box(digit).grow(FINGER_RADIUS).has_point(point):return digit
	return -1
static func key_box(digit: int) -> AABB:
	var center:=key_point(digit);center.z=.077
	return AABB(center-KEY_SIZE*.5,KEY_SIZE)
static func press(previous: Vector3,current: Vector3) -> int:
	# Front-to-back contact only, with a small fingertip radius. A side sweep,
	# stale sample, controller teleport or touch through the backing cannot type.
	if not previous.is_finite() or not current.is_finite() or previous.distance_to(current)>.25 or previous.z<FRONT+FINGER_RADIUS or current.z>=previous.z:return -1
	var plane:=FRONT+FINGER_RADIUS
	if current.z>plane:return -1
	var contact:=previous.lerp(current,(previous.z-plane)/(previous.z-current.z))
	for digit in 10:
		var box:=key_box(digit).grow(FINGER_RADIUS)
		if contact.x>=box.position.x and contact.x<=box.end.x and contact.y>=box.position.y and contact.y<=box.end.y:return digit
	return -1
static func wire_at(point: Vector3) -> int:
	for i in 3:
		if point.distance_to(WIRES[i])<.045:return i
	return -1
static func holster(pose: Dictionary) -> Vector3:
	return tool_carried(pose).origin
static func chest(pose: Dictionary) -> Transform3D:
	if pose.is_empty():pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left_handed":false}
	return Hip.chest(pose)
static func tool_carried(pose: Dictionary) -> Transform3D:
	# Mount below the aiming hands, following the same tracked torso frame.
	return chest(pose)*Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(-.17 if pose.get("left_handed",false) else .17,.07-CHEST_DROP,-.15))
static func carried(pose: Dictionary) -> Transform3D:
	return chest(pose)*Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*CARRIED_SCALE),Vector3(0,-.035-CHEST_DROP,-.15))
static func primary(pose: Dictionary) -> Transform3D:return pose.get("left" if pose.get("left_handed",false) else "right",Transform3D.IDENTITY)
static func held(pose: Dictionary) -> Transform3D:return pose.get("weapon",primary(pose))*hold_offset(pose.get("left_handed",false))
static func fingertip(pose: Dictionary) -> Vector3:
	return pose.get("index_tip",pose.get("offhand_weapon",Transform3D.IDENTITY)*Vector3(0,0,-.055))
static func cutter_tip(pose: Dictionary) -> Vector3:return pose.get("weapon",primary(pose))*Vector3(0,0,-.18)
