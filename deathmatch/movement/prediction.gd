extends RefCounted
## Compare authority with the saved state of its acknowledged input, never with
## a newer jump/turn. Bounded history; the server still owns collisions and damage.
const CAPACITY=180
const MAX_REPLAY_TICKS=32
var samples: Dictionary={}
var acknowledged:=-1
var pending_authority:Dictionary={}
var stats: Dictionary={"corrections":0,"resets":0,"max_error":0.0}

func clear() -> void:
	samples.clear();acknowledged=-1;pending_authority={}

func remember(sequence: int,position: Vector3,velocity: Vector3,height: float=-1.0,jetpack: Dictionary={},tribes: Dictionary={},command: Dictionary={},simulation:Dictionary={}) -> void:
	samples[sequence]={"position":position,"velocity":velocity,"height":height,"jetpack":jetpack.duplicate(true),"tribes":tribes.duplicate(true),"command":command.duplicate(true),"simulation":simulation.duplicate(true)}
	while samples.size()>CAPACITY:samples.erase(samples.keys()[0])

func reconcile(actor,sequence: int,position: Vector3,velocity: Vector3,height: float=-1.0,grounded: bool=false,jetpack: Dictionary={},tribes: Dictionary={}) -> void:
	if sequence<=acknowledged:return
	acknowledged=sequence
	if actor.tribes_enabled and actor.Tribes.valid_state(tribes):
		replay_tribes(actor,sequence,position,velocity,height,tribes)
		return
	if not samples.has(sequence):
		if not jetpack.is_empty():actor.Jetpack.reconcile(actor,jetpack)
		if not tribes.is_empty():actor.Tribes.reconcile(actor,tribes)
		# History loss/reconnect: only a substantial divergence warrants a reset.
		if actor.position.distance_to(position)>2.5:
			actor.position=position;actor.velocity=velocity;actor.reset_view()
		return
	var reference: Dictionary=samples[sequence]
	if not tribes.is_empty():actor.Tribes.reconcile(actor,tribes,reference.get("tribes",{}))
	if not jetpack.is_empty():actor.Jetpack.reconcile(actor,jetpack,reference.get("jetpack",{}))
	# Correct a server-denied stand-up at its acknowledged input. An older echo
	# must not undo a newer local crouch/prone transition.
	if height>=.65 and height<=1.65 and reference.get("height",-1.0)>0 and is_equal_approx(actor.collision_height,reference.height) and not is_equal_approx(height,reference.height):
		actor.update_height(height,true)
	var error: Vector3=position-reference.position
	stats.max_error=maxf(stats.max_error,error.length())
	if error.length()>.20:stats.corrections+=1
	var velocity_error: Vector3=velocity-reference.velocity
	if error.length()>2.5:
		stats.resets+=1
		actor.position=position;actor.velocity=velocity;actor.reset_view();return
	# The server holds inputs between 30 Hz packets. Ignore sub-tick differences.
	var correction:=error*.35 if error.length()>.20 else Vector3.ZERO
	var impulse:=Vector3.ZERO
	for axis in 3:
		if absf(velocity_error[axis])>.8:impulse[axis]=velocity_error[axis]
	# A ground collision removes downward velocity; it is not an upward force.
	# One tick of input/snapshot phase difference can otherwise re-launch a
	# client that has already landed (or add a second boost to its next jump).
	if grounded and absf(velocity.y)<.8 and reference.velocity.y<0:
		impulse.y=0
	# A wall/ceiling stopping an older movement is not a force in the opposite
	# direction. Keep newer motion (including moving away from the contact).
	for index in actor.get_slide_collision_count():
		var collision=actor.get_slide_collision(index)
		for contact in collision.get_collision_count():
			var normal: Vector3=collision.get_normal(contact)
			if reference.velocity.dot(normal)<-.8 and absf(velocity.dot(normal))<.8 and impulse.dot(normal)>0:
				impulse-=normal*impulse.dot(normal)
	correction=actor.correct_prediction(correction)
	actor.velocity+=impulse
	for key in samples.keys():
		if key<=sequence:samples.erase(key)
		else:
			samples[key].position+=correction
			samples[key].velocity+=impulse

func replay_tribes(actor,sequence: int,position: Vector3,velocity: Vector3,height: float,state: Dictionary) -> void:
	# Fast terrain travel needs collision replay, not a velocity-error impulse:
	# the latter can turn an older slope contact into a new vertical launch.
	var before: Vector3=actor.render_position()
	var before_physics: Vector3=actor.position
	var reference: Dictionary=samples.get(sequence,{})
	var error: float=position.distance_to(reference.get("position",position))
	stats.max_error=maxf(stats.max_error,error)
	if error>.20:stats.corrections+=1
	var held: Array=[actor.ski_held,actor.jet_held,actor.tribes_blocked,actor.jump_held,actor.rotation.y]
	actor.position=position;actor.velocity=velocity;actor.tribes_state=state.duplicate(true)
	if height>=.65 and height<=1.65:actor.update_height(height,true)
	actor.jump_held=reference.get("command",{}).get("jump",actor.jump_held)
	for key in samples.keys():
		if key<=sequence:samples.erase(key);continue
		var command: Dictionary=samples[key].get("command",{})
		if command.is_empty():continue
		# Authority runs every physics tick while holding the last 30 Hz input.
		# Its state may already cover part of the newer local simulation timeline;
		# replaying those milliseconds twice would add latency-dependent travel.
		var end_time: float=samples[key].tribes.get("time",state.time)
		var remaining:=minf(command.delta,maxf(0,end_time-float(actor.tribes_state.time)))
		if remaining<=.000001:continue
		actor.ski_held=command.ski;actor.jet_held=command.jet;actor.tribes_blocked=command.blocked
		actor.update_height(command.height)
		actor.simulate(command.move,command.yaw,command.slow,remaining,command.jump,command.swim)
		samples[key].position=actor.position;samples[key].velocity=actor.velocity;samples[key].tribes=actor.tribes_state.duplicate(true)
	actor.ski_held=held[0];actor.jet_held=held[1];actor.tribes_blocked=held[2];actor.jump_held=held[3];actor.rotation.y=held[4]
	actor.reset_physics_interpolation()
	actor.prediction_view_offset=before-actor.global_position
	stats["max_replay_adjustment"]=maxf(stats.get("max_replay_adjustment",0.0),before_physics.distance_to(actor.position))

func queue_authority(sequence:int,position:Vector3,velocity:Vector3,state:Dictionary) -> void:
	if sequence<=acknowledged or sequence<=pending_authority.get("sequence",-1):return
	pending_authority={"sequence":sequence,"position":position,"velocity":velocity,"state":state.duplicate(true)}

func apply_pending(actor) -> void:
	if pending_authority.is_empty():return
	var update:Dictionary=pending_authority;pending_authority={}
	var s:Dictionary=update.state
	if actor.tribes_enabled or not s.has("replay") or not samples.has(update.sequence) or samples[update.sequence].get("command",{}).is_empty():
		reconcile(actor,update.sequence,update.position,update.velocity,s.get("height",-1.0),s.get("grounded",false),s.get("jetpack",{}),s.get("tribes",{}));return
	replay(actor,update.sequence,update.position,update.velocity,s)

static func same_simulation(a:Dictionary,b:Dictionary) -> bool:
	if a.is_empty() or a.size()!=b.size():return false
	for field in b:
		if not a.has(field):return false
		if b[field] is float:
			if not is_equal_approx(float(a[field]),b[field]):return false
		elif b[field] is Vector2:
			if not a[field].is_equal_approx(b[field]):return false
		elif a[field]!=b[field]:return false
	return true

func replay(actor,sequence:int,position:Vector3,velocity:Vector3,state:Dictionary) -> void:
	if sequence<=acknowledged:return
	acknowledged=sequence
	var before:Vector3=actor.render_position()
	var reference:Dictionary=samples[sequence]
	var error:float=position.distance_to(reference.position)
	stats.max_error=maxf(stats.max_error,error)
	if error>.02:stats.corrections+=1
	# Matching state needs no collision queries. Compare the hidden movement
	# state too: equal positions alone would miss a queued jump or water boost.
	if error<.001 and velocity.distance_to(reference.velocity)<.001 and is_equal_approx(state.get("height",-1.0),reference.height) and same_simulation(reference.get("simulation",{}),state.replay) and reference.jetpack==state.get("jetpack",{}):
		for key in samples.keys():
			if key<=sequence:samples.erase(key)
		stats["confirmed"]=stats.get("confirmed",0)+1
		return
	if error>2.5 or samples.keys().filter(func(key):return key>sequence).size()>MAX_REPLAY_TICKS:
		stats.resets+=1;actor.position=position;actor.velocity=velocity;actor.reset_view()
		actor.restore_prediction_state(state.replay);acknowledged=sequence
		return
	var yaw:float=actor.rotation.y
	var environment:Dictionary=actor.prediction_environment()
	actor.position=position;actor.velocity=velocity
	actor.restore_prediction_state(state.replay)
	actor.update_height(state.get("height",actor.collision_height),true)
	if state.has("jetpack"):actor.jetpack_state=state.jetpack.duplicate(true)
	actor.replaying=true;actor.replay_grounded=int(state.get("grounded",false))
	for key in samples.keys():
		if key<=sequence:samples.erase(key);continue
		var c:Dictionary=samples[key].get("command",{})
		if c.is_empty():continue
		for field in c.environment:actor.set(field,c.environment[field])
		actor.update_height(c.height)
		actor.speed_multiplier=c.speed
		actor.configure_jetpack(c.jet_enabled,c.jet_blocked);actor.jetpack_requested=c.jet_request
		actor.simulate(c.move,c.yaw,c.slow,c.delta,c.jump,c.swim)
		actor.replay_grounded=-1
		if not c.room.is_zero_approx():preload("res://deathmatch/vr/room_scale.gd").move_capsule(actor,c.room,c.yaw,c.delta)
		samples[key].position=actor.position;samples[key].velocity=actor.velocity;samples[key].height=actor.collision_height
		samples[key].jetpack=actor.jetpack_state.duplicate(true) if actor.jetpack_enabled else {}
		samples[key].simulation=actor.prediction_state()
	actor.replay_grounded=-1;actor.replaying=false;actor.rotation.y=yaw
	for field in environment:actor.set(field,environment[field])
	actor.reset_physics_interpolation()
	actor.prediction_view_offset=before-actor.global_position
	stats["replays"]=stats.get("replays",0)+1
