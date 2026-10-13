extends SceneTree
func _initialize() -> void:
	var begin:=Time.get_ticks_msec()
	var Map=preload("res://tools/voxel_battle/map.gd")
	var shape=Map.terrain_collision()
	print(JSON.stringify({"cache":Map.collision_cache_path(),"samples":shape.map_data.size(),"spacing_m":Map.Landscape.EXTENT/(Map.COLLISION_SIDE-1),"bake_seconds":(Time.get_ticks_msec()-begin)/1000.0}))
	quit()
