extends "res://deathmatch/arena.gd"
var target:=Vector3.ZERO
var driving:=false
var trigger:=false
func _local_command() -> Dictionary:
	var id:=multiplayer.get_unique_id()
	var direction:=Vector3.ZERO
	if driving and fighters.has(id):
		direction=target-fighters[id].position;direction.y=0
		if direction.length()>.6:direction=direction.normalized()
		else:direction=Vector3.ZERO
	local_yaw=0
	return {"seq":sequence,"move":Vector2(direction.x,direction.z),"yaw":0.0,"pitch":-.15,"fire":trigger,"weapon":2,"slow":false,"respawn":true,"jump":false,"input_blocked":false}
