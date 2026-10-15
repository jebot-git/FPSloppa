extends Node
## Exercise VR-only script dependencies even when CI has no headset/render device.
func _ready()->void:
	var failed:=false
	for path in ["res://addons/godot-xr-tools/misc/xr_helpers.gd","res://addons/godot-xr-tools/events/pointer_event.gd","res://addons/godot-xr-tools/hands/hand.gd","res://addons/godot-xr-tools/functions/function_pointer.gd","res://addons/godot-xr-tools/objects/viewport_2d_in_3d.gd","res://addons/godot-xr-tools/objects/viewport_2d_in_3d_body.gd"]:
		var script=load(path)
		if not script or not script.can_instantiate():
			push_error("RELEASE_RESOURCE_FAILED "+path);failed=true
	var terrain=load("res://tools/streamed_heightfield/stream.gd").new()
	if terrain.initialize_tile_arrays()!=OK or terrain.height_tiles.get_format()!=Image.FORMAT_RF or terrain.color_tiles.get_format()!=Image.FORMAT_RGBA8 or terrain.height_tiles.get_layers()!=terrain.CAPACITY:
		push_error("RELEASE_RESOURCE_FAILED terrain texture arrays");failed=true
	else:
		terrain.height_tiles.update_layer(terrain.Mips.image(Image.create(65,65,false,Image.FORMAT_RF)),0)
		terrain.color_tiles.update_layer(terrain.Mips.image(Image.create(65,65,false,Image.FORMAT_RGBA8)),0)
	terrain.coarse_node.free();terrain.free()
	print("RELEASE_RESOURCES ","FAILED" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
