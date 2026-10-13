extends "res://tools/voxel_battle/cs_combat.gd"
const Trace=preload("res://tools/vrm_to_mdl/profile/trace.gd")
func tick_input(id: int,delta: float) -> void:
	var start:=Trace.begin()
	super.tick_input(id,delta)
	Trace.end("cs_weapon_input",start)
func fire(id: int,alternate: bool=false,charge: float=0.0) -> bool:
	var start:=Trace.begin()
	var result:=super.fire(id,alternate,charge)
	Trace.end("cs_fire",start)
	return result
