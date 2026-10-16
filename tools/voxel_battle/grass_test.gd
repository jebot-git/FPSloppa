extends "res://tools/voxel_battle/live_client.gd"
func arena_scene()->PackedScene:return preload("res://tools/voxel_battle/grass_test.tscn")
func start()->void:
 if OS.get_cmdline_user_args().has("--server"):
  game=arena_scene().instantiate();root.add_child(game);current_scene=game
 else:super.start()

# The suite buffers its own frame rows; avoid the ordinary one-second disk flush.
func sample()->void:pass
