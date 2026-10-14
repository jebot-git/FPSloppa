extends Node
var driver
@rpc("authority","call_remote","reliable",4)
func _manifest(epoch: int,value: int,data: Dictionary) -> void:
	_ready_assets.rpc_id(1,epoch,value)
@rpc("any_peer","call_remote","reliable",4)
func _ready_assets(epoch: int,value: int) -> void:
	pass
@rpc("any_peer","call_remote","reliable",4)
func _keepalive(epoch: int,value: int) -> void:
	pass
