extends SceneTree
func _initialize() -> void:
	var map=preload("res://tools/voxelspace/factory_map.gd").new()
	map.generate("res://test-results/factory-optimization")
	var rows: Array=[]
	for item in map.boxes:
		rows.append([[item[0].x,item[0].y,item[0].z],[item[1].x,item[1].y,item[1].z],[item[2].r,item[2].g,item[2].b]])
	FileAccess.open("res://test-results/factory-optimization/factory-boxes.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	FileAccess.open("res://test-results/factory-optimization/terrain-heights.bin",FileAccess.WRITE).store_buffer(map.heights.to_byte_array())
	quit()
