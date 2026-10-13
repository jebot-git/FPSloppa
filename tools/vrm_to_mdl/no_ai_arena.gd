extends "res://tools/voxel_battle/arena.gd"
func create_bot_controller() -> Node:return preload("res://tools/vrm_to_mdl/no_ai_slots.gd").new()
