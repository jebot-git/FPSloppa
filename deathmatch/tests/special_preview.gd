extends SceneTree
func _initialize():call_deferred("run")
func shot(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,960);root.content_scale_size=Vector2i(853,640)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	await shot("special-menu")
	var rig=preload("res://deathmatch/vr/rig.gd").new();rig.smooth_turn=true
	var panel=preload("res://deathmatch/vr/turn_panel.gd").new();game.hud.get_child(0).add_child(panel);panel.setup(rig);panel.open()
	await shot("special-controls");panel.free();rig.free()
	game.hud.hide();game.set_process(false)
	for number in range(9,14):
		for child in game.get_node("Map").get_children():child.free()
		var map=preload("res://deathmatch/maps/loader.gd").read("res://optional-map-pack/lqdm%d.bsp"%number);game.get_node("Map").add_child(map)
		await physics_frame;await physics_frame
		var camera: Camera3D=game.get_node("Overview");camera.make_current()
		for node in map.get_children():
			if "attributes" in node and node.attributes.get("classname","")=="info_player_deathmatch":
				camera.position=node.global_position+Vector3.UP*.75;camera.rotation=Vector3(0,deg_to_rad(float(node.attributes.get("angle",0))),0);break
		await shot("optional-lqdm%d"%number)
	for child in game.get_node("Map").get_children():child.free()
	var rail=preload("res://deathmatch/art.gd").weapon(9);game.add_child(rail)
	var camera:Camera3D=game.get_node("Overview");camera.position=Vector3(1,.5,1);camera.look_at(Vector3(0,0,-.3));await shot("special-railgun")
	game.free();quit()
