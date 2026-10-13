extends Node3D
## Attach to a vehicle hull. Repair is authoritative and returns actual restored HP.
@export var team:=0
@export var max_hp:=1000
@export var hp:=1000
func _ready() -> void:add_to_group("cq_repairable_vehicles")
func owns_collider(collider:Node) -> bool:
	return collider==self or collider==get_parent() or is_ancestor_of(collider)
func repair(request_team:int,amount:int) -> int:
	if not multiplayer.is_server() or request_team!=team or hp<=0 or amount<=0:return 0
	var restored:=mini(amount,maxi(0,max_hp-hp));hp+=restored;return restored
