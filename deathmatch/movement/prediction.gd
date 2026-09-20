extends RefCounted
## Compare authority with the saved state of its acknowledged input, never with
## a newer jump/turn. Bounded history; the server still owns collisions and damage.
const CAPACITY=180
var samples: Dictionary={}
var acknowledged:=-1
var stats: Dictionary={"corrections":0,"resets":0,"max_error":0.0}

func clear() -> void:
	samples.clear();acknowledged=-1

func remember(sequence: int,position: Vector3,velocity: Vector3,height: float=-1.0,jetpack: Dictionary={}) -> void:
	samples[sequence]={"position":position,"velocity":velocity,"height":height,"jetpack":jetpack.duplicate(true)}
	while samples.size()>CAPACITY:samples.erase(samples.keys()[0])

func reconcile(actor,sequence: int,position: Vector3,velocity: Vector3,height: float=-1.0,grounded: bool=false,jetpack: Dictionary={}) -> void:
	if sequence<=acknowledged:return
	acknowledged=sequence
	if not samples.has(sequence):
		if not jetpack.is_empty():actor.Jetpack.reconcile(actor,jetpack)
		# History loss/reconnect: only a substantial divergence warrants a reset.
		if actor.position.distance_to(position)>2.5:
			actor.position=position;actor.velocity=velocity;actor.reset_view()
		return
	var reference: Dictionary=samples[sequence]
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
