extends RefCounted
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
	if not data is Dictionary or data.size()<5 or data.size()>8: return {}
	for key in data:
		if key not in ["head","left","right","weapon","left_handed","body","face","offhand_weapon"]: return {}
	if not data.has("left_handed") or not data.left_handed is bool: return {}
	for key in ["head","left","right","weapon"]:
		if not valid_transform(data.get(key)): return {}
	var head: Vector3=data.head.origin
	if Vector2(head.x,head.z).length()>preload("res://deathmatch/vr/room_scale.gd").MAX_OFFSET or head.y<.35 or head.y>3.2: return {}
	for key in ["left","right"]:
		if data[key].origin.distance_to(Vector3(head.x,clampf(head.y-.45,.8,2.7),head.z))>1.55: return {}
	var hand: Transform3D=data.left if data.left_handed else data.right
	if data.weapon.origin.distance_to(hand.origin)>.4: return {}
	if data.has("offhand_weapon"):
		var offhand: Transform3D=data.right if data.left_handed else data.left
		if not valid_transform(data.offhand_weapon) or data.offhand_weapon.origin.distance_to(offhand.origin)>.4: return {}
	var result: Dictionary=data.duplicate()
	if data.has("body"):
		result.body=validate_body(data.body)
	if data.has("face"): result.face=validate_face(data.face)
	return result
static func neutral() -> Dictionary:
	return {"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.3,1.1,-.3)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.3)),"weapon":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.3)),"left_handed":false}

static func validate_body(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()>12: return {}
	var result: Dictionary={}
	for key in value:
		if key in ["left_curls","right_curls"]:
			if not value[key] is PackedFloat32Array or value[key].size()!=5: return {}
			for curl in value[key]:
				if not is_finite(curl) or curl<0 or curl>1: return {}
		elif key in ["hips","chest","left_foot","right_foot","left_knee","right_knee","left_elbow","right_elbow","left_hand","right_hand"]:
			if not valid_transform(value[key]) or value[key].origin.distance_to(Vector3(0,1,0))>2.2: return {}
		else: return {}
		result[key]=value[key]
	return result

static func validate_face(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()!=4: return {}
	if not value.get("look") is Vector2 or not value.get("blink") is Vector2: return {}
	if not value.get("gaze") is bool or not value.get("lids") is bool: return {}
	if not value.look.is_finite() or not value.blink.is_finite(): return {}
	return {"look":value.look.clamp(Vector2(-.20944,-.139626),Vector2(.20944,.139626)),"blink":value.blink.clamp(Vector2.ZERO,Vector2(.9,.9)),"gaze":value.gaze,"lids":value.lids}
