extends Node
var driver
@rpc("authority","call_remote","reliable",5)
func _offer(map_id: String,hash: String,size: int,title: String,epoch: int=0,mode: String="dm",weapon_rules: String="doom",source: String="") -> void:
	get_parent().epoch=epoch;get_parent()._map_ready.rpc_id(1,hash)
@rpc("any_peer","call_remote","reliable",5)
func _request(hash: String) -> void:
	pass
@rpc("authority","call_remote","reliable",5)
func _begin(hash: String,size: int) -> void:
	pass
@rpc("authority","call_remote","reliable",5)
func _chunk(hash: String,offset: int,bytes: PackedByteArray) -> void:
	pass
@rpc("any_peer","call_remote","reliable",5)
func _ack(hash: String,offset: int) -> void:
	pass
