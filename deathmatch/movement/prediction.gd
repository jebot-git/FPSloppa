extends RefCounted
## Compare authority with the saved state of its acknowledged input, never with
## a newer jump/turn. Bounded history; the server still owns collisions and damage.
const CAPACITY=180
var native_motion=preload("res://deathmatch/native/movement.gd").create()
var samples:Dictionary:
	get:return native_motion.prediction_samples() if native_motion else reference_samples
var stats:Dictionary:
	get:return native_motion.prediction_stats() if native_motion else reference_stats
	set(value):
		if native_motion:native_motion.prediction_set_stats(value)
		else:reference_stats=value
var acknowledged:int:
	get:return native_motion.prediction_acknowledged() if native_motion else reference_acknowledged
var reference_samples: Dictionary={}
var reference_acknowledged:=-1
var reference_stats: Dictionary={"corrections":0,"resets":0,"max_error":0.0}

func has_samples()->bool:
	return native_motion.prediction_size()>0 if native_motion else not reference_samples.is_empty()

func clear() -> void:
	if native_motion:native_motion.prediction_clear();return
	reference_samples.clear();reference_acknowledged=-1

func remember(sequence: int,position: Vector3,velocity: Vector3,height: float=-1.0,jetpack: Dictionary={},stamina:float=-1.0) -> void:
	if native_motion:native_motion.prediction_remember(sequence,position,velocity,height,jetpack,stamina);return
	reference_samples[sequence]={"position":position,"velocity":velocity,"height":height,"jetpack":jetpack.duplicate(true),"stamina":stamina}
	while reference_samples.size()>CAPACITY:reference_samples.erase(reference_samples.keys()[0])

func reconcile(actor,sequence: int,position: Vector3,velocity: Vector3,height: float=-1.0,grounded: bool=false,jetpack: Dictionary={},stamina:float=-1.0) -> void:
	if native_motion:
		var result:Dictionary=native_motion.prediction_begin(actor,sequence,position,velocity,grounded)
		if result.is_empty():return
		if result.get("missing",false):
			if not jetpack.is_empty():actor.Jetpack.reconcile(actor,jetpack)
		else:
			if actor.cs16_enabled and stamina>=0 and result.stamina>=0:
				actor.cs16_stamina=clampf(actor.cs16_stamina+stamina-result.stamina,0,actor.CS16.JUMP_STAMINA)
			if not jetpack.is_empty():actor.Jetpack.reconcile(actor,jetpack,result.jetpack)
			if height>=.65 and height<=1.65 and result.height>0 and is_equal_approx(actor.collision_height,result.height) and not is_equal_approx(height,result.height):actor.update_height(height,true)
		if result.get("reset",false):actor.position=position;actor.velocity=velocity;actor.reset_view();return
		if result.get("missing",false):return
		var applied:Vector3=actor.correct_prediction(result.correction)
		actor.velocity+=result.impulse
		native_motion.prediction_finish(sequence,applied,result.impulse)
		return
	if sequence<=reference_acknowledged:return
	reference_acknowledged=sequence
	if not reference_samples.has(sequence):
		if not jetpack.is_empty():actor.Jetpack.reconcile(actor,jetpack)
		# History loss/reconnect: only a substantial divergence warrants a reset.
		if actor.position.distance_to(position)>2.5:
			actor.position=position;actor.velocity=velocity;actor.reset_view()
		return
	var reference: Dictionary=reference_samples[sequence]
	if actor.cs16_enabled and stamina>=0 and reference.get("stamina",-1.0)>=0:
		actor.cs16_stamina=clampf(actor.cs16_stamina+stamina-reference.stamina,0,actor.CS16.JUMP_STAMINA)
	if not jetpack.is_empty():actor.Jetpack.reconcile(actor,jetpack,reference.get("jetpack",{}))
	# Correct a server-denied stand-up at its acknowledged input. An older echo
	# must not undo a newer local crouch/prone transition.
	if height>=.65 and height<=1.65 and reference.get("height",-1.0)>0 and is_equal_approx(actor.collision_height,reference.height) and not is_equal_approx(height,reference.height):
		actor.update_height(height,true)
	var error: Vector3=position-reference.position
	reference_stats.max_error=maxf(reference_stats.max_error,error.length())
	if error.length()>.20:reference_stats.corrections+=1
	var velocity_error: Vector3=velocity-reference.velocity
	if error.length()>2.5:
		reference_stats.resets+=1
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
	for key in reference_samples.keys():
		if key<=sequence:reference_samples.erase(key)
		else:
			reference_samples[key].position+=correction
			reference_samples[key].velocity+=impulse
