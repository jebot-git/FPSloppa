extends "res://tools/vrm_to_mdl/profile_no_ai.gd"
func create_game():
	var scene=super.create_game();scene.set_script(preload("res://tools/vrm_to_mdl/profile/impact_arena.gd"));return scene
