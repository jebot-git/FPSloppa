extends "res://tools/voxel_battle/shocktroop_test_arena.gd"
var grass_suite:Node
func _ready()->void:
 if not OS.get_cmdline_user_args().has("--cq-grass-test"):
  push_error("Grass fixture requires --cq-grass-test");get_tree().quit(2);return
 super._ready()
func _process(delta:float)->void:
 super._process(delta)
 if headless or not fixture_ready or is_instance_valid(grass_suite):return
 grass_suite=(load("res://tools/voxel_battle/grass_selection_suite.gd") if OS.get_cmdline_user_args().has("--grass-selection-only") else preload("res://tools/voxel_battle/grass_test_suite.gd")).new();add_child(grass_suite);grass_suite.setup(self)
