extends Node
var driver
@rpc("any_peer","call_remote","unreliable",6)
func submit(serial: int,data: PackedByteArray,team_only: bool=false) -> void:
	pass
@rpc("authority","call_remote","unreliable",6)
func receive(id: int,serial: int,data: PackedByteArray,team_only: bool=false) -> void:
	pass
@rpc("authority","call_remote","reliable",0)
func policy(allowed: bool,host_name: String,backend: String="builtin",external_url: String="") -> void:
	pass
