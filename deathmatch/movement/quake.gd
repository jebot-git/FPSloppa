extends RefCounted
## Godot 4 adaptation of rhulha/quake3-movement-godot (MIT; see LICENSE.txt).
## Pure shared movement math: server, client prediction, bots and VR use the same path.
const GROUND_ACCELERATION:=14.0
const AIR_ACCELERATION:=2.0
const AIR_DECELERATION:=2.0
const FRICTION:=6.0
const STOP_SPEED:=10.0

static func horizontal(velocity: Vector2,wish: Vector2,move_speed: float,grounded: bool,jumping: bool,delta: float) -> Vector2:
	var strength:=minf(wish.length(),1.0)
	if grounded and not jumping:
		# A fixed keyboard stop speed would overpower acceleration at small stick deflections.
		var stop_speed:=minf(STOP_SPEED,move_speed*strength) if strength>.0001 else STOP_SPEED
		velocity=friction(velocity,delta,stop_speed)
	# Unlike the original demo, assign normalization and retain analog input strength.
	if strength<=.0001:return velocity
	var direction:=wish.normalized()
	var acceleration:=GROUND_ACCELERATION if grounded else (AIR_DECELERATION if velocity.dot(direction)<0 else AIR_ACCELERATION)
	return accelerate(velocity,direction,move_speed*strength,acceleration,delta)

static func friction(velocity: Vector2,delta: float,stop_speed: float=STOP_SPEED) -> Vector2:
	var speed:=velocity.length()
	if speed<=.0001:return Vector2.ZERO
	var remaining:=maxf(0,speed-maxf(speed,stop_speed)*FRICTION*delta)
	return velocity*(remaining/speed)

static func accelerate(velocity: Vector2,direction: Vector2,wish_speed: float,acceleration: float,delta: float) -> Vector2:
	# Limit acceleration along the requested direction, retaining perpendicular momentum.
	var available:=wish_speed-velocity.dot(direction)
	if available<=0:return velocity
	return velocity+direction*minf(available,acceleration*delta*wish_speed)
