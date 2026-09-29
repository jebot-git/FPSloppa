extends SceneTree
func _initialize():
	var image:=Image.new()
	assert(image.load_svg_from_string(FileAccess.get_file_as_string("res://deathmatch/vehicles/tribes/hull-atlas.svg"))==OK)
	assert(image.save_png("res://deathmatch/vehicles/tribes/hull-atlas.png")==OK)
	quit()
