extends SceneTree
func _initialize():call_deferred("run")
func shot(name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,960);root.content_scale_size=Vector2i(853,640)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false);game.hud.hide()
	for name in ["tf_ironspan","tf_relayworks"]:
		var path: String=ProjectSettings.globalize_path("res://optional-tf-map-pack/"+name+".bsp")
		game.map_catalog=[{"id":name,"title":name,"path":path,"scene":"user://"+FileAccess.get_sha256(path)+".scn","sha256":FileAccess.get_sha256(path)}]
		game._load_map(name);game.match_mode.kind="tf";game.match_mode.reset()
		var camera: Camera3D=game.get_node("Overview");camera.make_current();camera.position=Vector3(38,54,60);camera.look_at(Vector3(0,0,0));await shot(name+"-overview")
		camera.position=Vector3(12,3,0);camera.look_at(Vector3(0,4,-25));await shot(name+"-ground")
	game.hud.show()
	var panel=preload("res://deathmatch/modes/fortress_panel.gd").new();game.hud.get_child(0).add_child(panel);panel.setup(game);panel.open();await shot("tf-class-menu");panel.free();game.hud.hide()
	game.free();quit()
