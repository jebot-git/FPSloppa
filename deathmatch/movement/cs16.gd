extends RefCounted
## Independent CS 1.6 movement model; numerical references and adaptation limits
## are documented in docs/BOMB-DEFUSAL.md. BSP coordinates use 32 units/metre.
const UNITS:=32.0
const GRAVITY:=800.0/UNITS
const JUMP_SPEED:=268.3281573/UNITS # sqrt(2 * 800 * 45)
const STEP_HEIGHT:=18.0/UNITS
const GROUND_ACCELERATION:=5.0
const AIR_ACCELERATION:=10.0
const AIR_WISH_CAP:=30.0/UNITS
const FRICTION:=4.0
const STOP_SPEED:=75.0/UNITS
const WALK_SCALE:=.52
const DUCK_SCALE:=.333
const JUMP_STAMINA:=1.315789429
const MAX_VELOCITY:=2000.0/UNITS

static func stamina_ratio(remaining: float) -> float:return maxf(0,1.0-.19*remaining)

static func horizontal(velocity: Vector2,wish: Vector2,max_speed: float,grounded: bool,delta: float,stamina: float=0.0,edge: bool=false) -> Vector2:
	var speed:=velocity.length()
	var strength:=minf(wish.length(),1.0)
	if grounded and speed>0:
		# Analog sticks need a scaled stop threshold at partial deflection.
		var stop:=minf(STOP_SPEED,max_speed*strength) if strength>0 and strength<1 else STOP_SPEED
		velocity*=maxf(0,speed-maxf(speed,stop)*FRICTION*(2.0 if edge else 1.0)*delta)/speed
		# GoldSrc's jump fatigue is frame-based. Normalize it to the conventional
		# 100 Hz command rate so server tick rate and headset refresh cannot alter it.
		velocity*=pow(stamina_ratio(stamina),delta*100.0)
	if strength>0:
		var direction:=wish.normalized()
		var requested:=max_speed*strength
		var available:=(requested if grounded else minf(requested,AIR_WISH_CAP))-velocity.dot(direction)
		if available>0:
			velocity+=direction*minf(available,(GROUND_ACCELERATION if grounded else AIR_ACCELERATION)*requested*delta)
	if grounded and velocity.length()<1.0/UNITS:return Vector2.ZERO
	return velocity

static func jump_limit(velocity: Vector2,max_speed: float) -> Vector2:
	return velocity.normalized()*max_speed*1.2*.8 if velocity.length()>max_speed*1.2 else velocity

static func near_edge(actor,velocity: Vector2) -> bool:
	if velocity.is_zero_approx():return false
	var ahead: Vector3=actor.global_position+Vector3(velocity.x,0,velocity.y).normalized()*(16.0/UNITS)+Vector3.UP*.02
	var query:=PhysicsRayQueryParameters3D.create(ahead,ahead-Vector3.UP*(34.0/UNITS),3,[actor.get_rid()])
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

static func water_velocity(velocity: Vector3,wish: Vector3,max_speed: float,delta: float,jump: bool) -> Vector3:
	if jump:velocity.y=100.0/UNITS
	var requested:=wish.limit_length(1)*max_speed
	if requested.is_zero_approx():requested.y=-60.0/UNITS
	velocity*=maxf(0,1-FRICTION*delta)
	var speed:=requested.length()*.8
	var available:=speed-velocity.length()
	if available>0:velocity+=requested.normalized()*minf(available,GROUND_ACCELERATION*speed*delta)
	return velocity

static func simulate(actor,direction: Vector3,slow: bool,delta: float,jump: bool,swim: Vector3) -> void:
	actor.cs16_stamina=maxf(0,actor.cs16_stamina-delta)
	# CS impulses are ordinary velocity, subject to the same ground/air rules.
	actor.blast_velocity=Vector2.ZERO
	actor.jump_queued=false
	var grounded: bool=actor.is_supported() and actor.velocity.y<=0
	var jumping: bool=grounded and jump and not actor.jump_held and not actor.in_water
	actor.jump_held=jump # Pressing in the air is consumed, never buffered to landing.
	var before_y: float=actor.position.y
	var horizontal_velocity:=Vector2(actor.velocity.x,actor.velocity.z)
	if actor.in_water:
		var stroke: Vector3=actor.basis*swim.limit_length(1) if swim.is_finite() else Vector3.ZERO
		actor.velocity=water_velocity(actor.velocity,(direction+stroke).limit_length(1),actor.movement_speed(slow),delta,jump)
	else:
		if jumping:
			horizontal_velocity=jump_limit(horizontal_velocity,actor.cs16_max_speed)
			actor.velocity.y=JUMP_SPEED*stamina_ratio(actor.cs16_stamina)
			actor.cs16_stamina=JUMP_STAMINA
		var walking:=grounded and not jumping
		horizontal_velocity=horizontal(horizontal_velocity,Vector2(direction.x,direction.z),actor.movement_speed(slow),walking,delta,actor.cs16_stamina,walking and near_edge(actor,horizontal_velocity))
		actor.velocity.x=horizontal_velocity.x;actor.velocity.z=horizontal_velocity.y
		actor.velocity.y=-.2 if walking else maxf(-MAX_VELOCITY,actor.velocity.y-GRAVITY*delta*.5)
	actor.velocity=actor.velocity.clamp(Vector3.ONE*-MAX_VELOCITY,Vector3.ONE*MAX_VELOCITY)
	var stepping: bool=grounded and not jumping and not actor.in_water
	actor.floor_grace=0 # No coyote time or stair assistance after leaving the floor.
	actor.stepped_last_frame=stepping and actor.step_up(Vector3(actor.velocity.x,0,actor.velocity.z)*delta,STEP_HEIGHT)
	var impact: float=actor.velocity.y
	if not actor.stepped_last_frame:actor.move_and_slide()
	if stepping and not actor.is_supported():actor.apply_floor_snap()
	if not actor.in_water:
		if actor.is_supported() and actor.velocity.y<=0:actor.velocity.y=0
		else:actor.velocity.y=maxf(-MAX_VELOCITY,actor.velocity.y-GRAVITY*delta*.5)
	if jumping and actor.velocity.y>0:actor.emit_movement_sound("jump",actor.global_position+Vector3.UP*.65)
	elif not grounded and actor.is_supported() and impact < -250.0/UNITS and not actor.in_water:actor.emit_movement_sound("land",actor.global_position+Vector3.UP*.2)
	if stepping and actor.is_supported() and absf(actor.position.y-before_y)<=STEP_HEIGHT+.05:
		actor.view_offset=clampf(actor.view_offset+before_y-actor.position.y,-STEP_HEIGHT,STEP_HEIGHT)
