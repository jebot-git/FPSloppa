extends Node
var driver
@rpc("any_peer","call_remote","reliable",4)
func _offer(hash: String, size: int) -> void:
	pass
@rpc("authority","call_remote","reliable",4)
func _catalog(data: Dictionary) -> void:
	pass
@rpc("any_peer","call_remote","reliable",4)
func _request(hash: String) -> void:
	pass
@rpc("any_peer","call_remote","reliable",4)
func _busy(hash: String) -> void:
	pass
@rpc("any_peer","call_remote","reliable",4)
func _begin(hash: String, size: int) -> void:
	pass
@rpc("any_peer","call_remote","reliable",4)
func _chunk(hash: String, offset: int, bytes: PackedByteArray) -> void:
	pass
@rpc("any_peer","call_remote","reliable",4)
func _ack(hash: String, offset: int) -> void:
	pass
