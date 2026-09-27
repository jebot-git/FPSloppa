extends RefCounted
## Pelvis attachment frame, adapted from raifslop's integration hip_mount.
## Poses are already normalized and expressed relative to the player's capsule.
static func tracked(pose: Dictionary) -> bool:
	return pose.get("body",{}).get("hips") is Transform3D

static func frame(pose: Dictionary) -> Transform3D:
	var head: Transform3D=pose.head
	var source: Transform3D=pose.body.hips if tracked(pose) else head
	var at:=source.origin
	if not tracked(pose):at.y-=clampf(head.origin.y*.4,.23,.65)
	# Keep the belt upright when the pelvis pitches/rolls. Looking around must
	# not steer an available hip tracker; flatten its own facing instead.
	var facing:=Vector3(source.basis.z.x,0,source.basis.z.z)
	if facing.length_squared()<.001:facing=Vector3(source.basis.x.x,0,source.basis.x.z).cross(Vector3.UP)
	return Transform3D(Basis(Vector3.UP,atan2(facing.x,facing.z)),at)

static func offhand_side(pose: Dictionary) -> float:
	return 1.0 if pose.left_handed else -1.0

static func pouch(pose: Dictionary) -> Transform3D:
	var hip:=frame(pose);var side:=offhand_side(pose)
	# Back/belt loops face the body; the fabric front faces out from either hip.
	return hip*Transform3D(Basis(Vector3.UP,-side*PI/2),Vector3(side*.29,-.035,0))

static func recovery_contains(pose: Dictionary,point: Vector3) -> bool:
	var local: Vector3=frame(pose).affine_inverse()*point
	# The entire offhand belt side is usable: front, flank and behind the hip.
	# Keep it below the ribs, above the thigh, and out of the opposite hip.
	return point.is_finite() and local.x*offhand_side(pose)>.025 and local.y>=-.28 and local.y<=.24 and Vector2(local.x/.58,local.z/.48).length_squared()<=1.0
