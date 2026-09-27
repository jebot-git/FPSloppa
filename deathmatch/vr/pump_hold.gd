extends RefCounted
## M3 palm-to-fore-end offset in tracked metres, shared by pose validation and
## local presentation. The authority still requires a held pump and full cycle.
const OFFSET:=Vector3(0,.025,-.538)*.65
const TRAVEL:=.105*.65
static func weapon(support: Transform3D,basis: Basis,stroke: float) -> Transform3D:
	return Transform3D(basis,support.origin-basis*(OFFSET+Vector3.BACK*TRAVEL*stroke))
static func attached(pose: Dictionary) -> bool:
	var hand: Transform3D=pose.right if pose.left_handed else pose.left
	var at: Vector3=pose.weapon.affine_inverse()*hand.origin-OFFSET
	return Vector2(at.x,at.y).length()<.08 and at.z>=-.05 and at.z<=TRAVEL+.05
