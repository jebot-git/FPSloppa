extends Node
func _ready() -> void:
	if OS.get_cmdline_user_args().has("--resident-suite"):
		var probe=load("res://tools/frontier_vps/resident_driver.gd").new();probe.name="ResidentSuite";add_child(probe)
	elif OS.get_cmdline_user_args().has("--clients"):
		add_child(load("res://tools/frontier_vps/clients.gd").new())
	elif OS.get_cmdline_user_args().has("--capacity"):
		var probe=load("res://tools/frontier_vps/capacity.gd").new();add_child(probe)
	else:
		var arena=load("res://tools/voxel_battle/class_arena.tscn").instantiate();
		if OS.get_cmdline_user_args().has("--profile-players"):arena.set_script(load("res://tools/frontier_vps/metered_arena.gd"))
		get_tree().root.add_child.call_deferred(arena)
