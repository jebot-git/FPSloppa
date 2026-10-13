extends RefCounted
const MIN_HEAD_HEIGHT:=.05 # A prone headset can sit only a few centimetres above the floor.
static func held_weapon(grip: Transform3D, aim: Transform3D) -> Transform3D:
	# Position at the palm, but preserve the runtime's independent aim direction.
	return Transform3D(aim.basis,grip.origin)

## Pose validation bounds room-scale requests; movement still uses the shared capsule.
static func valid_transform(value: Variant) -> bool:
	if not value is Transform3D or not value.origin.is_finite() or not value.basis.is_finite(): return false
	if absf(value.basis.determinant()-1.0)>.05: return false
	for axis in [value.basis.x,value.basis.y,value.basis.z]:
		if absf(axis.length()-1.0)>.02: return false
	return absf(value.basis.x.dot(value.basis.y))<.02 and absf(value.basis.x.dot(value.basis.z))<.02 and absf(value.basis.y.dot(value.basis.z))<.02
static func validate(data: Variant) -> Dictionary:
	if not data is Dictionary or data.size()<5 or data.size()>7: return {}
	for key in data:
		if key not in ["head","left","right","weapon","left_handed","offhand_weapon","height"]: return {}
	if not data.has("left_handed") or not data.left_handed is bool: return {}
	for key in ["head","left","right","weapon"]:
		if not valid_transform(data.get(key)): return {}
	var head: Vector3=data.head.origin
	if Vector2(head.x,head.z).length()>preload("res://deathmatch/vr/room_scale.gd").MAX_OFFSET or head.y<MIN_HEAD_HEIGHT or head.y>3.2: return {}
	for key in ["left","right"]:
		if data[key].origin.distance_to(Vector3(head.x,clampf(head.y-.45,.25,2.7),head.z))>1.55: return {}
	var hand: Transform3D=data.left if data.left_handed else data.right
	if data.weapon.origin.distance_to(hand.origin)>.4: return {}
	if data.has("offhand_weapon"):
		var offhand: Transform3D=data.right if data.left_handed else data.left
		if not valid_transform(data.offhand_weapon) or data.offhand_weapon.origin.distance_to(offhand.origin)>.4: return {}
	var result: Dictionary=data.duplicate()
	if data.has("height"):
		if not (data.height is float or data.height is int) or not is_finite(float(data.height)):return {}
		result.height=clampf(float(data.height),.80,1.65)
	return result
static func neutral() -> Dictionary:
	return {"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.3,1.1,-.3)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.3)),"weapon":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.3)),"left_handed":false}

static func gameplay(data:Dictionary) -> Dictionary:
	return validate(data)
