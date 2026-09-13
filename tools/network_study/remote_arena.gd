extends "res://tools/remote_match/client_arena.gd"
## Half of the remote peers add validated synthetic full-body data to normal AI input.
func _local_command() -> Dictionary:
	var command := super._local_command()
	if test_index < 8 or observer: return command
	var pose := VRPoses.neutral()
	pose.weapon.basis = Basis(Vector3.RIGHT,command.pitch)
	pose.body = {}
	var index := 0
	for key in ["hips","chest","left_foot","right_foot","left_knee","right_knee","left_elbow","right_elbow","left_hand","right_hand"]:
		pose.body[key] = Transform3D(Basis.from_euler(Vector3(sin(clock*.7+index)*.2,cos(clock*.9+index)*.2,sin(clock*.5+index)*.1)),Vector3(sin(index)*.25,.8+cos(index)*.5,sin(clock+index)*.15)); index += 1
	pose.body.left_curls = PackedFloat32Array([.1,.2,.3,.4,.5]); pose.body.right_curls = PackedFloat32Array([.2,.3,.4,.5,.6])
	pose.face = {"look":Vector2(sin(clock)*.1,cos(clock)*.1),"blink":Vector2(.1,.2),"gaze":true,"lids":true,"expression":PackedFloat32Array([.1,.2,.1,.2,.1])}
	command.xr = pose; command.room = Vector3.ZERO; command.physical = false
	return command
