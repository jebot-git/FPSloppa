extends RefCounted
## Compare authority with the saved state of its acknowledged input, never with
## a newer jump/turn. Bounded history; the server still owns collisions and damage.
const CAPACITY=180
var samples: Dictionary={}
var acknowledged:=-1

func clear() -> void:
	samples.clear();acknowledged=-1

func remember(sequence: int,position: Vector3,velocity: Vector3) -> void:
	samples[sequence]={"position":position,"velocity":velocity}
	while samples.size()>CAPACITY:samples.erase(samples.keys()[0])

func reconcile(actor,sequence: int,position: Vector3,velocity: Vector3) -> void:
	if sequence<=acknowledged:return
	acknowledged=sequence
	if not samples.has(sequence):
		# History loss/reconnect: only a substantial divergence warrants a reset.
		if actor.position.distance_to(position)>2.5:
			actor.position=position;actor.velocity=velocity;actor.reset_view()
		return
	var reference: Dictionary=samples[sequence]
	var error: Vector3=position-reference.position
	var velocity_error: Vector3=velocity-reference.velocity
	if error.length()>2.5:
		actor.position=position;actor.velocity=velocity;actor.reset_view();return
	# The server holds inputs between 30 Hz packets. Ignore sub-tick differences.
	var correction:=error*.35 if error.length()>.20 else Vector3.ZERO
	var impulse:=Vector3.ZERO
	for axis in 3:
		if absf(velocity_error[axis])>.8:impulse[axis]=velocity_error[axis]
	actor.position+=correction;actor.velocity+=impulse
	actor.prediction_view_offset-=correction
	for key in samples.keys():
		if key<=sequence:samples.erase(key)
		else:
			samples[key].position+=correction
			samples[key].velocity+=impulse
