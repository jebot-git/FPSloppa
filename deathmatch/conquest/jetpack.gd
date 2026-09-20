extends RefCounted
## Shared authority/prediction physics. Distances are actual horizontal path length,
## not distance from the origin, so steering cannot extend the 48 m safety budget.
const DOUBLE_TAP:=.30
const COOLDOWN:=8.0
const RANGE:=48.0
const SPEED:=16.0
const LIFT:=12.0
const GRAVITY:=12.0
const BURN_TIME:=2.0
const TURN_RATE:=PI/10.0 # 18 degrees/second; no instant reversal.
static func fresh() -> Dictionary:
	return {"mode":0,"age":0.0,"cooldown":0.0,"tap":0.0,"distance":0.0,"heading":Vector2.ZERO,"activation":0,"time":0.0}
static func tick(actor,direction: Vector3,delta: float,jump: bool) -> bool:
	var s: Dictionary=actor.jetpack_state
	s.time+=delta;s.cooldown=maxf(0,s.cooldown-delta);s.tap=maxf(0,s.tap-delta)
	var pressed: bool=jump and not actor.jump_held
	var request: bool=actor.jetpack_requested
	actor.jetpack_requested=false
	if not actor.jetpack_enabled:return false
	if actor.jetpack_blocked or actor.in_water or actor.frozen or actor.spectator or actor.stance=="prone":
		s.tap=0
		if actor.in_water or actor.frozen or actor.spectator:s.mode=0
		pressed=false;request=false
	var double: bool=pressed and s.tap>0
	if pressed:s.tap=DOUBLE_TAP
	if (double or request) and s.cooldown<=0 and s.mode==0:
		s.mode=1 if Vector2(direction.x,direction.z).length()>.15 else 2
		s.heading=Vector2(direction.x,direction.z).normalized();s.age=0.0;s.distance=0.0;s.cooldown=COOLDOWN;s.tap=0.0;s.activation+=1
		actor.blast_velocity=Vector2.ZERO
		actor.velocity=Vector3(s.heading.x*SPEED,LIFT,s.heading.y*SPEED) if s.mode==1 else Vector3(0,8,0)
	if s.mode==0:return false
	var old_age: float=s.age;s.age+=delta
	if s.mode==1:
		var wish:=Vector2(direction.x,direction.z)
		if wish.length()>.15 and not actor.jetpack_blocked:
			var angle: float=s.heading.angle_to(wish.normalized())
			s.heading=s.heading.rotated(clampf(angle,-TURN_RATE*delta,TURN_RATE*delta)).normalized()
		var speed:=maxf(0,SPEED-maxf(0,s.age-BURN_TIME)*12.0)
		speed=minf(speed,maxf(0,RANGE-s.distance)/delta)
		actor.velocity.x=s.heading.x*speed;actor.velocity.z=s.heading.y*speed
		actor.velocity.y=maxf(-30,actor.velocity.y-(GRAVITY if old_age<BURN_TIME else 20.0)*delta)
	else:
		actor.velocity.x=0;actor.velocity.z=0
		if s.age<.7:actor.velocity.y=maxf(0,8.0*(1.0-s.age/.7))
		elif s.age<1.5:actor.velocity.y=0
		else:actor.velocity.y=maxf(-30,actor.velocity.y-20.0*delta)
	actor.jump_queued=false;actor.floor_grace=0;actor.stepped_last_frame=false
	return true
static func moved(actor,before: Vector3) -> void:
	var s: Dictionary=actor.jetpack_state
	s.distance+=Vector2(actor.position.x-before.x,actor.position.z-before.z).length()
	if actor.is_on_ceiling() and s.mode==2 and s.age<.7:s.age=.7
	if actor.is_on_floor() and actor.velocity.y<=0:
		s.mode=0;s.tap=0.0
		# A landing must not preserve boost speed as unlimited bunny-hop momentum.
		var horizontal:=Vector2(actor.velocity.x,actor.velocity.z).limit_length(9.4)
		actor.velocity.x=horizontal.x;actor.velocity.z=horizontal.y
static func reconcile(actor,authority: Dictionary,reference: Dictionary={}) -> void:
	if authority.is_empty():return
	var current: Dictionary=actor.jetpack_state
	if not reference.is_empty() and current.activation>reference.activation:return # A newer, unacknowledged local takeoff.
	var elapsed:=maxf(0,float(current.time)-float(reference.get("time",current.time)))
	var next: Dictionary=authority.duplicate(true)
	next.cooldown=maxf(0,next.cooldown-elapsed);next.time=current.time
	if not reference.is_empty() and authority.activation==reference.activation and authority.mode==reference.mode:
		next.age=current.age;next.heading=current.heading;next.tap=current.tap
		next.distance=authority.distance+maxf(0,float(current.distance)-float(reference.distance))
		if current.mode==0 and actor.is_supported():next.mode=0
	else:
		next.age+=elapsed;next.tap=maxf(0,next.tap-elapsed)
	actor.jetpack_state=next
static func status(state: Dictionary) -> String:
	if state.mode!=0:return "JETPACK · HOVER" if state.mode==2 and state.age<1.5 else "JETPACK · IN FLIGHT"
	if state.cooldown>0:return "JETPACK · READY IN %.1fs"%state.cooldown
	return "JETPACK READY · DOUBLE-TAP JUMP"
