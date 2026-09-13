extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	var original: Array=game.map_catalog
	game.map_catalog=[{"id":game.current_map,"objectives":{"red":[1,2,3],"blue":[4,5,6]}}]
	game.match_mode.reset()
	assert(game.match_mode.bases==[Vector3(1,2,3),Vector3(4,5,6)])
	assert(game.match_mode.hill.is_finite())
	game.map_catalog=[{"id":game.current_map,"objectives":{"hill":[7,8,9]}}]
	game.match_mode.reset()
	assert(game.match_mode.bases.size()==2 and game.match_mode.hill==Vector3(7,8,9))
	game.map_catalog=original
	game.disconnect_game();game.queue_free();await process_frame;await process_frame
	print("OPTIONAL_OBJECTIVES_PASS flags_without_hill hill_without_flags");quit()
