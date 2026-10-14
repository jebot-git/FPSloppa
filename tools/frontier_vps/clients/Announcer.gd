extends Node
var driver
@rpc("authority","call_remote","reliable",0)
func policy(enabled: bool) -> void:
	pass
@rpc("authority","call_local","reliable",0)
func receive(cue: String,target: int=0) -> void:
	pass
