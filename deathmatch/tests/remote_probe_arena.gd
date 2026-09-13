extends "res://deathmatch/arena.gd"
var probe_number:=0
var probe_moving:=true
func _local_command() -> Dictionary:
	var command:=super._local_command()
	if not probe_moving:return command
	# Exercise the normal command/prediction path, including jump press/release.
	var angle:=clock*.45+probe_number*1.3
	local_yaw=wrapf(angle,-PI,PI);local_pitch=-.12
	command.move=Vector2(sin(angle*.7),-1).normalized()
	command.yaw=local_yaw;command.pitch=local_pitch
	command.fire=fmod(clock+probe_number*.19,.8)<.3
	command.jump=fmod(clock+probe_number*.31,2.5)<.10
	command.crouch=fmod(clock+probe_number,15)>13
	command.respawn=true
	return command
