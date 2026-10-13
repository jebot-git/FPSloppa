extends "res://tools/voxel_battle/cs_combat.gd"
const Meter=preload("res://tools/ut99_avatar/profile/meter.gd")
func tick_input(id:int,delta:float) -> void:
	var stamp:=Meter.begin("combat_input");super.tick_input(id,delta);Meter.end("combat_input",stamp)
