extends "res://deathmatch/fighter.gd"
const Meter=preload("res://tools/ut99_avatar/profile/meter.gd")
func simulate(input:Vector2,yaw:float,slow:bool,delta:float,jump:bool=false,swim:Vector3=Vector3.ZERO) -> void:
	var stamp:=Meter.begin("movement_collision");super.simulate(input,yaw,slow,delta,jump,swim);Meter.end("movement_collision",stamp)
func _process(delta:float) -> void:
	var stamp:=Meter.begin("fighter_visual_update");super._process(delta);Meter.end("fighter_visual_update",stamp)
