extends RefCounted
## Palm-origin CQ models share the authored well and charging-lever anchors.
static func ammo_basis(_w:int) -> Basis:return Basis.IDENTITY
static func ammo_contact(hand:Transform3D,_w:int) -> Vector3:return hand.origin
static func support(_w:int) -> Vector3:return Vector3(0,.015,-.15)
static func grip(_w:int) -> Vector3:return Vector3.ZERO
static func muzzle(_w:int) -> Vector3:return Vector3(0,.12,-.35)
