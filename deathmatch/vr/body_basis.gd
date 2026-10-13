extends RefCounted
static func head_yaw(pose: Dictionary,previous: float=0.0) -> float:
	if not pose.has("head"):return 0.0
	var forward: Vector3=-pose.head.basis.z
	if Vector2(forward.x,forward.z).length_squared()<.0001:return previous
	return atan2(-forward.x,-forward.z)
