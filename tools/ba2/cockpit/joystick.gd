extends RefCounted
## Position-driven circular gate, independent of controller wrist orientation
## and the much smaller mechanical travel of the robot's cannon hinges.
const RADIUS := .11
const DEADZONE := .12
const VISUAL_TILT := deg_to_rad(24.0)

static func axis(displacement: Vector3) -> Vector2:
	if not displacement.is_finite():return Vector2.ZERO
	var planar:=Vector2(displacement.x,-displacement.z)/RADIUS
	var distance:=planar.length()
	if distance<=DEADZONE:return Vector2.ZERO
	# Rescale the remaining radius so crossing the centre deadzone does not
	# abruptly jump to 12% input. Diagonals share the same circular boundary.
	return planar/distance*clampf((distance-DEADZONE)/(1.0-DEADZONE),0,1)

static func tilt(input: Vector2) -> Quaternion:
	if not input.is_finite():return Quaternion.IDENTITY
	var bounded:=input.limit_length()
	var angle:=bounded.length()*VISUAL_TILT
	var direction:=bounded.normalized()
	var shaft:=Vector3(direction.x*sin(angle),cos(angle),-direction.y*sin(angle))
	return Quaternion(Vector3.UP,shaft)
