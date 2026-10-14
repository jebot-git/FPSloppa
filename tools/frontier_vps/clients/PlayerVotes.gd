extends Node
var driver
@rpc("authority","call_remote","reliable",0)
func policy(allowed: bool,maps: Array,modes: Array=["dm"],matches: Array=[]) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func request(kind: String,value: String) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func cast_request(yes: bool) -> void:
	pass
@rpc("any_peer","call_remote","reliable",0)
func team_request(team: int) -> void:
	pass
